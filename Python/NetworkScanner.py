#!/usr/bin/env python3

import re
import socket
import ssl
import threading
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple


# ============================================================
# GLOBAL-IRC NETWORK SCANNER
# ============================================================
#
# Main bot:
#   ircplus.nl:6667
#   Channel: #IRCPlus
#
# The main bot remains connected while temporary worker
# connections test every server discovered through /MAP
# and /LINKS.
#
# Each worker disconnects immediately after its test.
#
# Python standard library only.
# No pip packages are required.
#
# ============================================================


# ------------------------------------------------------------
# MAIN BOT SETTINGS
# ------------------------------------------------------------

MAIN_HOST = "xxxxx"
MAIN_PORT = 6667

MAIN_NICK = "GlobalScan"
MAIN_CHANNEL = "xxxx"


# ------------------------------------------------------------
# SCANNER SETTINGS
# ------------------------------------------------------------

SCAN_TIMEOUT = 8

DISCOVERY_TIMEOUT = 10

# IMPORTANT:
# The main IRC socket is allowed to be quiet.
# A quiet IRC connection is NOT a disconnect.
MAIN_SOCKET_TIMEOUT = 30

DELAY_BETWEEN_TESTS = 0.35


# ------------------------------------------------------------
# DNS ROUND-ROBIN HOST
# ------------------------------------------------------------

DNS_CHECK_HOST = "irc.global-irc.eu"


# ------------------------------------------------------------
# SERVERS THAT MUST NOT BE SCANNED
# ------------------------------------------------------------

EXCLUDED = {
    "hub.global-irc.eu",
    "services.global-irc.eu",
}


# ------------------------------------------------------------
# SSL CONTEXT
# ------------------------------------------------------------
#
# The purpose of the SSL test is to determine whether the
# IRC server can actually be reached over TLS.
#
# Certificate validation is therefore disabled.
#
# This means a reachable server with a self-signed or otherwise
# locally untrusted certificate can still be reported as
# reachable over TLS.
#
# ------------------------------------------------------------

SSL_CONTEXT = ssl.create_default_context()

SSL_CONTEXT.check_hostname = False
SSL_CONTEXT.verify_mode = ssl.CERT_NONE


# ------------------------------------------------------------
# THREADING
# ------------------------------------------------------------

# Prevent simultaneous writes from different threads from
# corrupting IRC commands.

SEND_LOCK = threading.Lock()


# Prevent two complete scans from running simultaneously.

SCAN_LOCK = threading.Lock()


# ============================================================
# DATA STRUCTURES
# ============================================================


@dataclass
class Target:
    name: str
    host: str


@dataclass
class Result:
    target: str
    host: str
    port: int
    ssl: bool
    ok: bool
    detail: str
    elapsed: float


# ============================================================
# GENERAL HELPERS
# ============================================================


def normalize_server_name(value: str) -> str:
    """
    Normalize a server name for comparisons.
    """

    return value.strip().lower().rstrip(".")


# ------------------------------------------------------------


def irc_send(
    sock: socket.socket,
    command: str
) -> None:
    """
    Safely send one IRC command.
    """

    with SEND_LOCK:

        sock.sendall(
            (
                command
                +
                "\r\n"
            ).encode("utf-8")
        )


# ------------------------------------------------------------


def say(
    sock: socket.socket,
    text: str
) -> bool:
    """
    Send a message to #IRCPlus.

    Returns False if the main connection is already dead.
    """

    try:

        irc_send(
            sock,
            f"PRIVMSG {MAIN_CHANNEL} :{text}"
        )

        return True

    except (
        OSError,
        ValueError
    ):

        return False


# ------------------------------------------------------------


def sleep_interruptible(
    seconds: float,
    stop_event: threading.Event
) -> bool:
    """
    Sleep while allowing a scan to be cancelled.

    Returns False if cancellation was requested.
    """

    end = (
        time.monotonic()
        +
        seconds
    )

    while time.monotonic() < end:

        if stop_event.is_set():

            return False

        time.sleep(
            min(
                0.1,
                end - time.monotonic()
            )
        )

    return True


# ============================================================
# /MAP PARSER
# ============================================================


def parse_server_from_map(
    line: str
) -> Optional[Target]:
    """
    Parse UnrealIRCd RPL_MAP (006).

    Example:

    :server 006 GlobalScan server.name 1 :description
    """

    parts = line.split()

    if (
        len(parts) < 4
        or
        parts[1] != "006"
    ):

        return None

    candidate = parts[3].lstrip(":")

    if not re.fullmatch(
        r"[A-Za-z0-9_.-]+",
        candidate
    ):

        return None

    return Target(
        candidate,
        candidate
    )


# ============================================================
# /LINKS PARSER
# ============================================================


def parse_server_from_links(
    line: str
) -> Optional[Target]:
    """
    Parse IRC RPL_LINKS (364).

    Example:

    :server 364 GlobalScan target parent :description
    """

    parts = line.split()

    if (
        len(parts) < 4
        or
        parts[1] != "364"
    ):

        return None

    candidate = parts[3].lstrip(":")

    if not re.fullmatch(
        r"[A-Za-z0-9_.-]+",
        candidate
    ):

        return None

    return Target(
        candidate,
        candidate
    )


# ============================================================
# EXCLUSION CHECK
# ============================================================


def is_excluded(
    target: Target
) -> bool:

    return (
        normalize_server_name(
            target.name
        )
        in EXCLUDED
    )


# ============================================================
# DISCOVER NETWORK SERVERS
# ============================================================
#
# A separate temporary connection is intentionally used here.
#
# This means the permanent GlobalScan connection never has to
# stop reading its own IRC socket while /MAP and /LINKS are
# being processed.
#
# ============================================================


def discover_servers() -> List[Target]:

    sock: Optional[socket.socket] = None

    targets: Dict[str, Target] = {}

    buffer = b""

    deadline = (
        time.monotonic()
        +
        DISCOVERY_TIMEOUT
    )

    try:

        # ----------------------------------------------------
        # CONNECT
        # ----------------------------------------------------

        sock = socket.create_connection(
            (
                MAIN_HOST,
                MAIN_PORT
            ),
            timeout=SCAN_TIMEOUT
        )

        sock.settimeout(1.0)

        # ----------------------------------------------------
        # TEMPORARY DISCOVERY NICK
        # ----------------------------------------------------

        nick = (
            "MapScan"
            +
            str(
                int(
                    time.time()
                    *
                    1000
                )
                %
                1000000
            )
        )

        irc_send(
            sock,
            f"NICK {nick}"
        )

        irc_send(
            sock,
            (
                f"USER {nick} 0 * "
                f":Global-IRC network map discovery"
            )
        )

        # ----------------------------------------------------
        # WAIT FOR IRC WELCOME
        # ----------------------------------------------------

        registered = False

        while (
            time.monotonic()
            <
            deadline
            and
            not registered
        ):

            try:

                data = sock.recv(8192)

            except socket.timeout:

                continue

            if not data:

                break

            buffer += data

            while b"\n" in buffer:

                raw, buffer = buffer.split(
                    b"\n",
                    1
                )

                line = raw.decode(
                    "utf-8",
                    errors="replace"
                ).rstrip("\r")

                # PING/PONG

                if line.startswith("PING "):

                    irc_send(
                        sock,
                        "PONG " + line[5:]
                    )

                # Welcome

                if " 001 " in line:

                    registered = True

                    break

        if not registered:

            raise ConnectionError(
                "IRC server did not send a welcome during discovery"
            )

        # ----------------------------------------------------
        # REQUEST MAP
        # ----------------------------------------------------

        irc_send(
            sock,
            "MAP"
        )

        # ----------------------------------------------------
        # REQUEST LINKS
        # ----------------------------------------------------

        irc_send(
            sock,
            "LINKS"
        )

        map_done = False
        links_done = False

        buffer = b""

        deadline = (
            time.monotonic()
            +
            DISCOVERY_TIMEOUT
        )

        # ----------------------------------------------------
        # READ MAP + LINKS
        # ----------------------------------------------------

        while (
            time.monotonic()
            <
            deadline
            and
            not (
                map_done
                and
                links_done
            )
        ):

            try:

                data = sock.recv(16384)

            except socket.timeout:

                continue

            if not data:

                break

            buffer += data

            while b"\n" in buffer:

                raw, buffer = buffer.split(
                    b"\n",
                    1
                )

                line = raw.decode(
                    "utf-8",
                    errors="replace"
                ).rstrip("\r")

                parts = line.split()

                # PING

                if line.startswith("PING "):

                    irc_send(
                        sock,
                        "PONG " + line[5:]
                    )

                    continue

                # ------------------------------------------------
                # MAP SERVER
                # ------------------------------------------------

                target = parse_server_from_map(
                    line
                )

                if (
                    target
                    and
                    not is_excluded(target)
                ):

                    targets.setdefault(
                        normalize_server_name(
                            target.name
                        ),
                        target
                    )

                # ------------------------------------------------
                # LINKS SERVER
                # ------------------------------------------------

                target = parse_server_from_links(
                    line
                )

                if (
                    target
                    and
                    not is_excluded(target)
                ):

                    targets.setdefault(
                        normalize_server_name(
                            target.name
                        ),
                        target
                    )

                # ------------------------------------------------
                # MAP END
                #
                # 007 = RPL_MAPEND
                # ------------------------------------------------

                if (
                    len(parts) >= 2
                    and
                    parts[1] == "007"
                ):

                    map_done = True

                # ------------------------------------------------
                # LINKS END
                #
                # 365 = RPL_ENDOFLINKS
                # ------------------------------------------------

                if (
                    len(parts) >= 2
                    and
                    parts[1] == "365"
                ):

                    links_done = True

        # ----------------------------------------------------
        # SORT SERVER LIST
        # ----------------------------------------------------

        return sorted(
            targets.values(),
            key=lambda target:
                target.name.lower()
        )

    finally:

        # ----------------------------------------------------
        # CLOSE DISCOVERY CONNECTION
        # ----------------------------------------------------

        if sock is not None:

            try:

                sock.shutdown(
                    socket.SHUT_RDWR
                )

            except OSError:

                pass

            try:

                sock.close()

            except OSError:

                pass


# ============================================================
# TEST ONE SERVER / ONE PORT
# ============================================================


def test_target(
    target: Target,
    port: int,
    use_ssl: bool,
    stop_event: threading.Event
) -> Result:

    started = time.monotonic()

    sock: Optional[socket.socket] = None

    try:

        # ----------------------------------------------------
        # CANCELLED?
        # ----------------------------------------------------

        if stop_event.is_set():

            return Result(
                target.name,
                target.host,
                port,
                use_ssl,
                False,
                "scan cancelled",
                0.0
            )

        # ----------------------------------------------------
        # TCP CONNECT
        # ----------------------------------------------------

        sock = socket.create_connection(
            (
                target.host,
                port
            ),
            timeout=SCAN_TIMEOUT
        )

        sock.settimeout(2.0)

        # ----------------------------------------------------
        # SSL/TLS
        # ----------------------------------------------------

        if use_ssl:

            sock = SSL_CONTEXT.wrap_socket(
                sock,
                server_hostname=target.host
            )

            sock.settimeout(2.0)

        # ----------------------------------------------------
        # TEMPORARY IRC NICK
        # ----------------------------------------------------

        nick = (
            "Chk"
            +
            str(
                int(
                    time.time()
                    *
                    1000
                )
                %
                100000000
            )
        )

        irc_send(
            sock,
            f"NICK {nick}"
        )

        irc_send(
            sock,
            (
                f"USER {nick} 0 * "
                f":Global-IRC connectivity check"
            )
        )

        buffer = b""

        deadline = (
            time.monotonic()
            +
            SCAN_TIMEOUT
        )

        # ----------------------------------------------------
        # WAIT FOR IRC RESPONSE
        # ----------------------------------------------------

        while time.monotonic() < deadline:

            if stop_event.is_set():

                return Result(
                    target.name,
                    target.host,
                    port,
                    use_ssl,
                    False,
                    "scan cancelled",
                    time.monotonic()
                    -
                    started
                )

            try:

                data = sock.recv(4096)

            except socket.timeout:

                # IMPORTANT:
                #
                # A timeout here does NOT mean that the server
                # disconnected. We simply continue waiting.
                #
                continue

            if not data:

                raise ConnectionError(
                    "server closed the connection"
                )

            buffer += data

            while b"\n" in buffer:

                raw, buffer = buffer.split(
                    b"\n",
                    1
                )

                line = raw.decode(
                    "utf-8",
                    errors="replace"
                ).rstrip("\r")

                # ------------------------------------------------
                # PING
                # ------------------------------------------------

                if line.startswith("PING "):

                    irc_send(
                        sock,
                        "PONG " + line[5:]
                    )

                    continue

                # ------------------------------------------------
                # IRC WELCOME
                # ------------------------------------------------

                if " 001 " in line:

                    return Result(
                        target.name,
                        target.host,
                        port,
                        use_ssl,
                        True,
                        "IRC handshake accepted",
                        time.monotonic()
                        -
                        started
                    )

                # ------------------------------------------------
                # OTHER IRC RESPONSES
                #
                # These still prove that an IRC server answered.
                # ------------------------------------------------

                match = re.search(
                    r" (\d{3}) ",
                    line
                )

                if (
                    match
                    and
                    match.group(1)
                    in {
                        "433",
                        "451",
                        "462",
                        "464",
                        "465"
                    }
                ):

                    return Result(
                        target.name,
                        target.host,
                        port,
                        use_ssl,
                        True,
                        (
                            "IRC server answered "
                            f"(numeric {match.group(1)})"
                        ),
                        time.monotonic()
                        -
                        started
                    )

        # ----------------------------------------------------
        # NO WELCOME
        # ----------------------------------------------------

        return Result(
            target.name,
            target.host,
            port,
            use_ssl,
            False,
            (
                "connection established, "
                "but no IRC welcome was received"
            ),
            time.monotonic()
            -
            started
        )

    # --------------------------------------------------------
    # TLS ERROR
    # --------------------------------------------------------

    except ssl.SSLError as exc:

        return Result(
            target.name,
            target.host,
            port,
            use_ssl,
            False,
            f"TLS error: {exc}",
            time.monotonic()
            -
            started
        )

    # --------------------------------------------------------
    # TIMEOUT
    # --------------------------------------------------------

    except socket.timeout:

        return Result(
            target.name,
            target.host,
            port,
            use_ssl,
            False,
            "connection timeout",
            time.monotonic()
            -
            started
        )

    # --------------------------------------------------------
    # DNS ERROR
    # --------------------------------------------------------

    except socket.gaierror as exc:

        return Result(
            target.name,
            target.host,
            port,
            use_ssl,
            False,
            f"DNS error: {exc}",
            time.monotonic()
            -
            started
        )

    # --------------------------------------------------------
    # CONNECTION REFUSED
    # --------------------------------------------------------

    except ConnectionRefusedError:

        return Result(
            target.name,
            target.host,
            port,
            use_ssl,
            False,
            "connection refused",
            time.monotonic()
            -
            started
        )

    # --------------------------------------------------------
    # OTHER SOCKET ERROR
    # --------------------------------------------------------

    except OSError as exc:

        return Result(
            target.name,
            target.host,
            port,
            use_ssl,
            False,
            f"connection error: {exc}",
            time.monotonic()
            -
            started
        )

    # --------------------------------------------------------
    # OTHER ERROR
    # --------------------------------------------------------

    except Exception as exc:

        return Result(
            target.name,
            target.host,
            port,
            use_ssl,
            False,
            f"error: {exc}",
            time.monotonic()
            -
            started
        )

    finally:

        # ----------------------------------------------------
        # ALWAYS CLOSE TEMPORARY WORKER CONNECTION
        # ----------------------------------------------------

        if sock is not None:

            try:

                sock.shutdown(
                    socket.SHUT_RDWR
                )

            except OSError:

                pass

            try:

                sock.close()

            except OSError:

                pass


# ============================================================
# DNS RESOLUTION
# ============================================================


def resolve_ips(
    host: str
) -> Set[str]:

    ips: Set[str] = set()

    try:

        for item in socket.getaddrinfo(
            host,
            None,
            type=socket.SOCK_STREAM
        ):

            ips.add(
                item[4][0]
            )

    except socket.gaierror:

        pass

    return ips


# ============================================================
# DNS CHECK
# ============================================================


def dns_check(
    targets: List[Target]
) -> Tuple[
    Set[str],
    List[str]
]:

    rr_ips = resolve_ips(
        DNS_CHECK_HOST
    )

    notes: List[str] = []

    if not rr_ips:

        notes.append(
            f"{DNS_CHECK_HOST}: DNS resolution failed"
        )

        return (
            rr_ips,
            notes
        )

    for target in targets:

        ips = resolve_ips(
            target.host
        )

        if not ips:

            notes.append(
                f"{target.name}: no DNS address found"
            )

            continue

        overlap = (
            ips
            &
            rr_ips
        )

        if overlap:

            notes.append(
                (
                    f"{target.name}: DNS overlap with "
                    f"{DNS_CHECK_HOST} "
                    f"({', '.join(sorted(overlap))})"
                )
            )

        else:

            notes.append(
                (
                    f"{target.name}: no DNS overlap with "
                    f"{DNS_CHECK_HOST}"
                )
            )

    return (
        rr_ips,
        notes
    )


# ============================================================
# COMPLETE NETWORK SCAN
# ============================================================


def run_scan(
    main_sock: socket.socket,
    stop_event: threading.Event
) -> None:

    # --------------------------------------------------------
    # ONLY ONE SCAN AT A TIME
    # --------------------------------------------------------

    if not SCAN_LOCK.acquire(
        blocking=False
    ):

        say(
            main_sock,
            (
                "ℹ️ A network scan is already running. "
                "Please wait for it to finish."
            )
        )

        return

    try:

        # ----------------------------------------------------
        # CANCELLED?
        # ----------------------------------------------------

        if stop_event.is_set():

            return

        # ----------------------------------------------------
        # START MESSAGE
        # ----------------------------------------------------

        say(
            main_sock,
            "╔══════════════════════════════════════════════════════╗"
        )

        say(
            main_sock,
            "║ 🔎 Global-IRC Network Scanner initialized           ║"
        )

        say(
            main_sock,
            "║ Scanning the entire Global-IRC Network...            ║"
        )

        say(
            main_sock,
            "║ Please stand by while every server is tested.       ║"
        )

        say(
            main_sock,
            "╚══════════════════════════════════════════════════════╝"
        )

        # ----------------------------------------------------
        # DISCOVER SERVERS
        # ----------------------------------------------------

        try:

            targets = discover_servers()

        except Exception as exc:

            if not stop_event.is_set():

                say(
                    main_sock,
                    (
                        f"❌ Network map discovery failed: "
                        f"{exc}"
                    )
                )

            return

        # ----------------------------------------------------
        # CANCELLED?
        # ----------------------------------------------------

        if stop_event.is_set():

            return

        # ----------------------------------------------------
        # NOTHING FOUND
        # ----------------------------------------------------

        if not targets:

            say(
                main_sock,
                (
                    "❌ No servers were discovered "
                    "from /MAP or /LINKS."
                )
            )

            return

        # ----------------------------------------------------
        # DISCOVERY REPORT
        # ----------------------------------------------------

        say(
            main_sock,
            (
                f"📡 Discovered {len(targets)} server(s) "
                "from /MAP and /LINKS. "
                "Hub.Global-IRC.Eu and "
                "Services.Global-IRC.Eu are excluded."
            )
        )

        say(
            main_sock,
            (
                "🧪 Testing every server on "
                "IRC :6667 and SSL/TLS :6697..."
            )
        )

        results: List[Result] = []

        # ----------------------------------------------------
        # TEST EVERY SERVER
        # ----------------------------------------------------

        for target in targets:

            if stop_event.is_set():

                return

            # =================================================
            # PORT 6667
            # =================================================

            say(
                main_sock,
                (
                    f"➡️ Testing {target.name} "
                    "[IRC:6667]..."
                )
            )

            result = test_target(
                target,
                6667,
                False,
                stop_event
            )

            results.append(
                result
            )

            if stop_event.is_set():

                return

            if result.ok:

                say(
                    main_sock,
                    (
                        f"   ✅ {target.name}:6667 IRC — "
                        f"{result.detail}"
                    )
                )

            else:

                say(
                    main_sock,
                    (
                        f"   ❌ {target.name}:6667 IRC — "
                        f"{result.detail}"
                    )
                )

            if not sleep_interruptible(
                DELAY_BETWEEN_TESTS,
                stop_event
            ):

                return

            # =================================================
            # PORT 6697
            # =================================================

            say(
                main_sock,
                (
                    f"➡️ Testing {target.name} "
                    "[SSL/TLS:6697]..."
                )
            )

            result = test_target(
                target,
                6697,
                True,
                stop_event
            )

            results.append(
                result
            )

            if stop_event.is_set():

                return

            if result.ok:

                say(
                    main_sock,
                    (
                        f"   ✅ {target.name}:6697 "
                        f"SSL/TLS — {result.detail}"
                    )
                )

            else:

                say(
                    main_sock,
                    (
                        f"   ❌ {target.name}:6697 "
                        f"SSL/TLS — {result.detail}"
                    )
                )

            if not sleep_interruptible(
                DELAY_BETWEEN_TESTS,
                stop_event
            ):

                return

        # ----------------------------------------------------
        # DNS CHECK
        # ----------------------------------------------------

        if stop_event.is_set():

            return

        say(
            main_sock,
            (
                "🌐 Checking DNS for "
                "irc.global-irc.eu..."
            )
        )

        rr_ips, dns_notes = dns_check(
            targets
        )

        if rr_ips:

            say(
                main_sock,
                (
                    "   DNS addresses returned: "
                    +
                    ", ".join(
                        sorted(rr_ips)
                    )
                )
            )

        for note in dns_notes:

            if (
                "no DNS address"
                in note
                or
                "resolution failed"
                in note
            ):

                say(
                    main_sock,
                    f"   ❌ {note}"
                )

            elif (
                "no DNS overlap"
                in note
            ):

                say(
                    main_sock,
                    f"   ℹ️ {note}"
                )

            else:

                say(
                    main_sock,
                    f"   ✅ {note}"
                )

        # ----------------------------------------------------
        # STATISTICS
        # ----------------------------------------------------

        total = len(
            results
        )

        successful = sum(
            1
            for result in results
            if result.ok
        )

        failed = (
            total
            -
            successful
        )

        servers_ok = sum(
            1
            for target in targets
            if any(
                result.ok
                and
                normalize_server_name(
                    result.target
                )
                ==
                normalize_server_name(
                    target.name
                )
                for result in results
            )
        )

        # ----------------------------------------------------
        # FINAL REPORT
        # ----------------------------------------------------

        say(
            main_sock,
            "──────────────────────────────────────────────────────"
        )

        say(
            main_sock,
            "📊 Global-IRC Network Scan complete."
        )

        say(
            main_sock,
            (
                f"🖥️ Servers discovered : "
                f"{len(targets)}"
            )
        )

        say(
            main_sock,
            (
                f"🔌 Connection tests   : "
                f"{total}"
            )
        )

        say(
            main_sock,
            (
                f"✅ Successful tests   : "
                f"{successful}"
            )
        )

        say(
            main_sock,
            (
                f"❌ Failed tests       : "
                f"{failed}"
            )
        )

        say(
            main_sock,
            (
                f"🟢 Servers reachable  : "
                f"{servers_ok}/{len(targets)}"
            )
        )

        # ----------------------------------------------------
        # FAILED CONNECTIONS
        # ----------------------------------------------------

        failed_results = [
            result
            for result in results
            if not result.ok
        ]

        if failed_results:

            say(
                main_sock,
                "⚠️ Failed checks:"
            )

            for result in failed_results:

                say(
                    main_sock,
                    (
                        f"   • {result.target}:"
                        f"{result.port} — "
                        f"{result.detail}"
                    )
                )

        else:

            say(
                main_sock,
                (
                    "🎉 All discovered servers accepted "
                    "an IRC connection on both tested ports."
                )
            )

        # ----------------------------------------------------
        # FINISHED
        # ----------------------------------------------------

        say(
            main_sock,
            (
                "🏁 Scan finished. "
                "Main scanner remains online in #IRCPlus."
            )
        )

    finally:

        SCAN_LOCK.release()


# ============================================================
# IRC COMMAND HANDLER
# ============================================================


def handle_main_command(
    sock: socket.socket,
    line: str
) -> None:

    if " PRIVMSG " not in line:

        return

    match = re.match(
        r":([^!]+)!.* PRIVMSG [^ ]+ :(.+)$",
        line
    )

    if not match:

        return

    text = match.group(
        2
    ).strip().lower()

    # --------------------------------------------------------
    # MANUAL SCAN
    # --------------------------------------------------------

    if text == "!scan":

        # Check whether another scan is already active.

        if not SCAN_LOCK.acquire(
            blocking=False
        ):

            say(
                sock,
                (
                    "ℹ️ A network scan is already running. "
                    "Please wait for it to finish."
                )
            )

            return

        SCAN_LOCK.release()

        # Create a cancellation event for this scan.

        event = threading.Event()

        threading.Thread(
            target=run_scan,
            args=(
                sock,
                event
            ),
            daemon=True
        ).start()


# ============================================================
# MAIN PERMANENT IRC CONNECTION
# ============================================================
#
# THIS IS THE IMPORTANT PART THAT FIXES YOUR DISCONNECT BUG.
#
# A socket.timeout is completely normal on an IRC connection.
# The bot simply continues waiting.
#
# Only an actual closed socket or another real exception causes
# a reconnect.
#
# ============================================================


def main_connection() -> None:

    while True:

        sock: Optional[socket.socket] = None

        # This event belongs to the current main connection.
        #
        # If that connection really dies, the scan is cancelled.

        scan_stop_event = threading.Event()

        try:

            # ------------------------------------------------
            # CONNECT MAIN BOT
            # ------------------------------------------------

            sock = socket.create_connection(
                (
                    MAIN_HOST,
                    MAIN_PORT
                ),
                timeout=SCAN_TIMEOUT
            )

            # ------------------------------------------------
            # IMPORTANT
            # ------------------------------------------------
            #
            # The main IRC connection is allowed to be quiet.
            #
            # socket.timeout below is handled with "continue".
            #
            # It is NOT a disconnect.
            #
            # ------------------------------------------------

            sock.settimeout(
                MAIN_SOCKET_TIMEOUT
            )

            # ------------------------------------------------
            # REGISTER
            # ------------------------------------------------

            irc_send(
                sock,
                f"NICK {MAIN_NICK}"
            )

            irc_send(
                sock,
                (
                    f"USER {MAIN_NICK} 0 * "
                    f":Global-IRC Network Scanner"
                )
            )

            joined = False

            scan_started = False

            buffer = b""

            # ------------------------------------------------
            # MAIN IRC LOOP
            # ------------------------------------------------

            while True:

                try:

                    data = sock.recv(
                        8192
                    )

                except socket.timeout:

                    # ==================================================
                    # THIS IS THE FIX
                    # ==================================================
                    #
                    # No IRC data for 30 seconds is normal.
                    #
                    # DO NOT disconnect.
                    #
                    # DO NOT reconnect.
                    #
                    # Just keep waiting.
                    #
                    # ==================================================

                    continue

                if not data:

                    raise ConnectionError(
                        (
                            "Main IRC connection "
                            "closed by remote host"
                        )
                    )

                buffer += data

                while b"\n" in buffer:

                    raw, buffer = buffer.split(
                        b"\n",
                        1
                    )

                    line = raw.decode(
                        "utf-8",
                        errors="replace"
                    ).rstrip("\r")

                    # ----------------------------------------
                    # PING / PONG
                    # ----------------------------------------

                    if line.startswith(
                        "PING "
                    ):

                        irc_send(
                            sock,
                            "PONG " + line[5:]
                        )

                        continue

                    # ----------------------------------------
                    # IRC WELCOME
                    # ----------------------------------------

                    if (
                        " 001 " in line
                        and
                        not joined
                    ):

                        irc_send(
                            sock,
                            f"JOIN {MAIN_CHANNEL}"
                        )

                        joined = True

                    # ----------------------------------------
                    # FALLBACK JOIN
                    #
                    # 376 = MOTD finished
                    # 422 = MOTD file missing
                    # ----------------------------------------

                    if (
                        (
                            " 376 " in line
                            or
                            " 422 " in line
                        )
                        and
                        not joined
                    ):

                        irc_send(
                            sock,
                            f"JOIN {MAIN_CHANNEL}"
                        )

                        joined = True

                    # ----------------------------------------
                    # AUTOMATIC SCAN
                    #
                    # Start exactly once for this connection.
                    # ----------------------------------------

                    if (
                        joined
                        and
                        not scan_started
                    ):

                        scan_started = True

                        threading.Thread(
                            target=run_scan,
                            args=(
                                sock,
                                scan_stop_event
                            ),
                            daemon=True
                        ).start()

                    # ----------------------------------------
                    # COMMAND HANDLER
                    # ----------------------------------------

                    if joined:

                        handle_main_command(
                            sock,
                            line
                        )

        # ====================================================
        # REAL CONNECTION ERROR
        # ====================================================

        except Exception as exc:

            print(
                f"[MAIN] {exc}",
                flush=True
            )

        finally:

            # ------------------------------------------------
            # STOP CURRENT SCAN
            # ------------------------------------------------
            #
            # If the main bot genuinely disconnected, any scan
            # belonging to this connection must stop.
            #
            # This prevents an old scan from holding SCAN_LOCK
            # while a newly connected GlobalScan starts again.
            #
            # ------------------------------------------------

            scan_stop_event.set()

            # ------------------------------------------------
            # CLOSE MAIN SOCKET
            # ------------------------------------------------

            if sock is not None:

                try:

                    sock.shutdown(
                        socket.SHUT_RDWR
                    )

                except OSError:

                    pass

                try:

                    sock.close()

                except OSError:

                    pass

        # ----------------------------------------------------
        # RECONNECT
        # ----------------------------------------------------

        print(
            "[MAIN] Reconnecting in 5 seconds...",
            flush=True
        )

        time.sleep(
            5
        )


# ============================================================
# PROGRAM START
# ============================================================


def main():

    print(
        "Global-IRC Network Scanner starting...",
        flush=True
    )

    print(
        f"Main server : {MAIN_HOST}:{MAIN_PORT}",
        flush=True
    )

    print(
        f"Main channel: {MAIN_CHANNEL}",
        flush=True
    )

    main_connection()


# ============================================================
# RUN
# ============================================================


if __name__ == "__main__":

    main()

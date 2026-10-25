#!/usr/bin/env python3
"""
LimitServ - Python IRC bot (NeoStats LimitServ port)
====================================================
Automatically manages the user limit (+l) of channels.

Original behaviour:
  limit = current_users + BUFFER
  Only change the limit when the difference is larger than GRACE
  Update every TIMER seconds (and on join/part/kick)

Extra features (this port):
  - Auto OPER on connect
  - Auto-op itself in managed channels via ChanServ (preferred)
    or SAMODE as emergency fallback when the bot is opered

Commands (admin only):
  ADD <channel>     - Start managing a channel
  DEL <channel>     - Stop managing a channel
  LIST              - List managed channels
  SET BUFFER <n>    - Extra slots (default 1)
  SET TIMER <sec>   - Update interval (default 10)
  SET GRACE <n>     - Minimum change before adjusting (default 0)
  SET JOIN <ON|OFF> - Join the managed channels (default ON)
  HELP
"""

import asyncio
import json
import re
from pathlib import Path
from typing import Dict, Optional, Set

# =============================================================================
# CONFIGURATION - edit these values
# =============================================================================
SERVER          = "irc.example.com"
PORT            = 6667
NICK            = "LimitServ"
USERNAME        = "limitserv"
REALNAME        = "LimitServ - NeoStats Python port"
CHANNELS        = ["#services"]          # always-join control channels
ADMIN_NICKS     = {"YourNick", "Admin"}
COMMAND_PREFIX  = "!"
USE_SSL         = False
PASSWORD        = None                   # NickServ password (optional)
SERVER_PASSWORD = None

# --- Oper block ---------------------------------------------------------------
# Leave OPER_USER / OPER_PASS empty to disable auto-oper.
OPER_USER       = "limitserv"            # oper username (or full oper block name)
OPER_PASS       = "your_oper_password"   # oper password

# How the bot tries to gain ops in a managed channel (in order):
#   1. ChanServ OP (preferred)
#   2. SAMODE (only works when the bot is already opered)
CHANSERV_NICK   = "ChanServ"             # change if your network uses a different nick
USE_SAMODE      = True                   # emergency fallback when opered

DATA_FILE       = Path(__file__).parent / "limitserv.json"
# =============================================================================


class LimitServ:
    def __init__(self):
        self.reader: Optional[asyncio.StreamReader] = None
        self.writer: Optional[asyncio.StreamWriter] = None
        self.connected = False
        self.nick = NICK
        self.is_opered = False

        # managed channels -> current known user count
        self.channels: Dict[str, int] = {}
        # last limit we set per channel
        self.last_limit: Dict[str, int] = {}
        # users we currently know are in each channel
        self.channel_users: Dict[str, Set[str]] = {}
        # whether we currently have +o in the channel
        self.have_ops: Dict[str, bool] = {}
        # last time we tried to regain ops (avoid flood)
        self.last_op_attempt: Dict[str, float] = {}

        # settings (same defaults as original)
        self.buffer = 1
        self.timer = 10
        self.grace = 0
        self.do_join = True

        self.load_data()
        self._timer_task: Optional[asyncio.Task] = None

    # ------------------------------------------------------------------ data
    def load_data(self):
        if DATA_FILE.is_file():
            try:
                with open(DATA_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self.channels = {c.lower(): 0 for c in data.get("channels", [])}
                self.buffer = int(data.get("buffer", 1))
                self.timer = int(data.get("timer", 10))
                self.grace = int(data.get("grace", 0))
                self.do_join = bool(data.get("join", True))
                print(f"[+] Loaded {len(self.channels)} channels, "
                      f"buffer={self.buffer} timer={self.timer} grace={self.grace}")
            except Exception as e:
                print(f"[!] Failed to load data: {e}")
        else:
            self.save_data()

    def save_data(self):
        data = {
            "channels": sorted(self.channels.keys()),
            "buffer": self.buffer,
            "timer": self.timer,
            "grace": self.grace,
            "join": self.do_join,
        }
        try:
            with open(DATA_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"[!] Failed to save data: {e}")

    # ------------------------------------------------------------------ IRC
    async def connect(self):
        ssl_ctx = True if USE_SSL else None
        print(f"[*] Connecting to {SERVER}:{PORT} ...")
        self.reader, self.writer = await asyncio.open_connection(
            SERVER, PORT, ssl=ssl_ctx
        )
        self.connected = True
        self.is_opered = False
        if SERVER_PASSWORD:
            await self.send(f"PASS {SERVER_PASSWORD}")
        await self.send(f"NICK {self.nick}")
        await self.send(f"USER {USERNAME} 0 * :{REALNAME}")

    async def send(self, line: str):
        if self.writer:
            print(f">>> {line}")
            self.writer.write((line + "\r\n").encode("utf-8", errors="replace"))
            await self.writer.drain()

    async def privmsg(self, target: str, message: str):
        while message:
            chunk = message[:400]
            message = message[400:]
            await self.send(f"PRIVMSG {target} :{chunk}")

    def is_admin(self, nick: str) -> bool:
        return nick.lower() in {n.lower() for n in ADMIN_NICKS}

    # ------------------------------------------------------------------ oper / ops
    async def do_oper(self):
        """Try to OPER ourselves."""
        if not OPER_USER or not OPER_PASS:
            return
        print("[*] Sending OPER ...")
        await self.send(f"OPER {OPER_USER} {OPER_PASS}")

    async def ensure_ops(self, channel: str):
        """
        Make sure we have +o in the channel.
        Prefer ChanServ OP, fall back to SAMODE when opered.
        Rate-limited to once every 30 seconds per channel.
        """
        channel = channel.lower()
        if self.have_ops.get(channel):
            return

        now = asyncio.get_event_loop().time()
        last = self.last_op_attempt.get(channel, 0)
        if now - last < 30:
            return
        self.last_op_attempt[channel] = now

        # 1. Preferred: ChanServ
        print(f"[*] Requesting ops from {CHANSERV_NICK} on {channel}")
        await self.privmsg(CHANSERV_NICK, f"OP {channel} {self.nick}")

        # Give ChanServ a moment; if still no ops and we are opered, use SAMODE
        await asyncio.sleep(2)
        if not self.have_ops.get(channel) and self.is_opered and USE_SAMODE:
            print(f"[*] ChanServ did not op us – using SAMODE on {channel}")
            await self.send(f"SAMODE {channel} +o {self.nick}")

    # ------------------------------------------------------------------ limit logic
    async def set_limit(self, channel: str):
        """Apply +l = users + buffer, respecting grace. Ensures ops first."""
        channel = channel.lower()
        if channel not in self.channels:
            return

        # Make sure we can actually set the mode
        if not self.have_ops.get(channel):
            await self.ensure_ops(channel)
            # if still no ops, skip this round
            if not self.have_ops.get(channel):
                return

        users = len(self.channel_users.get(channel, set()))
        if users == 0 and self.channels.get(channel, 0) > 0:
            users = self.channels[channel]

        new_limit = users + self.buffer
        old_limit = self.last_limit.get(channel, 0)

        if abs(new_limit - old_limit) < self.grace and old_limit != 0:
            return
        if new_limit == old_limit:
            return

        await self.send(f"MODE {channel} +l {new_limit}")
        self.last_limit[channel] = new_limit
        self.channels[channel] = users
        print(f"[limit] {channel} -> +l {new_limit} (users={users})")

    async def update_all_limits(self):
        for chan in list(self.channels.keys()):
            await self.set_limit(chan)

    async def timer_loop(self):
        while self.connected:
            await asyncio.sleep(self.timer)
            if self.connected:
                await self.update_all_limits()

    # ------------------------------------------------------------------ commands
    def parse_command(self, message: str, is_channel: bool) -> Optional[tuple]:
        msg = message.strip()
        for prefix in (f"{self.nick}:", f"{self.nick},",
                       f"{self.nick.lower()}:", f"{self.nick.lower()},",
                       "LS:", "LS,"):
            if msg.lower().startswith(prefix.lower()):
                msg = msg[len(prefix):].strip()
                break
        else:
            if is_channel:
                if not msg.startswith(COMMAND_PREFIX):
                    return None
                msg = msg[len(COMMAND_PREFIX):].strip()

        if not msg:
            return None
        parts = msg.split(None, 1)
        cmd = parts[0].upper()
        args = parts[1] if len(parts) > 1 else ""
        return cmd, args

    async def handle_command(self, nick: str, target: str, message: str, is_channel: bool):
        parsed = self.parse_command(message, is_channel)
        if not parsed:
            return
        cmd, args = parsed
        reply_to = target if is_channel else nick

        if cmd in ("HELP", "?"):
            await self.cmd_help(reply_to)
            return

        if not self.is_admin(nick):
            await self.privmsg(reply_to, "Access denied.")
            return

        if cmd == "ADD":
            await self.cmd_add(reply_to, args)
        elif cmd == "DEL":
            await self.cmd_del(reply_to, args)
        elif cmd == "LIST":
            await self.cmd_list(reply_to)
        elif cmd == "SET":
            await self.cmd_set(reply_to, args)
        elif cmd in ("ABOUT", "VERSION"):
            await self.privmsg(reply_to,
                "LimitServ - Python port of NeoStats LimitServ | "
                "Keeps channel +l = users + buffer | auto-oper + auto-op")
        else:
            await self.privmsg(reply_to, "Unknown command. Try HELP.")

    async def cmd_help(self, target: str):
        await self.privmsg(target,
            "LimitServ commands (admin): "
            "ADD <#chan>, DEL <#chan>, LIST, "
            "SET BUFFER <n>, SET TIMER <sec>, SET GRACE <n>, SET JOIN <ON|OFF>, HELP")
        await self.privmsg(target,
            f"Settings: BUFFER={self.buffer} TIMER={self.timer}s "
            f"GRACE={self.grace} JOIN={'ON' if self.do_join else 'OFF'} "
            f"| opered={'yes' if self.is_opered else 'no'}")

    async def cmd_add(self, target: str, args: str):
        chan = args.strip().split()[0] if args.strip() else ""
        if not chan.startswith("#") and not chan.startswith("&"):
            await self.privmsg(target, "Syntax: ADD <#channel>")
            return
        key = chan.lower()
        if key in self.channels:
            await self.privmsg(target, f"{chan} is already managed.")
            return
        self.channels[key] = 0
        self.channel_users[key] = set()
        self.have_ops[key] = False
        self.save_data()
        await self.privmsg(target, f"Added {chan} to the limit list.")
        if self.do_join:
            await self.send(f"JOIN {chan}")
            await self.send(f"NAMES {chan}")
            await self.ensure_ops(chan)

    async def cmd_del(self, target: str, args: str):
        chan = args.strip().split()[0] if args.strip() else ""
        if not chan:
            await self.privmsg(target, "Syntax: DEL <#channel>")
            return
        key = chan.lower()
        if key not in self.channels:
            await self.privmsg(target, f"{chan} is not managed.")
            return
        del self.channels[key]
        self.channel_users.pop(key, None)
        self.last_limit.pop(key, None)
        self.have_ops.pop(key, None)
        self.last_op_attempt.pop(key, None)
        self.save_data()
        await self.privmsg(target, f"Removed {chan} from the limit list.")
        if self.do_join:
            await self.send(f"PART {chan}")

    async def cmd_list(self, target: str):
        if not self.channels:
            await self.privmsg(target, "No channels managed.")
            return
        parts = []
        for chan, count in sorted(self.channels.items()):
            users = len(self.channel_users.get(chan, set())) or count
            lim = self.last_limit.get(chan, "?")
            ops = "op" if self.have_ops.get(chan) else "no-op"
            parts.append(f"{chan} (users={users}, limit={lim}, {ops})")
        await self.privmsg(target, "Managed: " + ", ".join(parts))

    async def cmd_set(self, target: str, args: str):
        parts = args.split(None, 1)
        if len(parts) < 2:
            await self.privmsg(target,
                "Syntax: SET BUFFER <n> | SET TIMER <sec> | SET GRACE <n> | SET JOIN <ON|OFF>")
            return
        setting, value = parts[0].upper(), parts[1].strip()

        if setting == "BUFFER":
            try:
                n = int(value)
                if not 0 <= n <= 100:
                    raise ValueError
                self.buffer = n
                self.save_data()
                await self.privmsg(target, f"BUFFER set to {n}")
                await self.update_all_limits()
            except ValueError:
                await self.privmsg(target, "BUFFER must be 0-100")
        elif setting == "TIMER":
            try:
                n = int(value)
                if not 1 <= n <= 3600:
                    raise ValueError
                self.timer = n
                self.save_data()
                await self.privmsg(target, f"TIMER set to {n} seconds")
            except ValueError:
                await self.privmsg(target, "TIMER must be 1-3600")
        elif setting == "GRACE":
            try:
                n = int(value)
                if not 0 <= n <= 99:
                    raise ValueError
                self.grace = n
                self.save_data()
                await self.privmsg(target, f"GRACE set to {n}")
            except ValueError:
                await self.privmsg(target, "GRACE must be 0-99")
        elif setting == "JOIN":
            on = value.upper() in ("ON", "1", "YES", "TRUE")
            self.do_join = on
            self.save_data()
            await self.privmsg(target, f"JOIN set to {'ON' if on else 'OFF'}")
            if on:
                for chan in self.channels:
                    await self.send(f"JOIN {chan}")
                    await self.ensure_ops(chan)
            else:
                for chan in self.channels:
                    await self.send(f"PART {chan}")
        else:
            await self.privmsg(target, "Unknown setting. Use BUFFER, TIMER, GRACE or JOIN.")

    # ------------------------------------------------------------------ events
    async def handle_line(self, line: str):
        line = line.rstrip("\r\n")
        if not line:
            return
        print(f"<<< {line}")

        if line.startswith("PING"):
            await self.send("PONG" + line[4:])
            return

        # Successful registration
        if " 001 " in line:
            print("[+] Connected and registered")
            if PASSWORD:
                await self.privmsg("NickServ", f"IDENTIFY {PASSWORD}")
            # Oper as soon as possible
            await self.do_oper()
            for chan in CHANNELS:
                await self.send(f"JOIN {chan}")
            if self.do_join:
                for chan in self.channels:
                    await self.send(f"JOIN {chan}")
                    await self.send(f"NAMES {chan}")
            if self._timer_task:
                self._timer_task.cancel()
            self._timer_task = asyncio.create_task(self.timer_loop())
            return

        # OPER success (381)
        if " 381 " in line:
            self.is_opered = True
            print("[+] Successfully opered")
            # try to regain ops on all managed channels
            for chan in self.channels:
                if not self.have_ops.get(chan):
                    await self.ensure_ops(chan)
            return

        # OPER failure (491 / 464 / 491 etc.) – just log
        if re.search(r" (491|464|461) ", line) and "OPER" in line.upper():
            print("[!] OPER failed – check OPER_USER / OPER_PASS")
            return

        # MODE changes that affect us (gain/lose +o)
        # :nick MODE #chan +o LimitServ
        # :nick MODE #chan -o LimitServ
        m = re.match(r":[^ ]+ MODE ([^ ]+) ([+-][^\s]*)(?: (.*))?", line)
        if m:
            chan = m.group(1).lower()
            modes = m.group(2)
            params = (m.group(3) or "").split()
            if chan in self.channels:
                # simple parse for o/v modes that take a nick parameter
                param_idx = 0
                for ch in modes[1:]:
                    if ch in "ovhqa":
                        if param_idx < len(params):
                            target_nick = params[param_idx]
                            param_idx += 1
                            if target_nick.lower() == self.nick.lower():
                                if modes[0] == "+":
                                    self.have_ops[chan] = True
                                    print(f"[+] Gained ops on {chan}")
                                else:
                                    self.have_ops[chan] = False
                                    print(f"[-] Lost ops on {chan}")
                                    # try to get them back
                                    await self.ensure_ops(chan)
            return

        # NAMES reply (353) – also detect if we already have ops
        m = re.match(r":[^ ]+ 353 [^ ]+ . ([^ ]+) :(.*)", line)
        if m:
            chan = m.group(1).lower()
            if chan in self.channels:
                names = m.group(2).split()
                users = set()
                we_have_ops = False
                for n in names:
                    prefixes = ""
                    while n and n[0] in "~&@%+":
                        prefixes += n[0]
                        n = n[1:]
                    if n.lower() == self.nick.lower():
                        if "@" in prefixes or "&" in prefixes or "~" in prefixes:
                            we_have_ops = True
                    else:
                        users.add(n.lower())
                self.channel_users[chan] = users
                self.channels[chan] = len(users)
                self.have_ops[chan] = we_have_ops
                if not we_have_ops:
                    await self.ensure_ops(chan)
            return

        # End of NAMES (366)
        m = re.match(r":[^ ]+ 366 [^ ]+ ([^ ]+)", line)
        if m:
            chan = m.group(1).lower()
            if chan in self.channels:
                await self.set_limit(chan)
            return

        # JOIN
        m = re.match(r":([^!]+)![^ ]+ JOIN :?([^ ]+)", line)
        if m:
            nick, chan = m.group(1), m.group(2).lower()
            if chan in self.channels:
                if nick.lower() == self.nick.lower():
                    # we just joined – request names + try for ops
                    await self.send(f"NAMES {chan}")
                    await self.ensure_ops(chan)
                else:
                    self.channel_users.setdefault(chan, set()).add(nick.lower())
                    self.channels[chan] = len(self.channel_users[chan])
                    await self.set_limit(chan)
            return

        # PART
        m = re.match(r":([^!]+)![^ ]+ PART ([^ ]+)", line)
        if m:
            nick, chan = m.group(1).lower(), m.group(2).lower()
            if chan in self.channels:
                if nick == self.nick.lower():
                    self.have_ops[chan] = False
                else:
                    self.channel_users.get(chan, set()).discard(nick)
                    self.channels[chan] = len(self.channel_users.get(chan, set()))
                    await self.set_limit(chan)
            return

        # KICK
        m = re.match(r":[^ ]+ KICK ([^ ]+) ([^ ]+)", line)
        if m:
            chan, nick = m.group(1).lower(), m.group(2).lower()
            if chan in self.channels:
                if nick == self.nick.lower():
                    self.have_ops[chan] = False
                    # rejoin and try again
                    await asyncio.sleep(1)
                    await self.send(f"JOIN {chan}")
                else:
                    self.channel_users.get(chan, set()).discard(nick)
                    self.channels[chan] = len(self.channel_users.get(chan, set()))
                    await self.set_limit(chan)
            return

        # QUIT
        m = re.match(r":([^!]+)![^ ]+ QUIT", line)
        if m:
            nick = m.group(1).lower()
            for chan, users in list(self.channel_users.items()):
                if nick in users:
                    users.discard(nick)
                    self.channels[chan] = len(users)
                    await self.set_limit(chan)
            return

        # PRIVMSG
        m = re.match(r":([^!]+)![^ ]+ PRIVMSG ([^ ]+) :(.*)", line)
        if m:
            nick, target, message = m.group(1), m.group(2), m.group(3)
            is_channel = target.startswith("#") or target.startswith("&")
            await self.handle_command(nick, target, message, is_channel)

    async def run(self):
        backoff = 5
        while True:
            try:
                await self.connect()
                while self.connected:
                    line = await self.reader.readline()
                    if not line:
                        break
                    await self.handle_line(line.decode("utf-8", errors="replace"))
            except Exception as e:
                print(f"[!] Connection error: {e}")
            finally:
                self.connected = False
                self.is_opered = False
                if self._timer_task:
                    self._timer_task.cancel()
                    self._timer_task = None
                if self.writer:
                    self.writer.close()
                    try:
                        await self.writer.wait_closed()
                    except Exception:
                        pass
            print(f"[*] Reconnecting in {backoff} seconds...")
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60)


def main():
    bot = LimitServ()
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        print("\n[*] Shutting down LimitServ")


if __name__ == "__main__":
    main()

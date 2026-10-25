#!/usr/bin/env python3
"""
LimitServ - Python IRC bot (NeoStats LimitServ port)
====================================================
Automatically manages the user limit (+l) of channels.

Original behaviour:
  limit = current_users + BUFFER
  Only change the limit when the difference is larger than GRACE
  Update every TIMER seconds (and on join/part/kick)

Commands (admin only):
  ADD <channel>     - Start managing a channel
  DEL <channel>     - Stop managing a channel
  LIST              - List managed channels
  SET BUFFER <n>    - Extra slots (default 1)
  SET TIMER <sec>   - Update interval (default 10)
  SET GRACE <n>     - Minimum change before adjusting (default 0)
  SET JOIN <ON|OFF> - Join the managed channels (default ON)
  HELP

IMPORTANT
---------
The bot must be opped (or have the privilege to set modes) in the
channels it manages. As a normal client bot it can only see channels
it has joined.
"""

import asyncio
import json
import re
import time
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
CHANNELS        = ["#services"]          # channels the bot always joins (control)
ADMIN_NICKS     = {"YourNick", "Admin"}
COMMAND_PREFIX  = "!"
USE_SSL         = False
PASSWORD        = None
SERVER_PASSWORD = None

DATA_FILE       = Path(__file__).parent / "limitserv.json"
# =============================================================================


class LimitServ:
    def __init__(self):
        self.reader: Optional[asyncio.StreamReader] = None
        self.writer: Optional[asyncio.StreamWriter] = None
        self.connected = False
        self.nick = NICK

        # managed channels -> current known user count
        self.channels: Dict[str, int] = {}
        # last limit we set per channel
        self.last_limit: Dict[str, int] = {}
        # users we currently know are in each channel (for counting)
        self.channel_users: Dict[str, Set[str]] = {}

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

    # ------------------------------------------------------------------ limit logic
    async def set_limit(self, channel: str):
        """Apply +l = users + buffer, respecting grace."""
        channel = channel.lower()
        if channel not in self.channels:
            return

        users = len(self.channel_users.get(channel, set()))
        # fallback to the stored count if we somehow have no user list yet
        if users == 0 and self.channels.get(channel, 0) > 0:
            users = self.channels[channel]

        new_limit = users + self.buffer
        old_limit = self.last_limit.get(channel, 0)

        # original logic: only change when difference >= grace
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
                "Keeps channel +l = users + buffer")
        else:
            await self.privmsg(reply_to, f"Unknown command. Try HELP.")

    async def cmd_help(self, target: str):
        await self.privmsg(target,
            "LimitServ commands (admin): "
            "ADD <#chan>, DEL <#chan>, LIST, "
            "SET BUFFER <n>, SET TIMER <sec>, SET GRACE <n>, SET JOIN <ON|OFF>, HELP")
        await self.privmsg(target,
            f"Current settings: BUFFER={self.buffer} TIMER={self.timer}s "
            f"GRACE={self.grace} JOIN={'ON' if self.do_join else 'OFF'}")

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
        self.save_data()
        await self.privmsg(target, f"Added {chan} to the limit list.")
        if self.do_join:
            await self.send(f"JOIN {chan}")
            # request names so we get an initial count
            await self.send(f"NAMES {chan}")

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
            parts.append(f"{chan} (users={users}, limit={lim})")
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
                if n < 0 or n > 100:
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
                if n < 1 or n > 3600:
                    raise ValueError
                self.timer = n
                self.save_data()
                await self.privmsg(target, f"TIMER set to {n} seconds")
            except ValueError:
                await self.privmsg(target, "TIMER must be 1-3600")
        elif setting == "GRACE":
            try:
                n = int(value)
                if n < 0 or n >= self.buffer and self.buffer > 0:
                    # original rule: grace < buffer
                    pass
                if n < 0 or n > 99:
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

        if " 001 " in line:
            print("[+] Connected and registered")
            if PASSWORD:
                await self.privmsg("NickServ", f"IDENTIFY {PASSWORD}")
            for chan in CHANNELS:
                await self.send(f"JOIN {chan}")
            if self.do_join:
                for chan in self.channels:
                    await self.send(f"JOIN {chan}")
                    await self.send(f"NAMES {chan}")
            # start the periodic timer
            if self._timer_task:
                self._timer_task.cancel()
            self._timer_task = asyncio.create_task(self.timer_loop())
            return

        # NAMES reply (353)
        # :server 353 me = #chan :nick1 nick2 @nick3
        m = re.match(r":[^ ]+ 353 [^ ]+ . ([^ ]+) :(.*)", line)
        if m:
            chan = m.group(1).lower()
            if chan in self.channels:
                names = m.group(2).split()
                users = set()
                for n in names:
                    # strip prefixes @+%&~ etc.
                    clean = n.lstrip("~&@%+")
                    if clean.lower() != self.nick.lower():
                        users.add(clean.lower())
                self.channel_users[chan] = users
                self.channels[chan] = len(users)
            return

        # End of NAMES (366) – good moment to set limit
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
            if chan in self.channels and nick.lower() != self.nick.lower():
                self.channel_users.setdefault(chan, set()).add(nick.lower())
                self.channels[chan] = len(self.channel_users[chan])
                await self.set_limit(chan)
            return

        # PART / KICK / QUIT
        m = re.match(r":([^!]+)![^ ]+ PART ([^ ]+)", line)
        if m:
            nick, chan = m.group(1).lower(), m.group(2).lower()
            if chan in self.channels:
                self.channel_users.get(chan, set()).discard(nick)
                self.channels[chan] = len(self.channel_users.get(chan, set()))
                await self.set_limit(chan)
            return

        m = re.match(r":[^ ]+ KICK ([^ ]+) ([^ ]+)", line)
        if m:
            chan, nick = m.group(1).lower(), m.group(2).lower()
            if chan in self.channels:
                self.channel_users.get(chan, set()).discard(nick)
                self.channels[chan] = len(self.channel_users.get(chan, set()))
                await self.set_limit(chan)
            return

        m = re.match(r":([^!]+)![^ ]+ QUIT", line)
        if m:
            nick = m.group(1).lower()
            for chan, users in self.channel_users.items():
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

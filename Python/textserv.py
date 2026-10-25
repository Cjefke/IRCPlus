#!/usr/bin/env python3
"""
TextServ - Python IRC bot (NeoStats TextServ port)
==================================================
Configurable text / factoid service.

Original NeoStats TextServ allowed defining custom commands with
output text, optional parameters and actions. This is a practical
Python re-implementation.

Commands (admin):
  ADD <name> <response...>     - Create or overwrite a text command
  DEL <name>                   - Delete a command
  LIST                         - List all commands
  SET <name> <response...>     - Alias for ADD

Anyone can trigger a command by name (with prefix or by addressing the bot).

Placeholders in responses:
  %n / %N   - nick of the user who triggered the command
  %c / %C   - channel (or "private")
  %b / %B   - bot nick
  %1 %2 ..  - arguments given after the command
  %*        - all remaining arguments

Data is stored in textserv.json next to this script.
"""

import asyncio
import json
import re
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Any

# =============================================================================
# CONFIGURATION - edit these values
# =============================================================================
SERVER          = "irc.example.com"
PORT            = 6667
NICK            = "TextServ"
USERNAME        = "textserv"
REALNAME        = "TextServ - NeoStats Python port"
CHANNELS        = ["#services", "#chat"]
ADMIN_NICKS     = {"YourNick", "Admin"}
COMMAND_PREFIX  = "!"
USE_SSL         = False
PASSWORD        = None
SERVER_PASSWORD = None

# File where custom commands are saved
DATA_FILE       = Path(__file__).parent / "textserv.json"
# =============================================================================


class TextServ:
    def __init__(self):
        self.reader: Optional[asyncio.StreamReader] = None
        self.writer: Optional[asyncio.StreamWriter] = None
        self.connected = False
        self.nick = NICK
        self.commands: Dict[str, Dict[str, Any]] = {}
        self.load_data()

    def load_data(self):
        if DATA_FILE.is_file():
            try:
                with open(DATA_FILE, "r", encoding="utf-8") as f:
                    self.commands = json.load(f)
                print(f"[+] Loaded {len(self.commands)} commands from {DATA_FILE}")
            except Exception as e:
                print(f"[!] Failed to load data: {e}")
                self.commands = {}
        else:
            # seed with a few example commands
            self.commands = {
                "hello": {
                    "output": "Hello %n! Welcome to the network.",
                    "action": False,
                },
                "rules": {
                    "output": "Be nice. No spam. Have fun!",
                    "action": False,
                },
                "hug": {
                    "output": "hugs %1",
                    "action": True,
                },
            }
            self.save_data()
            print("[+] Created default commands")

    def save_data(self):
        try:
            with open(DATA_FILE, "w", encoding="utf-8") as f:
                json.dump(self.commands, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"[!] Failed to save data: {e}")

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

    async def action(self, target: str, message: str):
        await self.send(f"PRIVMSG {target} :\x01ACTION {message}\x01")

    def is_admin(self, nick: str) -> bool:
        return nick.lower() in {n.lower() for n in ADMIN_NICKS}

    def expand(self, text: str, nick: str, channel: str, args: List[str]) -> str:
        """Replace placeholders."""
        def repl_arg(m):
            idx = int(m.group(1)) - 1
            return args[idx] if 0 <= idx < len(args) else ""

        text = re.sub(r"%(\d+)", repl_arg, text)
        text = text.replace("%*", " ".join(args))
        text = text.replace("%n", nick).replace("%N", nick)
        text = text.replace("%c", channel).replace("%C", channel)
        text = text.replace("%b", self.nick).replace("%B", self.nick)
        return text

    def parse_message(self, message: str, is_channel: bool) -> Optional[tuple]:
        """
        Returns (cmd, args_list) or None.
        """
        msg = message.strip()
        addressed = False

        for prefix in (f"{self.nick}:", f"{self.nick},",
                       f"{self.nick.lower()}:", f"{self.nick.lower()},",
                       "TS:", "TS,"):
            if msg.lower().startswith(prefix.lower()):
                msg = msg[len(prefix):].strip()
                addressed = True
                break

        if is_channel and not addressed:
            if not msg.startswith(COMMAND_PREFIX):
                return None
            msg = msg[len(COMMAND_PREFIX):].strip()

        if not msg:
            return None

        parts = msg.split()
        cmd = parts[0].lower()
        args = parts[1:]
        return cmd, args

    async def handle_command(self, nick: str, target: str, message: str, is_channel: bool):
        parsed = self.parse_message(message, is_channel)
        if not parsed:
            return
        cmd, args = parsed
        reply_to = target if is_channel else nick
        channel = target if is_channel else "private"

        # Built-in admin / meta commands
        if cmd in ("help", "?"):
            await self.cmd_help(reply_to, args)
            return
        if cmd == "list":
            await self.cmd_list(reply_to, nick)
            return
        if cmd in ("add", "set"):
            if not self.is_admin(nick):
                await self.privmsg(reply_to, "Access denied.")
                return
            await self.cmd_add(reply_to, args)
            return
        if cmd == "del":
            if not self.is_admin(nick):
                await self.privmsg(reply_to, "Access denied.")
                return
            await self.cmd_del(reply_to, args)
            return
        if cmd in ("about", "version"):
            await self.privmsg(reply_to,
                "TextServ - Python port of NeoStats TextServ | "
                "Commands: LIST, ADD, DEL, HELP + any custom command")
            return

        # Custom command?
        if cmd in self.commands:
            entry = self.commands[cmd]
            output = entry.get("output", "")
            is_action = entry.get("action", False)
            text = self.expand(output, nick, channel, args)
            if is_action:
                await self.action(reply_to, text)
            else:
                await self.privmsg(reply_to, text)
            return

        # Unknown command – only reply if addressed or private
        if not is_channel or message.lower().startswith(self.nick.lower()):
            await self.privmsg(reply_to, f"Unknown command '{cmd}'. Try HELP or LIST.")

    async def cmd_help(self, target: str, args: List[str]):
        if not args:
            await self.privmsg(target,
                "TextServ: LIST | ADD <name> <text...> | DEL <name> | "
                "HELP [cmd] | or any custom command. "
                "Placeholders: %n (nick), %c (channel), %b (bot), %1 %2 %* (args)")
            return
        topic = args[0].lower()
        if topic in ("add", "set"):
            await self.privmsg(target,
                "ADD <name> <response...>  - Create/update a command (admin). "
                "Prefix the response with '/me ' to make it an action.")
        elif topic == "del":
            await self.privmsg(target, "DEL <name> - Remove a command (admin).")
        elif topic == "list":
            await self.privmsg(target, "LIST - Show all defined commands.")
        elif topic in self.commands:
            entry = self.commands[topic]
            kind = "action" if entry.get("action") else "text"
            await self.privmsg(target, f"{topic} ({kind}): {entry.get('output', '')}")
        else:
            await self.privmsg(target, f"No help for '{topic}'.")

    async def cmd_list(self, target: str, nick: str):
        if not self.commands:
            await self.privmsg(target, "No commands defined.")
            return
        names = sorted(self.commands.keys())
        # split into multiple messages if needed
        chunk = []
        length = 0
        for name in names:
            if length + len(name) + 2 > 350:
                await self.privmsg(target, "Commands: " + ", ".join(chunk))
                chunk = []
                length = 0
            chunk.append(name)
            length += len(name) + 2
        if chunk:
            await self.privmsg(target, "Commands: " + ", ".join(chunk))

    async def cmd_add(self, target: str, args: List[str]):
        if len(args) < 2:
            await self.privmsg(target, "Syntax: ADD <name> <response text...>")
            return
        name = args[0].lower()
        if not re.match(r"^[a-z0-9_-]+$", name):
            await self.privmsg(target, "Invalid command name (use a-z 0-9 _ -).")
            return
        if name in ("help", "list", "add", "set", "del", "about", "version", "?"):
            await self.privmsg(target, "That name is reserved.")
            return

        response = " ".join(args[1:])
        is_action = False
        if response.lower().startswith("/me "):
            is_action = True
            response = response[4:]
        elif response.lower().startswith("\x01action "):
            is_action = True
            response = response[8:].rstrip("\x01")

        self.commands[name] = {
            "output": response,
            "action": is_action,
        }
        self.save_data()
        kind = "action" if is_action else "text"
        await self.privmsg(target, f"Command '{name}' saved ({kind}).")

    async def cmd_del(self, target: str, args: List[str]):
        if not args:
            await self.privmsg(target, "Syntax: DEL <name>")
            return
        name = args[0].lower()
        if name not in self.commands:
            await self.privmsg(target, f"Command '{name}' does not exist.")
            return
        del self.commands[name]
        self.save_data()
        await self.privmsg(target, f"Command '{name}' deleted.")

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
            return

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
    bot = TextServ()
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        print("\n[*] Shutting down TextServ")


if __name__ == "__main__":
    main()

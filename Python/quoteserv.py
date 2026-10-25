#!/usr/bin/env python3
"""
QuoteServ - Python IRC bot (NeoStats QuoteServ port)
====================================================
Original NeoStats module converted to a standalone Python IRC client bot.

Commands (via private message or in channel with prefix):
  QUOTE [database]     - Random quote (optionally from specific database)
  LIST                 - List loaded databases
  ADD <database>       - Load / reload a database file (admin)
  DEL <database>       - Unload a database (admin)
  HELP [command]       - Show help

Configuration is at the top of this file.
"""

import asyncio
import random
import re
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set

# =============================================================================
# CONFIGURATION - edit these values
# =============================================================================
SERVER          = "irc.example.com"
PORT            = 6667
NICK            = "QuoteServ"
USERNAME        = "quoteserv"
REALNAME        = "QuoteServ - NeoStats Python port"
CHANNELS        = ["#services", "#quotes"]   # channels to join
ADMIN_NICKS     = {"YourNick", "Admin"}      # nicks allowed to use ADD/DEL
COMMAND_PREFIX  = "!"                       # also reacts to "QuoteServ:" or "QS:"
USE_SSL         = False
PASSWORD        = None                      # NickServ password (optional)
SERVER_PASSWORD = None                      # server password if any

# Directory containing quote databases (one quote per line)
QUOTES_DIR      = Path(__file__).parent / "quotes"

# Give a random quote when someone joins a channel the bot is in?
SIGNON_QUOTE    = False
# =============================================================================


class QuoteDatabase:
    def __init__(self, name: str, filepath: Path):
        self.name = name
        self.filepath = filepath
        self.quotes: List[str] = []
        self.load()

    def load(self) -> int:
        self.quotes = []
        if not self.filepath.is_file():
            return 0
        with open(self.filepath, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    self.quotes.append(line)
        return len(self.quotes)

    def random_quote(self) -> Optional[str]:
        if not self.quotes:
            return None
        return random.choice(self.quotes)


class QuoteServ:
    def __init__(self):
        self.reader: Optional[asyncio.StreamReader] = None
        self.writer: Optional[asyncio.StreamWriter] = None
        self.databases: Dict[str, QuoteDatabase] = {}
        self.connected = False
        self.nick = NICK
        self.load_all_databases()

    def load_all_databases(self):
        self.databases.clear()
        if not QUOTES_DIR.is_dir():
            print(f"[!] Quotes directory not found: {QUOTES_DIR}")
            return
        for path in sorted(QUOTES_DIR.iterdir()):
            if path.is_file() and not path.name.startswith("."):
                name = path.stem.lower()
                db = QuoteDatabase(name, path)
                if db.quotes:
                    self.databases[name] = db
                    print(f"[+] Loaded database '{name}' ({len(db.quotes)} quotes)")

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
        # Split long messages
        while message:
            chunk = message[:400]
            message = message[400:]
            await self.send(f"PRIVMSG {target} :{chunk}")

    async def notice(self, target: str, message: str):
        await self.send(f"NOTICE {target} :{message}")

    def is_admin(self, nick: str) -> bool:
        return nick.lower() in {n.lower() for n in ADMIN_NICKS}

    def parse_command(self, message: str, from_channel: bool) -> Optional[tuple]:
        """Return (cmd, args) or None"""
        msg = message.strip()
        # Direct addressing
        for prefix in (f"{self.nick}:", f"{self.nick},", "QS:", "QS,",
                       f"{self.nick.lower()}:", f"{self.nick.lower()},"):
            if msg.lower().startswith(prefix.lower()):
                msg = msg[len(prefix):].strip()
                break
        else:
            if from_channel:
                if not msg.startswith(COMMAND_PREFIX):
                    return None
                msg = msg[len(COMMAND_PREFIX):].strip()
            # private message: always treat as command

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
            await self.cmd_help(reply_to, args)
        elif cmd == "QUOTE":
            await self.cmd_quote(reply_to, args)
        elif cmd == "LIST":
            await self.cmd_list(reply_to)
        elif cmd == "ADD":
            if not self.is_admin(nick):
                await self.privmsg(reply_to, "Access denied.")
                return
            await self.cmd_add(reply_to, args)
        elif cmd == "DEL":
            if not self.is_admin(nick):
                await self.privmsg(reply_to, "Access denied.")
                return
            await self.cmd_del(reply_to, args)
        elif cmd in ("ABOUT", "VERSION"):
            await self.privmsg(reply_to,
                "QuoteServ - Python port of NeoStats QuoteServ | "
                "Commands: QUOTE [db], LIST, ADD <db>, DEL <db>, HELP")

    async def cmd_help(self, target: str, args: str):
        topic = args.strip().upper()
        if not topic or topic == "HELP":
            await self.privmsg(target,
                "QuoteServ commands: QUOTE [database], LIST, ADD <database>, "
                "DEL <database>, HELP [command].  Use HELP <command> for details.")
        elif topic == "QUOTE":
            await self.privmsg(target,
                "QUOTE [database] - Get a random quote. "
                "Optionally specify a database name (see LIST).")
        elif topic == "LIST":
            await self.privmsg(target, "LIST - Show all loaded quote databases.")
        elif topic == "ADD":
            await self.privmsg(target,
                "ADD <database> - Load or reload a database file from the quotes directory (admin only).")
        elif topic == "DEL":
            await self.privmsg(target,
                "DEL <database> - Unload a database (admin only).")
        else:
            await self.privmsg(target, f"No help available for '{args}'.")

    async def cmd_quote(self, target: str, args: str):
        dbname = args.strip().lower()
        if dbname:
            db = self.databases.get(dbname)
            if not db:
                await self.privmsg(target, f"Unknown database '{dbname}'. Use LIST to see available databases.")
                return
            quote = db.random_quote()
            if quote:
                await self.privmsg(target, f"[{dbname}] {quote}")
            else:
                await self.privmsg(target, f"Database '{dbname}' is empty.")
        else:
            if not self.databases:
                await self.privmsg(target, "No quote databases loaded.")
                return
            # pick random database that has quotes
            dbs = [d for d in self.databases.values() if d.quotes]
            if not dbs:
                await self.privmsg(target, "All databases are empty.")
                return
            db = random.choice(dbs)
            quote = db.random_quote()
            await self.privmsg(target, f"[{db.name}] {quote}")

    async def cmd_list(self, target: str):
        if not self.databases:
            await self.privmsg(target, "No databases loaded.")
            return
        lines = [f"{name} ({len(db.quotes)} quotes)" for name, db in sorted(self.databases.items())]
        await self.privmsg(target, "Loaded databases: " + ", ".join(lines))

    async def cmd_add(self, target: str, args: str):
        name = args.strip().lower()
        if not name:
            await self.privmsg(target, "Syntax: ADD <database>")
            return
        # safety: only allow simple names
        if not re.match(r"^[a-z0-9_-]+$", name):
            await self.privmsg(target, "Invalid database name.")
            return
        path = QUOTES_DIR / name
        # also try with .txt
        if not path.is_file():
            path = QUOTES_DIR / f"{name}.txt"
        if not path.is_file():
            await self.privmsg(target, f"File not found for database '{name}'.")
            return
        db = QuoteDatabase(name, path)
        if not db.quotes:
            await self.privmsg(target, f"Database file for '{name}' is empty or unreadable.")
            return
        self.databases[name] = db
        await self.privmsg(target, f"Loaded database '{name}' ({len(db.quotes)} quotes).")

    async def cmd_del(self, target: str, args: str):
        name = args.strip().lower()
        if not name:
            await self.privmsg(target, "Syntax: DEL <database>")
            return
        if name not in self.databases:
            await self.privmsg(target, f"Database '{name}' is not loaded.")
            return
        del self.databases[name]
        await self.privmsg(target, f"Unloaded database '{name}'.")

    async def handle_line(self, line: str):
        line = line.rstrip("\r\n")
        if not line:
            return
        print(f"<<< {line}")

        # PING
        if line.startswith("PING"):
            await self.send("PONG" + line[4:])
            return

        # Numeric / welcome
        if " 001 " in line:
            print("[+] Connected and registered")
            if PASSWORD:
                await self.privmsg("NickServ", f"IDENTIFY {PASSWORD}")
            for chan in CHANNELS:
                await self.send(f"JOIN {chan}")
            return

        # PRIVMSG
        # :nick!user@host PRIVMSG target :message
        m = re.match(r":([^!]+)![^ ]+ PRIVMSG ([^ ]+) :(.*)", line)
        if m:
            nick, target, message = m.group(1), m.group(2), m.group(3)
            is_channel = target.startswith("#") or target.startswith("&")
            await self.handle_command(nick, target, message, is_channel)
            return

        # JOIN (optional signon quote)
        if SIGNON_QUOTE:
            m = re.match(r":([^!]+)![^ ]+ JOIN :?(#[^ ]+)", line)
            if m:
                nick, channel = m.group(1), m.group(2)
                if nick.lower() != self.nick.lower() and self.databases:
                    dbs = [d for d in self.databases.values() if d.quotes]
                    if dbs:
                        db = random.choice(dbs)
                        quote = db.random_quote()
                        if quote:
                            await self.privmsg(channel, f"Welcome {nick}! [{db.name}] {quote}")

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
    bot = QuoteServ()
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        print("\n[*] Shutting down QuoteServ")


if __name__ == "__main__":
    main()

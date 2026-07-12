# ChanBot.py by Cjefke v1.0
# I don't think this is usefull for anyone, but anyways...here it is..
# Https://IRCPlus.nl - irc.IRCPlus.nl

#!/usr/bin/env python3

import asyncio
import ssl
import json
import os
import psutil

SERVER = "127.0.0.1"
PORT = 6697

NICK = "ChanBot"
IDENT = "ChanBot"
REALNAME = "Global-Irc Watcher"

OPER_USER = ""
OPER_PASS = ""

ADMIN_NICK = "cjefke"

DB_FILE = "irc_data.json"

# ==========================================
# CHANNELS DIE CHANBOT MOET OVERSLAAN
# ==========================================
SKIP_CHANNELS = {
    "#help",
    "#irc",
    "#opers",
    "#services",
}
# ==========================================


class AsyncIRC:

    def __init__(self):
        self.db = self.load_db()
        self.reader = None
        self.writer = None

        # runtime state
        self.is_op = {}
        self.current_topics = {}
        self.joined_channels = set()

    # -------------------------
    # DB
    # -------------------------
    def load_db(self):
        if os.path.exists(DB_FILE):
            try:
                with open(DB_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except:
                pass
        return {}

    def save_db(self):
        with open(DB_FILE, "w", encoding="utf-8") as f:
            json.dump(self.db, f, indent=2)

    # -------------------------
    # SEND
    # -------------------------
    async def send(self, msg):
        try:
            self.writer.write((msg + "\r\n").encode())
            await self.writer.drain()
        except:
            pass

    # -------------------------
    # CONNECT
    # -------------------------
    async def connect(self):

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        self.reader, self.writer = await asyncio.open_connection(
            SERVER, PORT, ssl=ctx
        )

        await self.send(f"NICK {NICK}")
        await self.send(f"USER {IDENT} 0 * :{REALNAME}")

        await self.loop()

    # -------------------------
    # LOOP
    # -------------------------
    async def loop(self):

        while True:
            try:
                line = await self.reader.readline()
                if not line:
                    print("[!] Connection closed")
                    break

                msg = line.decode(errors="ignore").strip()
                parts = msg.split()

                # ---------------- PING ----------------
                if parts and parts[0] == "PING":
                    await self.send("PONG " + parts[1])
                    continue

                # ---------------- WELCOME ----------------
                if "001" in msg:
                    await self.send(f"OPER {OPER_USER} {OPER_PASS}")
                    self.list_running = True
                    await self.send("LIST")
                    asyncio.create_task(self.list_loop())

                # ---------------- LIST JOIN ----------------
                if "322" in msg:
                    try:
                        channel = parts[3].lower()

                        if channel in SKIP_CHANNELS:
                            continue

                        if channel.startswith("#"):

                            # equivalent van: if ($me isin $chan) halt
                            if channel in self.joined_channels:
                                continue

                            self.db.setdefault(channel, {"topic": ""})
                            self.save_db()

                            self.joined_channels.add(channel)
                            await self.send(f"JOIN {channel}")

                    except:
                        pass

                # ---------------- TOPIC UPDATE ----------------
                if "TOPIC" in msg:
                    try:
                        channel = parts[2].lower()

                        if channel in SKIP_CHANNELS:
                            continue

                        if channel.startswith("#"):
                            topic = msg.split(":", 2)[2]

                            # runtime cache
                            self.current_topics[channel] = topic

                            if topic.strip():
                                self.db.setdefault(channel, {"topic": ""})
                                self.db[channel]["topic"] = topic
                                self.save_db()
                    except:
                        pass

                # ---------------- PRIVMSG ----------------
                if "PRIVMSG" in msg:
                    await self.handle_privmsg(msg)

            except Exception as e:
                print(f"[ERROR] {e}")
                await asyncio.sleep(2)

    # /list loop 5mins
    async def list_loop(self):
        while True:
            await asyncio.sleep(300)   # 5 minuten
            await self.send("LIST")

    # -------------------------
    # PRIVMSG
    # -------------------------
    async def handle_privmsg(self, msg):

        prefix = msg.split("PRIVMSG")[0]
        nick = prefix.split("!")[0].replace(":", "").lower()

        target = msg.split("PRIVMSG")[1].split(":", 1)[0].strip()
        text = msg.split(":", 2)[2].strip()

        if nick != ADMIN_NICK.lower():
            return

        parts = text.split(" ", 1)
        cmd = parts[0].lower()
        arg = parts[1] if len(parts) > 1 else ""

        if cmd == ".chanbot":
            mem = psutil.Process(os.getpid()).memory_info().rss / 1024 / 1024
            await self.send(f"PRIVMSG {ADMIN_NICK} :Channels={len(self.db)} Mem={mem:.1f}MB")

        elif cmd == ".raw":
            await self.send(arg)

        elif cmd == ".join":
            await self.send(f"JOIN {arg}")

        elif cmd == ".part":
            await self.send(f"PART {arg}")

        elif cmd == ".sync":
            channel = arg.lower() if arg else target.lower()
            await self.sync(channel)

    # -------------------------
    # SYNC (SMART VERSION)
    # -------------------------
    async def sync(self, channel):

        if channel in SKIP_CHANNELS:
            await self.send(
                f"PRIVMSG {ADMIN_NICK} :{channel} is configured as skip channel"
            )
            return

        if channel not in self.db:
            await self.send(f"PRIVMSG {ADMIN_NICK} :No data for channel")
            return

        db_topic = self.db[channel].get("topic", "")
        current_topic = self.current_topics.get(channel, "")

        # normalize compare
        def norm(t):
            return " ".join(t.split()) if t else ""

        if norm(db_topic) and norm(db_topic) == norm(current_topic):
            await self.send(
                f"PRIVMSG {ADMIN_NICK} :Topics the same in {channel}, skipping sync"
            )
            return

        already_op = self.is_op.get(channel, False)

        # ---------------- OP IF NEEDED ----------------
        if not already_op:
            await self.send(f"SAMODE {channel} +o {NICK}")
            self.is_op[channel] = True

        # ---------------- SET TOPIC ----------------
        if db_topic:
            await self.send(f"TOPIC {channel} :{db_topic}")

        # update cache after setting
        self.current_topics[channel] = db_topic

        # ---------------- DEOP ONLY IF WE OPED ----------------
        if not already_op:
            await self.send(f"MODE {channel} -o {NICK}")
            self.is_op[channel] = False


async def main():
    bot = AsyncIRC()
    await bot.connect()


if __name__ == "__main__":
    asyncio.run(main())

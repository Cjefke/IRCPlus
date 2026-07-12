# Small python IRC bots.
# v1.0 by Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

#!/usr/bin/env python3

import asyncio
import random
import time

# ==========================
# CONFIG
# ==========================

SERVER = "127.0.0.1"
PORT = 6667
CHANNEL = "#Python"

CLONES = 10
IDENT = "IRCPlus"
REALNAME = "IRCPlus Socket Clone"

JOIN_RETRY = 30      # seconden tussen join pogingen

# ==========================

async def irc_clone(clone_id):
    while True:
        writer = None

        try:
            nick = f"WaRS4W[{random.randint(10000,99999)}]"

            reader, writer = await asyncio.open_connection(
                SERVER,
                PORT
            )

            writer.write(f"NICK {nick}\r\n".encode())
            writer.write(f"USER {IDENT} 0 * :{REALNAME}\r\n".encode())
            await writer.drain()

            print(f"[+] Connected: {nick}")

            joined = False
            last_join_attempt = 0

            while True:

                # Probeer periodiek te joinen zolang we niet in het kanaal zitten
                if not joined and time.time() - last_join_attempt >= JOIN_RETRY:
                    print(f"[{nick}] Attempting JOIN {CHANNEL}")
                    writer.write(f"JOIN {CHANNEL}\r\n".encode())
                    await writer.drain()
                    last_join_attempt = time.time()

                try:
                    data = await asyncio.wait_for(
                        reader.readline(),
                        timeout=5
                    )
                except asyncio.TimeoutError:
                    continue

                if not data:
                    raise Exception("Disconnected")

                line = data.decode(errors="ignore").rstrip("\r\n")

                if not line:
                    continue

                print(f"[{nick}] {line}")

                # PING/PONG
                if line.startswith("PING"):
                    writer.write(
                        f"PONG {line.split(':',1)[1]}\r\n".encode()
                    )
                    await writer.drain()

                # Na connectie direct join proberen
                if " 001 " in line:
                    joined = False
                    last_join_attempt = 0

                # JOIN succesvol
                if f" JOIN :{CHANNEL}" in line.upper():
                    if line.startswith(f":{nick}!"):
                        joined = True
                        print(f"[{nick}] Joined {CHANNEL}")

                # Ook detecteren via NAMES reply
                if " 353 " in line or " 366 " in line:
                    joined = True

                # KICK ontvangen
                if f" KICK {CHANNEL} " in line.upper():
                    if f" {nick} :" in line:
                        joined = False
                        print(f"[{nick}] Kicked from {CHANNEL}")

                # Veel voorkomende join errors
                if any(code in line for code in [
                    " 437 ",  # channel delay / nick delay
                    " 471 ",  # channel full
                    " 473 ",  # invite only
                    " 474 ",  # banned
                    " 475 ",  # key required
                    " 477 ",  # +R etc.
                    " 489 "
                ]):
                    joined = False

        except Exception as e:
            print(f"[-] Clone {clone_id} disconnected: {e}")

            try:
                if writer:
                    writer.close()
                    await writer.wait_closed()
            except:
                pass

            await asyncio.sleep(10)


async def main():
    print(f"Starting {CLONES} async clones...")

    for i in range(CLONES):
        asyncio.create_task(irc_clone(i))
        await asyncio.sleep(0.05)

    while True:
        await asyncio.sleep(3600)


if __name__ == "__main__":
    asyncio.run(main())

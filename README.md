# IRCPlus.nl

> **The IRC toolbox — scripts, bots, tools & community. Keeping IRC alive.**

[![Website](https://img.shields.io/badge/Website-IRCPlus.nl-0078D4?style=for-the-badge&logo=google-chrome&logoColor=white)](https://ircplus.nl)
[![IRC Server](https://img.shields.io/badge/IRC-irc.IRCPlus.nl-00A65A?style=for-the-badge&logo=internetexplorer&logoColor=white)](irc://irc.ircplus.nl)
[![WebChat](https://img.shields.io/badge/WebChat-%23IRCPlus-blue?style=for-the-badge)](https://ircplus.nl/webchat.php?channel=%23IRCPlus)
[![Free Bouncer](https://img.shields.io/badge/Free-ZNC%20Bouncer-orange?style=for-the-badge)](https://ircplus.nl/free-bouncer.php)
[![License](https://img.shields.io/badge/License-Open%20Source-green?style=for-the-badge)](#-license)

---

## About

**IRCPlus.nl** is an open-source collection of **mIRC scripts**, **Eggdrop TCL scripts**, **Python IRC bots**, and practical IRC utilities.  

We combine the classic IRC experience with modern automation, monitoring, and tools — all free and open source.

Whether you run a channel, maintain an Eggdrop, develop bots, or just want a better mIRC setup, IRCPlus is your one-stop toolbox.

🌐 **Main website:** [https://ircplus.nl](https://ircplus.nl)  
💬 **IRC Network:** `irc.ircplus.nl` (ports 6667 / 6697 TLS)  
🗣️ **Main channel:** `#IRCPlus`  
🖥️ **WebChat:** [Join #IRCPlus instantly](https://ircplus.nl/webchat.php?channel=%23IRCPlus)

---

## Features

| Category              | What you get                                      |
|-----------------------|---------------------------------------------------|
| 💻 **mIRC Scripts**   | Ready-to-use scripts, addons, themes & utilities  |
| 🥚 **Eggdrop TCL**    | Channel automation, monitoring & utility scripts  |
| 🐍 **Python Bots**    | Monitoring, scanners, games & API integrations    |
| 🌦 Weather & Info     | Live weather, holidays, birthdays, DNS/IP tools   |
| 🛡 Security           | Clone detection, protection & network monitoring  |
| 🎮 Games & Fun        | Entertainment commands and classic IRC games      |
| 🔧 Utilities          | Daily admin tools and helpful scripts             |
| ❤️ Open Source        | Free to use, improve and share                    |

---

## Free IRC Bouncer (ZNC)

Keep your IRC connection online 24/7 — even when your computer is off.

- Free for IRCPlus users  
- TLS protected  
- Powered by ZNC  
- One network per account  

**How to get one:**  
1. Join `#IRCPlus` (or use the [WebChat](https://ircplus.nl/webchat.php?channel=%23IRCPlus))  
2. Type: `!request your_desired_username`  
3. Wait for staff approval — credentials are sent privately  

Full details & client setup guides → [https://ircplus.nl/free-bouncer.php](https://ircplus.nl/free-bouncer.php)

---

## Latest Release — IRCPlus mIRC Client Pack

**Current version:** v1.1b  

### Highlights
- Custom Connect Manager with first-time setup wizard  
- Built-in NickServ authentication  
- Improved MP3 Player (playlist, random/continuous play, better UI)  
- Colored nicklist, nick completion, talkers  
- Custom RAW handlers & text enhancements  
- Splash screen & many stability fixes  

**Download the latest release** from the [Releases page](https://github.com/Cjefke/IRCPlus/releases).

---

## Repository Structure

```text
IRCPlus/
├── mIRC/                  # Scripts, IRCPlus client pack, addons
│   ├── Scripts/
│   ├── IRCPlus v1.x.zip
│   └── ...
├── Eggdrop/               # TCL scripts & example config
│   ├── TCL's/
│   └── eggdrop.conf
├── Python/                # IRC bots & tools
│   ├── chanbot.py
│   ├── NetworkScanner.py
│   ├── herowars.py
│   └── pybots.py
└── UnrealIRCd/            # Basic UnrealIRCd configuration

#!/usr/bin/env python3

# DEPENDENCIES:
#sudo apt update
#sudo apt install python3-pip
#playwright install chromium
#python3 -m pip install playwright
#pip install playwright irc
#sudo apt install -y \
#    libatk1.0-0 \
#    libatk-bridge2.0-0 \
#    libcups2 \
#    libdrm2 \
#    libxkbcommon0 \
#    libxcomposite1 \
#    libxdamage1 \
#    libxfixes3 \
#    libxrandr2 \
#    libgbm1 \
#    libasound2
# sudo apt install -y libnspr4 libnss3
# sudo playwright install-deps chromium 
# if not found then: python -m playwright install-deps chromium
# playwright install-deps chromium
# 
# ============================================================
# Hero Wars News & Gifts IRC Bot
# IRCPlus.nl
#
# Server : irc.global-irc.eu
# Port   : 6667
# Channel: #herowars
# Nick   : HeroWars-Serv
# ============================================================

import json
import os
import re
import threading
import time
from datetime import datetime, timedelta, timezone

from irc.bot import SingleServerIRCBot
from playwright.sync_api import sync_playwright


# ============================================================
# CONFIG
# ============================================================

IRC_SERVER = "irc.global-irc.eu"
IRC_PORT = 6667
IRC_CHANNEL = "#herowars"
IRC_NICK = "HeroWars-Serv"

FEED_URL = "https://community.hero-wars.com/feed/all/1"

CHECK_INTERVAL = 5 * 60

# Gift werkt volgens de website 24 uur.
GIFT_LIFETIME_HOURS = 24

# Reminder 6 uur voordat gift verloopt.
REMINDER_HOURS_LEFT = 6

DATA_FILE = "herowars_posts.json"


# ============================================================
# HELPERS
# ============================================================

def clean_text(text):

    if not text:
        return ""

    return re.sub(
        r"\s+",
        " ",
        text
    ).strip()


def now():

    return datetime.now(
        timezone.utc
    )


def load_database():

    if not os.path.exists(
        DATA_FILE
    ):
        return {}

    try:

        with open(
            DATA_FILE,
            "r",
            encoding="utf-8"
        ) as f:

            return json.load(f)

    except Exception as e:

        print(
            f"[DB] Error reading database: {e}"
        )

        return {}


def save_database(data):

    try:

        temp = DATA_FILE + ".tmp"

        with open(
            temp,
            "w",
            encoding="utf-8"
        ) as f:

            json.dump(
                data,
                f,
                indent=2,
                ensure_ascii=False
            )

        os.replace(
            temp,
            DATA_FILE
        )

    except Exception as e:

        print(
            f"[DB] Error saving database: {e}"
        )


def parse_datetime(value):

    try:

        return datetime.fromisoformat(
            value
        )

    except Exception:

        return None


# ============================================================
# TYPE DETECTION
# ============================================================

def detect_type(
    title,
    text
):

    combined = (
        title
        + " "
        + text
    ).lower()

    gift_words = [

        "gift",

        "free boxes",

        "free box",

        "free spheres",

        "reward",

        "claim",

        "click here",

        "code",

        "emerald",

        "energy",

        "chest",

        "bonus",

    ]

    for word in gift_words:

        if word in combined:

            return "GIFT"

    return "NEWS"


# ============================================================
# SCRAPER
# ============================================================

class HeroWarsScraper:

    def __init__(
        self,
        bot
    ):

        self.bot = bot

        self.playwright = None

        self.browser = None

    # --------------------------------------------------------
    # Start browser
    # --------------------------------------------------------

    def start_browser(self):

        print(
            "[WEB] Starting Playwright..."
        )

        self.playwright = (
            sync_playwright().start()
        )

        self.browser = (
            self.playwright.chromium.launch(

                headless=True,

                args=[

                    "--no-sandbox",

                    "--disable-dev-shm-usage",

                    "--disable-blink-features=AutomationControlled",

                ]

            )
        )

        print(
            "[WEB] Chromium started."
        )

    # --------------------------------------------------------
    # Stop browser
    # --------------------------------------------------------

    def stop_browser(self):

        try:

            if self.browser:
                self.browser.close()

        except Exception:
            pass

        try:

            if self.playwright:
                self.playwright.stop()

        except Exception:
            pass

    # --------------------------------------------------------
    # Accept cookies
    # --------------------------------------------------------

    def accept_cookies(
        self,
        page
    ):

        print(
            "[WEB] Checking cookie banner..."
        )

        cookie_buttons = [

            "Accept all cookies",

            "Accept All Cookies",

            "Accept all",

            "Accept All",

        ]

        for text in cookie_buttons:

            try:

                button = page.get_by_role(

                    "button",

                    name=re.compile(
                        rf"^{re.escape(text)}$",
                        re.IGNORECASE
                    )

                )

                if button.count() > 0:

                    print(
                        "[WEB] Accepting cookies..."
                    )

                    button.first.click(
                        timeout=3000
                    )

                    page.wait_for_timeout(
                        2000
                    )

                    print(
                        "[WEB] Cookies accepted."
                    )

                    return True

            except Exception:
                pass

        # Sommige sites gebruiken div's
        # in plaats van echte buttons.

        try:

            element = page.get_by_text(

                re.compile(
                    r"^Accept all cookies$",
                    re.IGNORECASE
                )

            )

            if element.count() > 0:

                print(
                    "[WEB] Clicking cookie text..."
                )

                element.first.click(
                    timeout=3000
                )

                page.wait_for_timeout(
                    2000
                )

                return True

        except Exception:
            pass

        print(
            "[WEB] Cookie banner not found."
        )

        return False

    # --------------------------------------------------------
    # Scrape feed
    # --------------------------------------------------------

    def scrape(self):

        context = None
        page = None

        try:

            context = (
                self.browser.new_context(

                    viewport={
                        "width": 1920,
                        "height": 1080
                    },

                    locale="en-US",

                    user_agent=(
                        "Mozilla/5.0 "
                        "(X11; Linux x86_64) "
                        "AppleWebKit/537.36 "
                        "(KHTML, like Gecko) "
                        "Chrome/131.0.0.0 "
                        "Safari/537.36"
                    )

                )
            )

            page = context.new_page()

            print()
            print(
                "================================================"
            )

            print(
                f"[WEB] Opening {FEED_URL}"
            )

            page.goto(

                FEED_URL,

                wait_until="domcontentloaded",

                timeout=60000

            )

            page.wait_for_timeout(
                5000
            )

            print(
                f"[WEB] Current URL: {page.url}"
            )

            # ------------------------------------------------
            # Cookies
            # ------------------------------------------------

            self.accept_cookies(
                page
            )

            page.wait_for_timeout(
                3000
            )

            # ------------------------------------------------
            # Get body text
            # ------------------------------------------------

            body_text = clean_text(
                page.locator(
                    "body"
                ).inner_text()
            )

            print(
                f"[WEB] Page text: "
                f"{len(body_text)} characters"
            )

            # ------------------------------------------------
            # Detect feed
            # ------------------------------------------------

            if "Free Boxes" not in body_text:

                print(
                    "[WEB] WARNING: Feed content "
                    "was not detected."
                )

                print(
                    body_text[:1000]
                )

                return []

            print(
                "[WEB] Hero Wars feed detected."
            )

            # ------------------------------------------------
            # Find post containers
            # ------------------------------------------------
            #
            # We look for elements containing
            # recognizable post dates/titles.
            #
            # The exact CSS layout can change, so
            # we use several strategies.
            # ------------------------------------------------

            posts = []

            # ------------------------------------------------
            # Strategy A: links with article-like URLs
            # ------------------------------------------------

            links = page.locator(
                "a"
            )

            link_count = links.count()

            print(
                f"[WEB] Found {link_count} links."
            )

            candidates = []

            ignored = [

                "support",

                "cookie",

                "privacy",

                "terms",

                "settings",

                "login",

                "register",

            ]

            for i in range(
                link_count
            ):

                try:

                    link = links.nth(i)

                    href = (
                        link.get_attribute(
                            "href"
                        )
                    )

                    text = clean_text(
                        link.inner_text()
                    )

                    if not href:
                        continue

                    if href.startswith("/"):

                        href = (
                            "https://community.hero-wars.com"
                            + href
                        )

                    if not href.startswith(
                        "https://community.hero-wars.com"
                    ):
                        continue

                    lower_href = (
                        href.lower()
                    )

                    lower_text = (
                        text.lower()
                    )

                    if any(
                        word in lower_href
                        for word in ignored
                    ):
                        continue

                    if any(
                        word == lower_text
                        for word in ignored
                    ):
                        continue

                    # We don't reject /feed/ here.
                    #
                    # This was one of the problems
                    # with the previous scraper.

                    if len(text) < 4:
                        continue

                    candidates.append({

                        "href": href,

                        "text": text,

                        "element": link

                    })

                except Exception:
                    continue

            print(
                f"[WEB] Link candidates: "
                f"{len(candidates)}"
            )

            # ------------------------------------------------
            # Find actual post blocks
            # ------------------------------------------------

            seen = set()

            for candidate in candidates:

                try:

                    link = candidate[
                        "element"
                    ]

                    href = candidate[
                        "href"
                    ]

                    link_text = candidate[
                        "text"
                    ]

                    # ------------------------------------------------
                    # Get a reasonably large parent block.
                    # ------------------------------------------------

                    parent = link

                    best_text = link_text

                    for level in range(1, 6):

                        try:

                            parent = parent.locator(
                                "xpath=.."
                            )

                            parent_text = clean_text(
                                parent.inner_text()
                            )

                            # We want a block containing
                            # date + title + description.

                            if (
                                len(parent_text)
                                > len(best_text)
                                and len(parent_text)
                                < 2000
                            ):

                                best_text = (
                                    parent_text
                                )

                        except Exception:

                            break

                    # ------------------------------------------------
                    # Is this actually a post?
                    # ------------------------------------------------

                    has_date = bool(
                        re.search(
                            r"\b\d{1,2}\s+"
                            r"(January|February|March|April|May|June|"
                            r"July|August|September|October|November|December)"
                            r"\s+\d{4}\b",
                            best_text,
                            re.IGNORECASE
                        )
                    )

                    has_gift = (
                        "click here" in
                        best_text.lower()
                    )

                    has_greetings = (
                        "greetings guardians" in
                        best_text.lower()
                    )

                    # Title itself is usually short.
                    # Reject obvious navigation.

                    if not (
                        has_date
                        or has_gift
                        or has_greetings
                    ):

                        continue

                    # ------------------------------------------------
                    # Extract date
                    # ------------------------------------------------

                    date_match = re.search(

                        r"\b\d{1,2}\s+"
                        r"(January|February|March|April|May|June|"
                        r"July|August|September|October|November|December)"
                        r"\s+\d{4}\b",

                        best_text,

                        re.IGNORECASE

                    )

                    post_date = (
                        date_match.group(0)
                        if date_match
                        else ""
                    )

                    # ------------------------------------------------
                    # Find gift link inside block
                    # ------------------------------------------------

                    gift_url = None

                    inner_links = parent.locator(
                        "a"
                    )

                    inner_count = (
                        inner_links.count()
                    )

                    for x in range(
                        inner_count
                    ):

                        try:

                            inner = (
                                inner_links.nth(x)
                            )

                            inner_href = (
                                inner.get_attribute(
                                    "href"
                                )
                            )

                            inner_text = clean_text(
                                inner.inner_text()
                            )

                            if not inner_href:
                                continue

                            if inner_href.startswith(
                                "/"
                            ):

                                inner_href = (
                                    "https://community.hero-wars.com"
                                    + inner_href
                                )

                            if (
                                "click here"
                                in inner_text.lower()
                            ):

                                gift_url = (
                                    inner_href
                                )

                                break

                        except Exception:
                            continue

                    # ------------------------------------------------
                    # Determine title
                    # ------------------------------------------------

                    title = link_text

                    # Avoid generic "Click here"
                    if title.lower() == "click here":

                        # Search headings inside parent
                        for selector in [
                            "h1",
                            "h2",
                            "h3",
                            "h4"
                        ]:

                            try:

                                headings = (
                                    parent.locator(
                                        selector
                                    )
                                )

                                heading_count = (
                                    headings.count()
                                )

                                for h in range(
                                    heading_count
                                ):

                                    heading_text = (
                                        clean_text(
                                            headings
                                            .nth(h)
                                            .inner_text()
                                        )
                                    )

                                    if (
                                        len(heading_text)
                                        >= 5
                                    ):

                                        title = (
                                            heading_text
                                        )

                                        break

                                if (
                                    title.lower()
                                    != "click here"
                                ):

                                    break

                            except Exception:
                                continue

                    # ------------------------------------------------
                    # Gift posts:
                    # Use the gift URL as unique URL.
                    # News posts:
                    # use the article URL.
                    # -----------------------------------------------

                    post_type = detect_type(
                        title,
                        best_text
                    )

                    unique_url = (
                        gift_url
                        if (
                            post_type == "GIFT"
                            and gift_url
                        )
                        else href
                    )

                    if unique_url in seen:

                        continue

                    seen.add(
                        unique_url
                    )

                    posts.append({

                        "url": unique_url,

                        "article_url": href,

                        "gift_url": gift_url,

                        "title": title,

                        "date": post_date,

                        "text": best_text,

                        "type": post_type

                    })

                except Exception:
                    continue

            # ------------------------------------------------
            # Remove bad candidates
            # ------------------------------------------------

            filtered = []

            for post in posts:

                title = clean_text(
                    post["title"]
                )

                lower = title.lower()

                if lower in [

                    "support",

                    "here",

                    "login",

                    "register",

                    "cookie policy",

                    "privacy policy",

                    "terms of services",

                ]:

                    continue

                if len(title) < 5:

                    continue

                filtered.append(
                    post
                )

            posts = filtered

            # ------------------------------------------------
            # Output
            # ------------------------------------------------

            print(
                f"[WEB] REAL POSTS FOUND: "
                f"{len(posts)}"
            )

            for post in posts:

                print(
                    f"[WEB POST] "
                    f"{post['type']} | "
                    f"{post['date']} | "
                    f"{post['title']}"
                )

                print(
                    f"           Article: "
                    f"{post['article_url']}"
                )

                if post.get(
                    "gift_url"
                ):

                    print(
                        f"           Gift: "
                        f"{post['gift_url']}"
                    )

            print(
                "================================================"
            )

            return posts

        except Exception as e:

            print(
                f"[WEB ERROR] "
                f"{type(e).__name__}: {e}"
            )

            return []

        finally:

            try:

                if context:
                    context.close()

            except Exception:
                pass

    # --------------------------------------------------------
    # Monitoring loop
    # --------------------------------------------------------

    def run(self):

        try:

            self.start_browser()

            while True:

                try:

                    posts = self.scrape()

                    self.bot.process_posts(
                        posts
                    )

                except Exception as e:

                    print(
                        f"[MONITOR ERROR] {e}"
                    )

                print(
                    f"[WEB] Next check in "
                    f"{CHECK_INTERVAL // 60} minutes."
                )

                time.sleep(
                    CHECK_INTERVAL
                )

        except Exception as e:

            print(
                f"[WEB FATAL] {e}"
            )

        finally:

            self.stop_browser()


# ============================================================
# IRC BOT
# ============================================================

class HeroWarsBot(
    SingleServerIRCBot
):

    def __init__(self):

        super().__init__(

            [
                (
                    IRC_SERVER,
                    IRC_PORT
                )
            ],

            IRC_NICK,

            IRC_NICK

        )

        self.data = (
            load_database()
        )

        self.scraper_thread = None

    # --------------------------------------------------------
    # Connected
    # --------------------------------------------------------

    def on_welcome(
        self,
        connection,
        event
    ):

        print(
            "[IRC] Connected."
        )

        print(
            f"[IRC] Joining "
            f"{IRC_CHANNEL}"
        )

        connection.join(
            IRC_CHANNEL
        )

        self.start_scraper()

    # --------------------------------------------------------
    # Start scraper
    # --------------------------------------------------------

    def start_scraper(self):

        if (
            self.scraper_thread
            and self.scraper_thread.is_alive()
        ):

            return

        print(
            "[WEB] Starting scraper thread..."
        )

        scraper = (
            HeroWarsScraper(
                self
            )
        )

        self.scraper_thread = (
            threading.Thread(

                target=scraper.run,

                daemon=True

            )
        )

        self.scraper_thread.start()

    # --------------------------------------------------------
    # IRC send
    # --------------------------------------------------------

    def say(
        self,
        message
    ):

        try:

            self.connection.privmsg(

                IRC_CHANNEL,

                message

            )

            print(
                f"[IRC] {message}"
            )

        except Exception as e:

            print(
                f"[IRC ERROR] {e}"
            )

    # --------------------------------------------------------
    # Process posts
    # --------------------------------------------------------

    def process_posts(
        self,
        posts
    ):

        if not posts:

            print(
                "[WEB] No real posts found."
            )

            return

        current = now()

        changed = False

        for post in posts:

            url = post.get(
                "url"
            )

            article_url = post.get(
                "article_url"
            )

            gift_url = post.get(
                "gift_url"
            )

            title = clean_text(
                post.get(
                    "title",
                    ""
                )
            )

            post_type = post.get(
                "type",
                "NEWS"
            )

            post_date = post.get(
                "date",
                ""
            )

            if not url or not title:
                continue

            # ------------------------------------------------
            # New item
            # ------------------------------------------------

            if url not in self.data:

                self.data[url] = {

                    "url": url,

                    "article_url":
                        article_url,

                    "gift_url":
                        gift_url,

                    "title": title,

                    "type": post_type,

                    "date": post_date,

                    "created":
                        current.isoformat(),

                    "reminder_sent":
                        False

                }

                changed = True

                # ------------------------------------------------
                # IRC
                # ------------------------------------------------

                if post_type == "GIFT":

                    target = (
                        gift_url
                        or article_url
                        or url
                    )

                    self.say(
                        "🎁 NEW HERO WARS GIFT: "
                        f"{title} -> {target}"
                    )

                else:

                    self.say(
                        "📰 NEW HERO WARS NEWS: "
                        f"{title} -> {article_url}"
                    )

                continue

            # ------------------------------------------------
            # Existing gift
            # ------------------------------------------------

            saved = self.data[url]

            if (
                saved.get(
                    "type"
                ) != "GIFT"
            ):

                continue

            if saved.get(
                "reminder_sent",
                False
            ):

                continue

            created = parse_datetime(
                saved.get(
                    "created"
                )
            )

            if not created:
                continue

            age = (
                current
                - created
            )

            expiry = (
                created
                + timedelta(
                    hours=GIFT_LIFETIME_HOURS
                )
            )

            remaining = (
                expiry
                - current
            )

            hours_left = int(
                remaining.total_seconds()
                // 3600
            )

            # ------------------------------------------------
            # Six hours left
            # ------------------------------------------------

            if (
                hours_left
                <= REMINDER_HOURS_LEFT
                and hours_left > 0
            ):

                target = (
                    saved.get(
                        "gift_url"
                    )
                    or saved.get(
                        "article_url"
                    )
                    or url
                )

                self.say(
                    "🎁 Just "
                    f"{hours_left} hours left "
                    "for this gift: "
                    f"{target}"
                )

                saved[
                    "reminder_sent"
                ] = True

                changed = True

        if changed:

            save_database(
                self.data
            )

    # --------------------------------------------------------
    # Disconnect
    # --------------------------------------------------------

    def on_disconnect(
        self,
        connection,
        event
    ):

        print(
            "[IRC] Disconnected."
        )


# ============================================================
# MAIN
# ============================================================

def main():

    print()
    print(
        "=============================================="
    )

    print(
        " Hero Wars News & Gifts IRC Bot"
    )

    print(
        " IRCPlus.nl"
    )

    print(
        "=============================================="
    )

    print(
        f"Server : "
        f"{IRC_SERVER}:{IRC_PORT}"
    )

    print(
        f"Channel: "
        f"{IRC_CHANNEL}"
    )

    print(
        f"Nick   : "
        f"{IRC_NICK}"
    )

    print(
        f"Website: "
        f"{FEED_URL}"
    )

    print(
        "=============================================="
    )

    print()

    bot = HeroWarsBot()

    try:

        bot.start()

    except KeyboardInterrupt:

        print(
            "[EXIT] Bot stopped."
        )


# ============================================================
# START
# ============================================================

if __name__ == "__main__":

    main()

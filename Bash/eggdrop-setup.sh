#!/usr/bin/env bash
# IRCPlus.nl - Eggdrop 1.10.2 Installer (English) - Fixed version
set -Eeuo pipefail
umask 077

VERSION="1.10.2"
URL="https://ftp.eggheads.org/pub/eggdrop/source/1.10/eggdrop-${VERSION}.tar.gz"

trap 'echo; echo "ERROR: Installation failed at line $LINENO."; exit 1' ERR

cat <<'BANNER'
  ___ ____   ____ ____  _                 _
 |_ _|  _ \ / ___|  _ \| |__  _   _ ___  | |
  | || |_) | |   | |_) | '_ \| | | / __| | |
  | ||  _ <| |___|  __/| | | | |_| \__ \ |_|
 |___|_| \_\\____|_|   |_| |_|\__,_|___/ (_)
BANNER
echo "              Eggdrop ${VERSION} Installer (Fixed)"
echo

if [[ $EUID -eq 0 ]]; then
    echo "Run as a normal user with sudo access, not as root."
    exit 1
fi
command -v sudo >/dev/null || { echo "sudo is required."; exit 1; }

ask() {
    local prompt="$1" default="${2:-}" answer
    read -r -p "$prompt [$default]: " answer
    printf '%s' "${answer:-$default}"
}

ask_secret() {
    local answer
    while :; do
        read -r -s -p "$1: " answer
        echo
        [[ -n "$answer" ]] && { printf '%s' "$answer"; return; }
        echo "This field is required."
    done
}

valid_nick() {
    [[ "$1" =~ ^[A-Za-z][A-Za-z0-9_-]{0,29}$ ]]
}

tcl_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    value="${value//\[/\\\[}"
    value="${value//\]/\\\]}"
    printf '%s' "$value"
}

echo "=== Configuration ==="
INSTALL_DIR="$(ask 'Installation directory' "$HOME/eggdrop")"
[[ "$INSTALL_DIR" = /* && "$INSTALL_DIR" != "/" ]] || {
    echo "Use an absolute path other than /."; exit 1;
}

BOT_NICK="$(ask 'Bot nickname' 'LamestBot')"
valid_nick "$BOT_NICK" || { echo "Invalid nickname."; exit 1; }

ALT_NICK="$(ask 'Alternative nickname' "${BOT_NICK}_")"
valid_nick "$ALT_NICK" || { echo "Invalid alternative nickname."; exit 1; }

OWNER_NICK="$(ask 'Your IRC nickname (owner)' 'YourNick')"
valid_nick "$OWNER_NICK" || { echo "Invalid owner nickname."; exit 1; }

IRC_SERVER="$(ask 'IRC server hostname' 'irc.ircplus.nl')"
[[ "$IRC_SERVER" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Invalid hostname."; exit 1; }

TLS="$(ask 'Use TLS? yes/no' 'yes')"
case "${TLS,,}" in
    yes|y) TLS=yes; DEFAULT_PORT=6697 ;;
    no|n)  TLS=no;  DEFAULT_PORT=6667 ;;
    *) echo "Answer yes or no."; exit 1 ;;
esac

IRC_PORT="$(ask 'IRC server port' "$DEFAULT_PORT")"
[[ "$IRC_PORT" =~ ^[0-9]+$ ]] && (( IRC_PORT >= 1 && IRC_PORT <= 65535 )) || {
    echo "Invalid port."; exit 1;
}

CHANNEL="$(ask 'Channel to join' '#IRCPlus')"
[[ "$CHANNEL" =~ ^#[^[:space:],]+$ ]] || { echo "Invalid channel."; exit 1; }

REALNAME="$(ask 'Bot real name' 'IRCPlus Eggdrop Bot')"
IDENT="$(ask 'IRC username/ident' 'eggdrop')"
[[ "$IDENT" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid ident."; exit 1; }

NETWORK="$(ask 'IRC network name' 'IRCPlus')"
ADMIN_NAME="$(ask 'Administrator name' "$OWNER_NICK")"
ADMIN_EMAIL="$(ask 'Administrator email' 'admin@example.org')"

DCC_PORT="$(ask 'DCC listening port' '3333')"
[[ "$DCC_PORT" =~ ^[0-9]+$ ]] && (( DCC_PORT >= 1 && DCC_PORT <= 65535 )) || {
    echo "Invalid DCC port."; exit 1;
}

HELLO_SECRET="$(ask_secret 'Secret for /msg BotNick hello SECRET')"

SERVICE_NAME="eggdrop-${BOT_NICK,,}"
CONFIG="$INSTALL_DIR/$BOT_NICK.conf"
USERFILE="$INSTALL_DIR/$BOT_NICK.user"

if [[ -e "$CONFIG" ]]; then
    echo "Config already exists: $CONFIG"
    echo "Refusing to overwrite an existing configuration."
    exit 1
fi

echo
echo "=== Installing dependencies ==="
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential gcc g++ make autoconf automake pkg-config \
    tcl tcl-dev libssl-dev zlib1g-dev libtool curl ca-certificates \
    tar gzip

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo
echo "=== Downloading Eggdrop ${VERSION} ==="
curl -fL --retry 3 "$URL" -o "$TMP/eggdrop.tar.gz"
mkdir "$TMP/src"
tar -xzf "$TMP/eggdrop.tar.gz" -C "$TMP/src"
SRC="$(find "$TMP/src" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[[ -n "$SRC" ]] || { echo "Source directory not found."; exit 1; }

echo
echo "=== Compiling Eggdrop ==="
cd "$SRC"
./configure --prefix="$INSTALL_DIR"
make config
make -j"$(nproc)"
make install

BIN="$INSTALL_DIR/eggdrop"
[[ -x "$BIN" ]] || { echo "Eggdrop binary not found: $BIN"; exit 1; }

mkdir -p "$INSTALL_DIR/logs" "$INSTALL_DIR/tmp" \
    "$INSTALL_DIR/scripts" "$INSTALL_DIR/modules"

# Tcl values are escaped before being inserted into the configuration.
Q_NICK="$(tcl_escape "$BOT_NICK")"
Q_ALT="$(tcl_escape "$ALT_NICK")"
Q_OWNER="$(tcl_escape "$OWNER_NICK")"
Q_SERVER="$(tcl_escape "$IRC_SERVER")"
Q_CHANNEL="$(tcl_escape "$CHANNEL")"
Q_REALNAME="$(tcl_escape "$REALNAME")"
Q_IDENT="$(tcl_escape "$IDENT")"
Q_NETWORK="$(tcl_escape "$NETWORK")"
Q_ADMIN="$(tcl_escape "$ADMIN_NAME <$ADMIN_EMAIL>")"
Q_SECRET="$(tcl_escape "$HELLO_SECRET")"

if [[ "$TLS" == yes ]]; then
    SERVER_SPEC="${IRC_SERVER}:+${IRC_PORT}"
else
    SERVER_SPEC="${IRC_SERVER}:${IRC_PORT}"
fi
Q_SERVER_SPEC="$(tcl_escape "$SERVER_SPEC")"

echo
echo "=== Writing configuration ==="
cat > "$CONFIG" <<EOF
#! $BIN
# IRCPlus.nl Eggdrop ${VERSION}
# Review this file before changing advanced settings.

set username "$Q_IDENT"
set realname "$Q_REALNAME"
set admin "$Q_ADMIN"
set network "$Q_NETWORK"
set owner "$Q_OWNER"

# IRC nick (required) + botnet nick
set nick "$Q_NICK"
set altnick "$Q_ALT"
set botnet-nick "$Q_NICK"

set userfile "$BOT_NICK.user"
set pidfile "$BOT_NICK.pid"
set chanfile "$BOT_NICK.chan"

# logfile is a command, not a Tcl variable
logfile mco * "logs/$BOT_NICK.log"
set max-logs 5
set keep-all-logs 0
set console "mkcobxs"

set mod-path "$INSTALL_DIR/modules/"
set help-path "$INSTALL_DIR/help/"
set temp-path "$INSTALL_DIR/tmp/"
set userfile-perm 0600
set max-socks 100
set dcc-block 0
set server-timeout 60
set connect-timeout 30
set default-port $DCC_PORT
set stealth-telnets 1
set die-on-sigterm 1
set hourly-updates 00
set learn-users 0
set must-be-owner 1
set default-flags "-"

# Encryption module is required for userfile / passwords
loadmodule blowfish

# dns module is not needed when Eggdrop is compiled with threaded DNS
# loadmodule dns
loadmodule channels
loadmodule server
loadmodule ctcp
loadmodule irc
loadmodule notes
loadmodule console
loadmodule uptime

set servers {
    "$Q_SERVER_SPEC"
}

channel add "$Q_CHANNEL" {
    chanmode "+nt"
    idle-kick 0
    stopnethack-mode 0
    revenge-mode 0
    flood-chan 8:60
    flood-join 5:60
    flood-kick 3:10
    flood-deop 3:10
    flood-nick 5:60
    flood-ctcp 3:60
    +dynamicbans
    +userbans
    +protectops
    +dontkickops
    +cycle
    -autoop
    -autovoice
    -greet
}

# Initial owner setup:
# /msg $Q_NICK hello YOUR_SECRET
set setup-hello-secret "$Q_SECRET"
bind msg - "hello *" setup_hello_owner
proc setup_hello_owner {nick uhost hand text} {
    global setup-hello-secret owner
    set supplied [lindex [split \$text] 0]
    if {\$supplied ne \$setup-hello-secret} {
        puthelp "NOTICE \$nick :Incorrect setup password."
        return 0
    }
    if {![string equal -nocase \$nick \$owner]} {
        puthelp "NOTICE \$nick :Only the configured owner nickname can use this command."
        return 0
    }
    if {[validuser \$nick]} {
        puthelp "NOTICE \$nick :A user record already exists."
        return 0
    }
    adduser \$nick \$uhost
    chattr \$nick +n
    puthelp "NOTICE \$nick :Owner account created. Finish setting a private Eggdrop password, then remove the temporary hello setup block from the config."
    return 1
}
EOF

chmod 600 "$CONFIG"

# First run uses -m (create userfile). Later starts use -n (foreground for systemd).
WRAPPER="$INSTALL_DIR/start-eggdrop.sh"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
set -e
cd "$INSTALL_DIR"
if [[ ! -f "$USERFILE" ]]; then
    exec "$BIN" -m "$CONFIG"
else
    exec "$BIN" -n "$CONFIG"
fi
EOF
chmod 700 "$WRAPPER"

echo
echo "=== Creating systemd service ==="
sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=IRCPlus.nl Eggdrop bot ($BOT_NICK)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(id -un)
Group=$(id -gn)
WorkingDirectory=$INSTALL_DIR
ExecStart=$WRAPPER
Restart=on-failure
RestartSec=10
UMask=0077
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME" || sudo systemctl start "$SERVICE_NAME"

echo
echo "========================================"
echo " IRCPlus.nl - Installation completed"
echo "========================================"
echo "Config:  $CONFIG"
echo "Service: $SERVICE_NAME"
echo
echo "Check status:"
echo "  sudo systemctl status $SERVICE_NAME"
echo "View logs:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo "Restart:"
echo "  sudo systemctl restart $SERVICE_NAME"
echo
echo "When the bot is online, send:"
echo "  /msg $BOT_NICK hello YOUR_SECRET"
echo
echo "IMPORTANT: After you are owner, remove the temporary hello setup block"
echo "from the config for security. The config contains the setup secret."
echo

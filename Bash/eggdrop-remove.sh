#!/usr/bin/env bash
# Eggdrop Complete Removal Script (safe PID handling)
set -euo pipefail

echo
echo "=== Eggdrop Complete Removal ==="
echo

read -rp "Systemd service name (example: eggdrop-lamestbot): " SERVICE_NAME
read -rp "Installation directory (example: /home/eggdrop/lamestb0t): " INSTALL_DIR

echo
echo "You are about to permanently delete:"
echo "  Service   : $SERVICE_NAME"
echo "  Directory : $INSTALL_DIR"
echo
read -rp "Type 'yes' to confirm: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo
echo "→ Stopping and disabling service..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true

echo "→ Removing systemd unit..."
sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
sudo systemctl daemon-reload
sudo systemctl reset-failed 2>/dev/null || true

# --- Safe PID handling using Eggdrop's own pidfile ---
echo "→ Looking for Eggdrop pidfile..."
PIDFILE=""
if [[ -d "$INSTALL_DIR" ]]; then
    # Try common locations
    for f in "$INSTALL_DIR"/*.pid; do
        if [[ -f "$f" ]]; then
            PIDFILE="$f"
            break
        fi
    done
fi

if [[ -n "$PIDFILE" && -f "$PIDFILE" ]]; then
    PID=$(cat "$PIDFILE" 2>/dev/null || true)
    if [[ -n "$PID" && "$PID" =~ ^[0-9]+$ ]]; then
        if kill -0 "$PID" 2>/dev/null; then
            echo "→ Found running Eggdrop (PID $PID) – sending TERM..."
            kill "$PID" 2>/dev/null || true
            sleep 1
            # Force kill only if still alive
            if kill -0 "$PID" 2>/dev/null; then
                echo "→ Process still running, sending KILL..."
                kill -9 "$PID" 2>/dev/null || true
            fi
            echo "→ Eggdrop process $PID terminated."
        else
            echo "→ PID $PID is not running (stale pidfile)."
        fi
    else
        echo "→ Pidfile exists but contains no valid PID."
    fi
else
    echo "→ No pidfile found (bot was probably already stopped)."
fi

echo "→ Removing installation directory..."
rm -rf "$INSTALL_DIR"

echo
echo "=== Removal completed ==="
echo "Service, process (if running) and directory have been deleted."
echo

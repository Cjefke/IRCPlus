# Status.tcl for Eggdrop v1.10+ v1.0 by Cjefke 2026
# !status or wait for 12 hours and the bot will spam the status in the channel you config
# Bot will output stats also when connected to server immediatly to the channel.
# Https://IRCPlus.nl - irc.IRCPlus.nl

# ===== CONFIG =====
set status_interval 43200   ;# 12 hours
set status_channel "#BlackBox"   ;# Give channel to do status every 12 hours interval.

# IRC color codes
set c_reset "\003"
set c_bold "\002"
set c_green "\00303"
set c_blue "\00312"
set c_yellow "\00308"
set c_red "\00304"

# ===== COMMAND =====
bind pub - "!status" pub_status

set last_status 0

proc pub_status {nick host hand chan text} {
    global last_status
    set now [clock seconds]

    if {$now - $last_status < 10} {
        return
    }

    set last_status $now
    send_status $chan
}

# ===== AUTO LOOP =====
proc auto_status {} {
    global status_interval status_channel
    send_status $status_channel
    utimer $status_interval auto_status
}

# ===== STATUS FUNCTION =====
proc send_status {chan} {
    global c_reset c_bold c_green c_blue c_yellow c_red

    if {[catch {

        set out [exec sh -c {
            OS=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
            HOST=$(hostname)
            KERNEL=$(uname -r)
            CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')

            CORES=$(nproc)
            LOAD_RAW=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
            LOAD1=$(awk '{print $1}' /proc/loadavg)
            LOAD_NORM=$(awk -v l=$LOAD1 -v c=$CORES 'BEGIN {printf "%.2f", l/c}')

            RAM=$(free -m | awk '/Mem:/ {print $3"/"$2"MB"}')
            DISK=$(df -h --output=used,size,pcent / 2>/dev/null | tail -1 | awk '{print $1"/"$2" ("$3")"}')
            UP=$(uptime -p)

            PROCS=$(ps -e --no-headers | wc -l)

            TOPPROC=$(ps -eo comm,%cpu --sort=-%cpu | awk 'NR==2 {printf "%s (%.1f%%)", $1, $2}')

            echo "$OS|$HOST|$KERNEL|$CPU|$RAM|$LOAD_RAW|$LOAD_NORM|$DISK|$UP|$PROCS|$TOPPROC"
        }]

        # ===== PARSE =====
        set parts [split $out "|"]

        if {[llength $parts] < 11} {
            putserv "PRIVMSG $chan :Error: Failed to parse system stats"
            return
        }

        set OS        [lindex $parts 0]
        set HOST      [lindex $parts 1]
        set KERNEL    [lindex $parts 2]
        set CPU       [lindex $parts 3]
        set RAM       [lindex $parts 4]
        set LOAD      [lindex $parts 5]
        set LOADNORM  [lindex $parts 6]
        set DISK      [lindex $parts 7]
        set UP        [lindex $parts 8]
        set PROCS     [lindex $parts 9]
        set TOPPROC   [lindex $parts 10]

        if {$DISK eq ""} { set DISK "N/A" }
        if {$TOPPROC eq ""} { set TOPPROC "N/A" }

        # trim long CPU names
        set CPU [string range $CPU 0 60]

        # ===== OUTPUT =====
        putserv "PRIVMSG $chan :${c_bold}${c_blue}System${c_reset} → ${c_green}$OS${c_reset} | Host: ${c_yellow}$HOST${c_reset}"

        putserv "PRIVMSG $chan :CPU: ${c_green}$CPU${c_reset} | Load: ${c_red}$LOAD${c_reset} (${c_red}$LOADNORM/core${c_reset})"

        putserv "PRIVMSG $chan :RAM: ${c_blue}$RAM${c_reset} | Disk: ${c_yellow}$DISK${c_reset} | Procs: ${c_green}$PROCS${c_reset}"

        putserv "PRIVMSG $chan :Top: ${c_red}$TOPPROC${c_reset} | Uptime: ${c_green}$UP${c_reset}"

    } err]} {
        putserv "PRIVMSG $chan :Error: $err"
    }
}

# ===== START AUTO TIMER =====
if {![info exists ::auto_status_running]} {
    set ::auto_status_running 1
    utimer 10 auto_status
}

# blackbox Commands Script
# Commands:
# .blackbox ports
# .blackbox sysinfo
# Https://IRCPlus.nl - irc.IRCPlus.nl - 2026® Cjefke

bind pub -|- ".blackbox" blackbox_command

proc blackbox_command {nick host hand chan text} {

    # Alleen operators of owners
    if {![matchattr $hand o|n $chan]} {
        putserv "PRIVMSG $chan :$nick: Geen toegang."
        return
    }

    set cmd [string trim $text]

    # =========================
    # PORTS
    # =========================
    if {$cmd eq "ports"} {

        set lsofbin "/usr/bin/lsof"

        if {![file executable $lsofbin]} {
            putserv "PRIVMSG $chan :lsof niet gevonden op $lsofbin"
            return
        }

        if {[catch {exec $lsofbin -i -P} result]} {
            putserv "PRIVMSG $chan :Fout: $result"
            return
        }

        set lines [split $result "\n"]

        set maxlines 15
        set count 0

foreach line $lines {

    # ANSI kleuren verwijderen
    regsub -all {\x1b\[[0-9;]*m} $line "" line

    # Trim spaces
    set cleanline [string trim $line]

    # Lege regels overslaan
    if {$cleanline eq ""} {
        continue
    }

    # IRC limiet
    if {[string length $cleanline] > 350} {
        set cleanline "[string range $cleanline 0 349]..."
    }

    putserv "PRIVMSG $chan :$cleanline"

    incr count

    if {$count >= $maxlines} {
        putserv "PRIVMSG $chan :Sysinfo output ingekort op $maxlines regels."
        break
    }
}

        return
    }

    # =========================
    # SYSINFO
    # =========================
    if {$cmd eq "sysinfo"} {

        # Pas aan indien nodig:
        set fastfetchbin "/usr/bin/fastfetch"

        if {![file executable $fastfetchbin]} {
            putserv "PRIVMSG $chan :fastfetch niet gevonden op $fastfetchbin"
            return
        }

        # --pipe voorkomt ANSI kleuren/problemen
        if {[catch {exec $fastfetchbin --pipe --logo none --separator " : "} result]} {
            putserv "PRIVMSG $chan :Fout: $result"
            return
        }

        set lines [split $result "\n"]

        set maxlines 25
        set count 0

foreach line $lines {

    # 1. ANSI escape codes verwijderen
    regsub -all {\x1b\[[0-9;]*m} $line "" line

    # 2. Alles wat whitespace is normaliseren
    set line [string map {"\u00A0" " "} $line]

    # 3. Trim
    set line [string trim $line]

    # 4. Echt lege regels skippen (ook na cleanup)
    if {$line eq ""} {
        continue
    }

    # IRC limiet
    if {[string length $line] > 350} {
        set line "[string range $line 0 349]..."
    }

    putserv "PRIVMSG $chan :$line"

    incr count

    if {$count >= $maxlines} {
        putserv "PRIVMSG $chan :Sysinfo output ingekort op $maxlines regels."
        break
    }
}

        return
    }

    # Help
    putserv "PRIVMSG $chan :Gebruik: .blackbox ports | .blackbox sysinfo"
}

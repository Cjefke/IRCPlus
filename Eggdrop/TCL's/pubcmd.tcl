# Channel commands v1.2 by Cjefke
# Https://IRCPlus.nl - irc.IRCPlus.nl

putlog "Channel Commands v0.5 CLEAN by Cjefke Loaded!"

bind pub - .mass mass_control


# =========================
# MASS CONTROL (HUB)
# =========================
proc mass_control {nick host hand chan text} {

    if {![matchattr $hand n]} {
        return 0
    }

    set cmd [string tolower [lindex $text 0]]

    switch -- $cmd {

        rehash {
            puthelp "PRIVMSG $chan :Rehashing all bots..."
            putallbots "rehash"
            rehash
        }

        restart {
            puthelp "PRIVMSG $chan :Restarting all bots..."
            putallbots "restart"
            utimer 2 restart
        }

        status {
            puthelp "PRIVMSG $chan :Botnet: [bots]"
        }

        join {
            set ch [lindex $text 1]

            if {$ch eq ""} {
                puthelp "PRIVMSG $chan :Usage: .mass join <#channel>"
                return 0
            }

            puthelp "PRIVMSG $chan :Joining $ch on all bots..."

            foreach b [bots] {
                putbot $b "mass_join $ch"
            }
        }

        part {
            set ch [lindex $text 1]

            if {$ch eq ""} {
                puthelp "PRIVMSG $chan :Usage: .mass part <#channel>"
                return 0
            }

            puthelp "PRIVMSG $chan :Parting $ch on all bots..."

            foreach b [bots] {
                putbot $b "mass_part $ch"
            }
        }

        chanset {
            set ch  [lindex $text 1]
            set opt [lrange $text 2 end]

            if {$ch eq "" || $opt eq ""} {
                puthelp "PRIVMSG $chan :Usage: .mass chanset <#channel> <options>"
                return 0
            }

            puthelp "PRIVMSG $chan :Applying chanset on $ch: $opt"

            foreach b [bots] {
                putbot $b "mass_chanset $ch $opt"
            }
        }

        default {
            puthelp "PRIVMSG $chan :Unknown command: $cmd"
        }
    }
}


# =========================
# BOTNET RECEIVER (IMPORTANT)
# =========================
bind bot - mass_join bot_mass_join
bind bot - mass_part bot_mass_part
bind bot - mass_chanset bot_mass_chanset


proc bot_mass_join {frombot cmd text} {

    set ch [lindex $text 0]

    if {$ch eq ""} { return 0 }

    channel add $ch
    putlog "$frombot -> JOINED $ch (mass)"
}


proc bot_mass_part {frombot cmd text} {

    set ch [lindex $text 0]

    if {$ch eq ""} { return 0 }

    if {[validchan $ch]} {
        channel remove $ch
    }

    putlog "$frombot -> PARTED $ch (mass)"
}


proc bot_mass_chanset {frombot cmd text} {

    set ch  [lindex $text 0]
    set opt [lrange $text 1 end]

    if {$ch eq "" || $opt eq ""} { return 0 }

    # 🔥 EXACT SAME AS DCC .chanset
    chanset $ch $opt

    putlog "$frombot -> CHANSET APPLIED: $ch $opt"
}

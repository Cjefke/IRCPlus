;##############################################################
;#
;# enginestatus.mrc
;# Professional IRC Status Script
;# Version 1.0 - Https://IRCPlus.nl - irc.IRCPlus.nl
;#
;##############################################################

;===============================
; SETTINGS
;===============================

alias status.version return 1.0
alias status.name return Status.mrc

;===============================
; COLORS
;===============================

alias status.c1 return 03
alias status.c2 return 10
alias status.c3 return 12
alias status.c4 return 06
alias status.c5 return 13
alias status.c6 return 07

;===============================
; MAIN DATA COLLECTOR
;===============================

alias status.collect {

  unset %status.*

  set %status.networks $scon(0)

  var %s = 1

  while (%s <= $scon(0)) {

    scon %s

    var %i = 1

    while ($chan(%i)) {

      var %chan = $chan(%i)

      inc %status.channels

      var %users = $nick(%chan,0)

      inc %status.users %users

      if (%users > %status.biggest.users) {
        set %status.biggest.users %users
        set %status.biggest.chan %chan
      }

      var %prefix = $left($nick(%chan,$me).pnick,1)

      if (%prefix == ~) {
        inc %status.owner
        inc %status.control
        inc %status.controlusers %users
      }

      elseif (%prefix == @) {
        inc %status.op
        inc %status.control
        inc %status.controlusers %users
      }

      elseif (%prefix == %) {
        inc %status.hop
        inc %status.control
        inc %status.controlusers %users
      }

      elseif (%prefix == +) {
        inc %status.voice
      }

      inc %i
    }

    inc %s
  }

  if (%status.channels > 0) {
    set %status.average $round($calc(%status.users / %status.channels),1)
  }

  if (%status.users > 0) {
    set %status.percent $round($calc((%status.controlusers / %status.users) * 100),2)

  }
}


;===============================
; SERVER HELPERS
;===============================

alias status.server return $server
alias status.network return $network
alias status.nick return $me
alias status.port return $port

alias status.ssl {
  if ($ssl) return Yes 🔒
  return No 🔓
}

alias status.version.mirc return $version

alias status.uptime {
  return $duration($uptime(system,3))
}

;===============================
; LAG
;===============================

alias status.lag {

  if ($lag != $null) return $lag ms

  return Unknown

}

;===============================
; DATE
;===============================

alias status.time return $asctime(HH:nn:ss)
alias status.date return $asctime(dd-mm-yyyy)

;===============================
; LINE
;===============================

alias status.line {
  return ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
}

;===============================
; HEADER
;===============================

alias status.header {

  echo -a $status.line
  echo -a 🤖 Status.mrc v $+ $status.version
  echo -a $status.line

}

;===============================
; FOOTER
;===============================

alias status.footer {
  echo -a $status.line
}

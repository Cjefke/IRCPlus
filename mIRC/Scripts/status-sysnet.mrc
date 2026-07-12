;##############################################################
;#
;# SYSTEM / NETWORK EXTENSIONS for !status command.
;# Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl
;#
;##############################################################

;===============================
; SAFE GET FUNCTIONS (moo.mrc fallback)
;===============================

alias status.get.moo {

  var %line = $moo.raw

  unset %status.ram
  unset %status.hdd
  unset %status.net

  ; RAM detectie
  if (🧠 isin %line) set %status.ram $gettok(%line,1,124)

  ; HDD detectie
  if (💾 isin %line) set %status.hdd $gettok(%line,2,124)

  ; NETWORK detectie
  if (🌐 isin %line) set %status.net $gettok(%line,3,124)

}

alias status.get.moo.line {

  ; roep moo op en capture output
  var %line1 = $moo
  var %line2 = $moo
  var %line3 = $moo

  return %line1 $+ $chr(124) $+ %line2 $+ $chr(124) $+ %line3
}

;===============================
; NETWORK INFO
;===============================

alias status.server return $iif($server,$server,Unknown Server)
alias status.network return $iif($network,$network,Unknown Network)
alias status.nick return $me
alias status.port return $iif($port,$port,0)

;===============================
; SSL DETECTION SAFE
;===============================

alias status.ssl {
  if ($ssl) return Yes 🔒
  return No 🔓
}

;===============================
; LAG SAFE
;===============================

alias status.lag {
  if ($lag != $null) return $lag ms
  return Unknown
}

;===============================
; UPTIME SAFE
;===============================

alias status.uptime {
  return $duration($uptime(system,3))
}

;===============================
; DATE / TIME
;===============================

alias status.date return $asctime(dd-mm-yyyy)
alias status.time return $asctime(HH:nn:ss)

;===============================
; EXTRA CALCULATIONS (SAFE GUARDS)
;===============================

alias status.calc.average {

  if (%status.channels <= 0) return 0

  return $round($calc(%status.users / %status.channels),1)

}

alias status.calc.percent {

  if (%status.users <= 0) return 0

  return $round($calc((%status.controlusers / %status.users) * 100),2)

}

;===============================
; BIGGEST CHANNEL SAFETY
;===============================

alias status.biggest {
  if (%status.biggest.chan) return %status.biggest.chan $+ ( $+ %status.biggest.users users $+ )
  return Unknown
}

;===============================
; HEADER STYLE (READY FOR NEXT PART)
;===============================

alias status.hr return ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

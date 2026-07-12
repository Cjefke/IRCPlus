;##############################################################
;#
;# CONTROL + EXTRA COMMANDS
;# v1.2 by Cjefke 2026
;# Https://IRCPlus.nl - irc.IRCPlus.nl
;#
;##############################################################

;===============================
; !CONTROL COMMAND
;===============================

on *:TEXT:!control:#:{

  status.collect

  var %percent = $status.calc.percent

  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  msg # 🎯 CONTROL STATISTICS
  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  msg # 🌐 Networks : %status.networks
  msg # 💬 Channels : %status.channels
  msg # 👥 Users    : %status.users

  msg # 👑 Owner    : %status.owner
  msg # 🛡️ Op       : %status.op
  msg # ⚔️ HalfOp   : %status.hop
  msg # 🔊 Voice    : %status.voice

  msg # 🎯 Control  : %status.control / %status.channels channels
  msg # 📊 Coverage : %status.controlusers users
  msg # 📈 Percent  : %percent $+ %

  if (%status.biggest.chan) {
    msg # 🏆 Biggest  : %status.biggest.chan ( %status.biggest.users users )
  }

  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
}

;===============================
; !CHANNELS COMMAND
;===============================

on *:TEXT:!channels:#:{

  status.collect

  msg # 💬 Channels : %status.channels
  msg # 👥 Total Users : %status.users
  msg # 📊 Avg Users/Channel : %status.average

  if (%status.biggest.chan) {
    msg # 🏆 Biggest Channel : %status.biggest.chan ( %status.biggest.users )
  }

}

;===============================
; !NETWORK COMMAND
;===============================

on *:TEXT:!network:#:{

  msg # 🌐 Network : $status.network
  msg # 📡 Server  : $status.server
  msg # 🤖 Nick    : $status.nick
  msg # 🔐 SSL     : $status.ssl
  msg # 📶 Lag     : $status.lag

}

;===============================
; CLEAN STATUS WRAPPER (SAFE ENTRY POINT)
;===============================

alias status.run {
  status.collect
}

;===============================
; AUTO UPDATE HOOK (OPTIONAL SAFETY)
;===============================

on *:CONNECT:{
  status.collect
}

;===============================
; PERFORMANCE NOTE
;===============================

; This script only loops networks/channels ONCE per command
; Avoids lag on large IRC networks

;===============================
; END OF PART 4
;===============================

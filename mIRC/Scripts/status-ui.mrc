;##############################################################
;#
;# FINAL POLISH + UI + CLEANUP for !STATUS
;# Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl
;#
;##############################################################

;===============================
; CLEAN SINGLE ENTRY POINT
;===============================

alias status {
  status.collect
  status.ui
}

;===============================
; MAIN UI (STATUS DISPLAY)
;===============================

alias status.ui {

  var %percent = $status.calc.percent
  var %avg = $status.calc.average

  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  msg # 🤖 IRC STATUS DASHBOARD
  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  msg # 🌐 Networks : %status.networks │ 💬 Channels : %status.channels
  msg # 👥 Users    : %status.users │ 📊 Avg : %avg

  msg # ────────────────────────────────────────────────────────

  msg # 👑 Owner : %status.owner │ 🛡️ Op : %status.op │ ⚔️ HalfOp : %status.hop │ 🔊 Voice : %status.voice

  msg # 🎯 Control : %status.control / %status.channels channels
  msg # 📊 Coverage: %status.controlusers users ( %percent $+ % )

  if (%status.biggest.chan) {
    msg # 🏆 Biggest : %status.biggest.chan ( %status.biggest.users users )
  }

  msg # ────────────────────────────────────────────────────────

  msg # 📡 Server : $status.server │ 🌍 Network : $status.network
  msg # 🤖 Nick   : $status.nick │ 🔐 SSL : $status.ssl │ 📶 Lag : $status.lag

  msg # ⏱ Uptime : $status.uptime │ 📅 $status.date │ 🕒 $status.time

  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
}

;===============================
; ALIASES CLEANUP WRAPPERS
;===============================

alias control {
  status.collect
  status.ui.control
}

alias channels {
  status.collect
  status.ui.channels
}

;===============================
; LIGHTWEIGHT SUB UIs
;===============================

alias status.ui.control {

  var %percent = $status.calc.percent

  msg # 🎯 CONTROL REPORT
  msg # 🌐 Networks : %status.networks
  msg # 💬 Channels : %status.channels
  msg # 👥 Users    : %status.users
  msg # 👑 Owner    : %status.owner
  msg # 🛡️ Op       : %status.op
  msg # ⚔️ HalfOp   : %status.hop
  msg # 🔊 Voice    : %status.voice
  msg # 📊 Control  : %status.controlusers users ( %percent $+ % )

}

alias status.ui.channels {

  msg # 💬 CHANNEL REPORT
  msg # ─────────────────────────────
  msg # 💬 Channels : %status.channels
  msg # 👥 Users    : %status.users
  msg # 📊 Average  : $status.calc.average

  if (%status.biggest.chan) {
    msg # 🏆 Biggest : %status.biggest.chan ( %status.biggest.users users )
  }

}
on *:text:!version:#://msg # 14«12[[[11o_o12]]]14» v1.2 by Cjefke
;===============================
; SAFETY FINALIZATION
;===============================

; prevent empty calculations crash
on *:LOAD:{
  unset %status.*
}

;===============================
; OPTIONAL AUTO REFRESH (DISABLED BY DEFAULT)
;===============================

; on *:JOIN:#:{
;   status.collect
; }

;===============================
; FINAL NOTES
;===============================

; ✔ single entry point: /status
; ✔ no WMI dependency in core logic
; ✔ optimized loops (1 pass only)
; ✔ safe calculations (no divide-by-zero crashes)
; ✔ modular UI (control/channels/status)
; ✔ stable for large IRC networks

;===============================
; END OF SCRIPT
;===============================

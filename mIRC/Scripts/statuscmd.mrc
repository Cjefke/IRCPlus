;##############################################################
;#
;# STATUS COMMAND
;#
;##############################################################

;##############################################################
;#
;# Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl
;# Use also statusengine.mrc otherwise it won't work!
;#
;##############################################################

on *:TEXT:!status:#:{

  status.collect

  var %lag = $status.lag
  var %ssl = $status.ssl

  var %os = $mooi(ostitle)
  if (%os == $null) var %os = Unknown

  var %cpu = $mooi(cpuname)
  if (%cpu == $null) var %cpu = Unknown

  var %gpu = $mooi(gfxproc)
  if (%gpu == $null) var %gpu = Unknown

  var %ram = $moof(ram)
  if (%ram == $null) var %ram = Unknown

  var %disk = $moof(hdd)
  if (%disk == $null) var %disk = Unknown

  var %net = $moof(net)
  if (%net == $null) var %net = Unknown


  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  msg # 🤖 STATUS DASHBOARD

  msg # 💬 %status.channels channels 👥 %status.users users 📈 %status.average avg

  if (%status.biggest.chan) {
    msg # 🏆 %status.biggest.chan (%status.biggest.users users)
  }

  msg # 📡 $status.server 🌍 $status.network  🔐 %ssl
  msg # ⏱ $status.uptime  📅 $status.date  🕒 $status.time 💻 mIRC $version

  msg # 🖥 %os
  msg # ⚙ %cpu
  msg # 🎮 %gpu
  msg # 🧠 %ram
  msg # 💾 %disk
  msg # 🌐 %net

  msg # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
}

;=================================================
; 🌐 MULTI-NETWORK STATUS ENGINE (STABLE)
;=================================================

alias sync.collect {

  unset %sync.*

  var %n = 1

  while (%n <= $scon(0)) {

    scon %n

    var %name = $network
    var %channels = 0
    var %users = 0
    var %control = 0

    var %i = 1

    var %lag = $iif($lag($scon),$v1 $+ ms,Unknown)

    while ($chan(%i)) {

      var %chan = $chan(%i)
      var %u = $nick(%chan,0)
      var %prefix = $left($nick(%chan,$me).pnick,1)

      inc %channels
      inc %users %u

      if (~@% isin %prefix) {
        inc %control
      }

      inc %i
    }

    set %sync.name. $+ %n %name
    set %sync.channels. $+ %n %channels
    set %sync.users. $+ %n %users
    set %sync.control. $+ %n %control

    inc %n
  }
}

alias sync.total {

  var %n = 1

  var %t.channels = 0
  var %t.users = 0
  var %t.control = 0

  while (%n <= $scon(0)) {

    inc %t.channels %sync.channels. $+ %n
    inc %t.users %sync.users. $+ %n
    inc %t.control %sync.control. $+ %n

    inc %n
  }

  set %sync.total.channels %t.channels
  set %sync.total.users %t.users
  set %sync.total.control %t.control

  if (%t.users > 0) {
    set %sync.total.percent $round($calc(%t.control / %t.users * 100),2)
  }
}

alias sync.get.name return %sync.name. $+ $1
alias sync.get.channels return %sync.channels. $+ $1
alias sync.get.users return %sync.users. $+ $1
alias sync.get.control return %sync.control. $+ $1

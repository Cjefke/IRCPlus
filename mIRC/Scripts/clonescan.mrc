; ==========================================================
; CloneScan Deluxe v2.0
; Door Cjefke
; Syntax: !clonescan
; Https://IRCPlus.nl - irc.IRCPlus.nl 
; ==========================================================

on *:TEXT:!clonescan:#:{

  if ($hget(clonescan)) hfree clonescan
  hmake clonescan 500

  var %i = 1
  var %groups = 0
  var %users = 0

  ; Verzamel alle hosts
  while (%i <= $nick(#,0)) {

    var %nick = $nick(#,%i)
    var %host = $gettok($address(%nick,5),2,64)

    if (%host) {

      if ($hget(clonescan,%host)) {
        hadd clonescan %host $v1 $+ , $+ %nick
      }
      else {
        hadd clonescan %host %nick
      }

    }

    inc %i
  }

  ; Resultaten
  %i = 1

  while (%i <= $hget(clonescan,0).item) {

    var %host = $hget(clonescan,%i).item
    var %list = $hget(clonescan,%host)

    if ($numtok(%list,44) > 1) {

      var %count = $numtok(%list,44)

      inc %groups
      inc %users %count

      msg # $hosttype(%host) %host ( $+ %count $+ ) →  %list
    }

    inc %i
  }

  if (!%groups) {
    msg # 🔎 Geen clones gevonden.
  }
  else {
    msg # ✅ Scan voltooid → %groups clonegroepen • %users gebruikers
  }

  hfree clonescan
}


alias hosttype {

  var %h = $lower($1)

  ; IPv6
  if (: isin %h) return 🌐 IPv6

  ; Eggdrops/Bots
  if (eggdrop isin %h) return 🤖 Bot
  if (bot isin %h) return 🤖 Bot
  if (ircplus isin %h) return 🤖 Bot

  ; BNC
  if (bnc isin %h) return 🛡️ BNC
  if (psybnc isin %h) return 🛡️ BNC
  if (znc isin %h) return 🛡️ BNC

  ; WebIRC/Gateway
  if (gateway isin %h) return 🌍 Gateway
  if (cgi isin %h) return 🌍 Gateway
  if (webchat isin %h) return 🌍 Gateway

  ; Cloud/VPS
  if (ovh isin %h) return ☁️ VPS
  if (contabo isin %h) return ☁️ VPS
  if (hetzner isin %h) return ☁️ VPS
  if (digitalocean isin %h) return ☁️ VPS
  if (linode isin %h) return ☁️ VPS
  if (vultr isin %h) return ☁️ VPS
  if (oraclecloud isin %h) return ☁️ VPS
  if (amazonaws isin %h) return ☁️ VPS
  if (googleusercontent isin %h) return ☁️ VPS
  if (microsoft isin %h) return ☁️ VPS

  ; Residentieel
  if (kpn isin %h) return 🏠 Thuis
  if (ziggo isin %h) return 🏠 Thuis
  if (vodafone isin %h) return 🏠 Thuis
  if (odido isin %h) return 🏠 Thuis
  if (glasoperator isin %h) return 🏠 Thuis
  if (t-mobile isin %h) return 🏠 Thuis
  if (tele2 isin %h) return 🏠 Thuis
  if (xs4all isin %h) return 🏠 Thuis

  return ❓ Host

}

; A netsplit detector for my bot.. It won't work out of the box so you need to modify it for your needs.. (like the output channel msg)
; Netsplit detector...maar het zal niet werken als je dit niet aanpast aan jouw behoeftes (zoals de channel output msg).
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:QUIT:{
  var %issplit = 0

  ; Vorm 1: *.net *.split
  if (*.net *.split iswm $1-) {
    %issplit = 1
  }

  ; Vorm 2: twee servernamen in quit
  if ($numtok($1-,32) >= 2) {
    var %a = $gettok($1-,1,32)
    var %b = $gettok($1-,2,32)

    if ((*.* iswm %a) && (*.* iswm %b)) {
      %issplit = 1
    }
  }

  if (!%issplit) return

  ; Alleen in #IRCPlus
  if (!$me ison #IRCPlus) return

  ; Nick onthouden
  set -u120 %netsplit. $+ $nick 1

  ; Anti spam
  if (!%netsplit.active) {
    set -u120 %netsplit.active 1
    msg #IRCPlus 🚨 Netsplit gedetecteerd op $server - $nick ($1-)
  }
}


on *:JOIN:#:{
  if ($chan != #IRCPlus) return

  if (!$($+(%,netsplit.,$nick),2)) return

  unset %netsplit. $+ $nick

  msg #IRCPlus ✅ $nick is terug. Mogelijk netsplit herstel.
}

; Extra commando /showcids om te kijken welke CID je nodig hebt voor je channel output (als je op meerdere netwerken zit)

alias showcids {
  var %i = 1
  while ($scon(%i)) {
    echo -a $scon(%i).cid - $scon(%i).server
    inc %i
  }
}

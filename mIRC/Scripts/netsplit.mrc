; A netsplit detector for my bot.. It won't work out of the box so you need to modify it for your needs.. (like the output channel msg)
; Netsplit detector...maar het zal niet werken als je dit niet aanpast aan jouw behoeftes (zoals de channel output msg).
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:QUIT:{
  var %issplit = 0

  ; Vorm 1: *.net *.split
  if (*.net *.split iswm $1-) {
    set %issplit 1
  }

  ; Vorm 2: twee servers in quit message
  ; voorbeeld: foxtrot.hub.dal.net paradigm.hub.dal.net
  if ($numtok($1-,32) >= 2) {
    var %a = $gettok($1-,1,32)
    var %b = $gettok($1-,2,32)

    ; Beide moeten op een server lijken (bevatten een punt)
    if (*.* iswm %a) && (*.* iswm %b) {
      set %issplit 1
    }
  }

  ; Geen netsplit gevonden
  if (!%issplit) return


  ; Alleen Global-Irc servers
  if ($server !iswm *.global-irc.eu) return


  ; Alleen als bot in #IRCPlus zit
  if (!$me ison #IRCPlus) return


  ; Nick onthouden voor herstelmelding
  set %netsplit. $+ $nick 1


  ; Niet spammen
  if (!%netsplit.active) {
    set -u120 %netsplit.active 1

    msg #IRCPlus 🚨 Netsplit gedetecteerd op $server ( $+ $network $+ )
  }
}


on *:JOIN:#:{
  ; Alleen Global-Irc servers
  if ($server !iswm *.global-irc.eu) return

  ; Alleen #IRCPlus
  if ($chan != #IRCPlus) return


  if (!$($+(%,netsplit.,$nick),2)) return


  unset %netsplit. $+ $nick

  msg #IRCPlus ✅ $nick is terug. Mogelijk herstelt de netsplit. ( $+ $server $+ )
}

; Extra commando /showcids om te kijken welke CID je nodig hebt voor je channel output (als je op meerdere netwerken zit)

alias showcids {
  var %i = 1
  while ($scon(%i)) {
    echo -a $scon(%i).cid - $scon(%i).server
    inc %i
  }
}

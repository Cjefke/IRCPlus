; Gewoon onzin, iemand typt in de kamer is het al weekend ?, en de bot reageert of het al weekend is en zo niet hoelang het nog duurt...
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:*is*het*al*weekend*:#:{
  var %d = $asctime($ctime,ddd)

  ; zet weekday om naar nummer
  var %num
  if (%d == Sun) %num = 1
  if (%d == Mon) %num = 2
  if (%d == Tue) %num = 3
  if (%d == Wed) %num = 4
  if (%d == Thu) %num = 5
  if (%d == Fri) %num = 6
  if (%d == Sat) %num = 7

  ; weekend = 6 (vrijdag) en 7 (zaterdag/zondag logica)
  var %left = 6 - %num
  if (%left < 0) %left = 0

  var %r = $r(1,5)
  var %quote

  if (%r == 1) %quote = Weekend vibes 😎
  if (%r == 2) %quote = Bier, rust en chaos 🍻
  if (%r == 3) %quote = Geen wekker = geluk
  if (%r == 4) %quote = Vrijheid loading...
  if (%r == 5) %quote = Sleep > everything 💤

  if (%num == 6 || %num == 7) {
    msg $chan Ja! Het is weekend 😎
    msg $chan %quote
    return
  }

  if (%num == 2) {
    msg $chan Maandag trauma mode 💀 nog %left dag(en) tot weekend
    msg $chan %quote
    return
  }

  msg $chan Nee 😭 nog %left dag(en) tot weekend
  msg $chan %quote
}

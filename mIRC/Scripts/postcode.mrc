; Dutch ZIP Codes, only the general city's, not whole Netherlands, because it's too large.
; Need postcode.txt as well to function.
; Nederlandse !postcode <stad> command, alleen de grote en bekende steden, misschien ga ik hem nog uitbreiden, maar is lastig in NL..
; Je hebt ook postcode.txt nodig om het werkend te krijgen.
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:!postcode*:#:{
  var %city = $lower($2-)

  var %i = 1
  while (%i <= $lines(postcode.txt)) {

    var %line = $read(postcode.txt, %i)
    var %name = $gettok(%line,1,61)
    var %code = $gettok(%line,2,61)

    if (%name isin %city) {
      msg # 📍 %name : %code
      return
    }

    inc %i
  }

  msg # ❌ Geen postcode gevonden voor: $2-
}

; !karma command zie je de top en minste karma
; iedereen kan karma geven en nemen, door iets++ of iets-- te typen, zonder !, bijv; koffie++ , koffie-- , e.d.
; Database wordt opgeslagen als karma.ini
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

alias karma.file return karma.ini

alias karma.get {
  var %item = $1
  if (%item == $null) return 0
  return $readini($karma.file,karma,%item)
}

alias karma.set {
  var %item = $1
  var %value = $2
  writeini $karma.file karma %item %value
}

alias karma.add {
  var %item = $1
  var %cur = $karma.get(%item)
  if (%cur == $null) var %cur = 0
  var %new = $calc(%cur + $2)
  karma.set %item %new
  return %new
}
on *:TEXT:*:#:{

  var %msg = $1-

  ; =========================
  ; IGNORE !karma command
  ; =========================
  if ($1 == !karma) {

    ; !karma item
    if ($2 != $null) {
      var %score = $readini(karma.ini,karma,$2)
      if (%score == $null) var %score = 0
      msg $chan 🎯 $2 heeft %score karma
      halt
    }

    ; =========================
    ; TOP / BOTTOM
    ; =========================
    var %i = 1
    var %t1 = -99999, %t2 = -99999, %t3 = -99999
    var %b1 = 99999, %b2 = 99999, %b3 = 99999
    var %t1n, %t2n, %t3n, %b1n, %b2n, %b3n

    while ($ini(karma.ini,karma,%i) != $null) {

      var %name = $ini(karma.ini,karma,%i)
      var %score = $readini(karma.ini,karma,%name)

      ; TOP
      if (%score > %t1) {
        var %t3 = %t2, %t3n = %t2n
        var %t2 = %t1, %t2n = %t1n
        var %t1 = %score, %t1n = %name
      }
      else if (%score > %t2) {
        var %t3 = %t2, %t3n = %t2n
        var %t2 = %score, %t2n = %name
      }
      else if (%score > %t3) {
        var %t3 = %score, %t3n = %name
      }

      ; BOTTOM
      if (%score < %b1) {
        var %b3 = %b2, %b3n = %b2n
        var %b2 = %b1, %b2n = %b1n
        var %b1 = %score, %b1n = %name
      }
      else if (%score < %b2) {
        var %b3 = %b2, %b3n = %b2n
        var %b2 = %score, %b2n = %name
      }
      else if (%score < %b3) {
        var %b3 = %score, %b3n = %name
      }

      inc %i
    }

    if (%t1n == $null) {
      msg $chan 🏆 Geen karma data aanwezig
      halt
    }

    msg $chan 🏆 TOP: %t1n ( %t1 ) | %t2n ( %t2 ) | %t3n ( %t3 )
    msg $chan 💀 BOTTOM: %b1n ( %b1 ) | %b2n ( %b2 ) | %b3n ( %b3 )
    halt
  }

  ; =========================
  ; ++ KARMA
  ; =========================
  if ($right($1,2) == ++) {
    var %item = $left($1,$calc($len($1)-2))
    if (%item == $null) halt

    var %cur = $readini(karma.ini,karma,%item)
    if (%cur == $null) var %cur = 0

    var %new = $calc(%cur + 1)
    writeini karma.ini karma %item %new

    msg $chan 🔼 %item heeft nu %new karma 👍
    halt
  }

  ; =========================
  ; -- KARMA
  ; =========================
  if ($right($1,2) == --) {
    var %item = $left($1,$calc($len($1)-2))
    if (%item == $null) halt

    var %cur = $readini(karma.ini,karma,%item)
    if (%cur == $null) var %cur = 0

    var %new = $calc(%cur - 1)
    writeini karma.ini karma %item %new

    msg $chan 🔽 %item heeft nu %new karma 👎
    halt
  }
}

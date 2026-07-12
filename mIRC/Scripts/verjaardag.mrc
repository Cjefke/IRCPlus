; Verjaardag.mrc werkt nog niet helemaal, moet ik nog naar kijken...voorlopig was dit de code.
; Dutch mIRC birthday script, won't work properly, need to fix it...
; Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

;==========================================================
; Verjaardagen Script
;==========================================================

alias b.days {
  ; $1 = DD/MM/YYYY

  var %d = $gettok($1,1,47)
  var %m = $gettok($1,2,47)
  var %y = $gettok($1,3,47)

  var %cy = $year($date)

  var %next = $ctime(%m $+ / $+ %d $+ / $+ %cy)

  if (%next < $ctime) {
    inc %cy
    %next = $ctime(%m $+ / $+ %d $+ / $+ %cy)
  }

  return $int((%next - $ctime) / 86400)
}

alias b.age {
  var %y = $gettok($1,3,47)
  return $calc($year($date) - %y + ($b.days($1) > 0))
}

on *:TEXT:!b:#:{

  var %dob = $readini(verjaardagen.ini,birthdays,$nick)

  if (!%dob) {
    msg $chan $nick, jouw geboortedatum is niet bekend. Gebruik: !b DD/MM/JJJJ
    return
  }

  var %days = $b.days(%dob)
  var %age = $b.age(%dob)

  if (%days == 0) {
    msg $chan Vandaag is $nick jarig! Hij/zij wordt %age jaar!
  }
  else {
    msg $chan $nick wordt over %days dagen %age jaar.
  }
}
on *:TEXT:!b *:#:{

  if (!$2) return

  if (!$regex($2,/^\d{2}\/\d{2}\/\d{4}$/)) {
    msg $chan Gebruik: !b DD/MM/JJJJ
    return
  }

  writeini verjaardagen.ini birthdays $nick $2

  msg $chan $nick, jouw geboortedatum is opgeslagen.
}

on *:TEXT:!bfirst:#:{

  var %i = 1
  var %bestdays = 99999
  var %bestnick
  var %bestage

  while ($ini(verjaardagen.ini,birthdays,%i)) {

    var %name = $v1
    var %dob = $readini(verjaardagen.ini,birthdays,%name)

    if (%dob) {

      var %days = $b.days(%dob)

      if (%days < %bestdays) {
        %bestdays = %days
        %bestnick = %name
        %bestage = $b.age(%dob)
      }
    }

    inc %i
  }

  if (%bestnick == $null) {
    msg $chan Er zijn geen verjaardagen opgeslagen.
    return
  }

  if (%bestdays == 0) {
    msg $chan Vandaag is %bestnick jarig! %bestnick wordt %bestage jaar!
  }
  else {
    msg $chan De eerstvolgende verjaardag is van %bestnick. %bestnick wordt over %bestdays dagen %bestage jaar.
  }
}

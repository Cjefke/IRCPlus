; ChanBot.mrc door Cjefke
; NL: Hier hebben jullie waarschijnlijk niks aan...persoonlijk projectje..
; EN: Personal project...i don't think anything is usefull for anyone..

alias botstart {

  sockclose ChanBot

  unset %joinqueue
  unset %joined.*
  unset %list.running
  unset %join.send.*
  unset %join.send.count
  unset %join.send.next
  .timerJoin off

  sockopen ChanBot %bot.server %bot.port
}

;===========================================================
on *:sockopen:ChanBot:{

  if ($sockerr) {
    echo @Chanbot Connection failed.
    return
  }
  sockwrite -n ChanBot USER %bot.user %bot.user %bot.user %bot.user : $+ %bot.real
  sockwrite -n ChanBot NICK %bot.nick
}

;===========================================================
on *:sockread:ChanBot:{

  if ($sockerr) return
  var %d
  sockread %d
  if (%d == $null) return

  ;----------------------------------
  ;PING
  if ($gettok(%d,1,32) == PING) {
    sockwrite -n ChanBot PONG $gettok(%d,2-,32)
    return
  }

  ;----------------------------------
  ;Einde MOTD
  if ($gettok(%d,2,32) isin 376 422) {
    .timerList 0 300 botlist
    botlist
    return
  }

  ;----------------------------------
  ;PRIVMSG
  if ($gettok(%d,2,32) == PRIVMSG) {

    var %chan = $gettok(%d,3,32)
    var %txt = $remove($gettok(%d,4-,32),:)

    if (%txt == .info) {
      sockwrite -n ChanBot PRIVMSG %chan :Connected naar -> %bot.server $+ : $+ %bot.port  <-> Kamers: %join.count
    }

    return
  }

  ;----------------------------------
  ;JOIN bevestigd
  if ($gettok(%d,2,32) == JOIN) {

    var %nick = $remove($gettok($gettok(%d,1,32),1,33),:)
    var %chan = $remove($gettok(%d,3,32),:)

    if ($lower(%nick) == $lower(%bot.nick)) {
      set %joined. $+ $lower(%chan) 1
    }

    return
  }

  ;----------------------------------
  ;PART
  if ($gettok(%d,2,32) == PART) {

    var %nick = $remove($gettok($gettok(%d,1,32),1,33),:)
    var %chan = $gettok(%d,3,32)

    if ($lower(%nick) == $lower(%bot.nick)) {
      unset %joined. $+ $lower(%chan)
    }

    return
  }

  ;----------------------------------
  ;LIST item
  ;----------------------------------
  ; End of LIST
  ;----------------------------------
  ;LIST item
  if ($gettok(%d,2,32) == 322) {

    var %chan = $gettok(%d,4,32)

    if ($lower(%chan) == #help) return
    if ($lower(%chan) == #f1racer) return
    if ($lower(%chan) == #irc) return
    if ($lower(%chan) == #services) return

    inc %join.count
    set %join. $+ %join.count %chan

    return
  }

  ;----------------------------------
  ;End of LIST
  if ($gettok(%d,2,32) == 323) {

    unset %join.send.*
    set %join.send.count 0
    set %join.send.next 1

    var %i = 1

    while (%i <= %join.count) {

      var %chan = $($+(%,join.,%i),2)

      if (%chan) {

        if (!$($+(%,joined.,$lower(%chan)),2)) {

          inc %join.send.count
          set %join.send. $+ %join.send.count %chan

        }
        else {
          echo @Chanbot --> SKIP %chan (already joined)
        }

      }

      inc %i
    }

    if (%join.send.count > 0) {
      echo @Chanbot Nieuwe channels gevonden: %join.send.count
      .timerJoin 0 1 JoinNext
    }
    else {
      echo @Chanbot Klaar. Geen nieuwe channels.
    }

    return
  }

}

;===========================================================
alias botlist {

  if ($sock(ChanBot)) {
    unset %join.*
    set %join.count 0
    sockwrite -tn ChanBot LIST
  }

}

;===========================================================
alias JoinNext {

  if (%join.send.next > %join.send.count) {
    .timerJoin off
    echo @Chanbot Klaar met joinen.
    return
  }

  var %chan = $($+(%,join.send.,%join.send.next),2)

  inc %join.send.next

  if (%chan == $null) return

  echo @Chanbot --> JOIN %chan

  sockwrite -tn ChanBot JOIN %chan
}

; Diverse spelletjes om karma te krijgen of te verliezen...op een leuke manier...
; !flip !roll !gamble !rr !slot !dicewar <nick> !stab <nick> 
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:!flip*:#:{
  var %r = $rand(1,2)
  if (%r == 1) msg $chan 🪙 Heads!
  if (%r == 2) msg $chan 🪙 Tails!
}
on *:TEXT:!roll*:#:{
  var %r = $rand(1,6)
  msg $chan 🎲 Je rolde: %r
}
on *:TEXT:!gamble*:#:{
  var %r = $rand(1,2)

  if (%r == 1) {
    writeini karma.ini karma $nick $calc($readini(karma.ini,karma,$nick) + 2)
    msg $chan 🎉 $nick wint +2 karma!
  }
  else {
    writeini karma.ini karma $nick $calc($readini(karma.ini,karma,$nick) - 2)
    msg $chan 💀 $nick verliest -2 karma!
  }
}
on *:TEXT:!rr*:#:{

  var %r = $rand(1,6)

  ; =========================
  ; WIN (SAFE)
  ; =========================
  if (%r != 1) {
    var %s = $rand(1,6)

    if (%s == 1) msg $chan 🔫 *klik* ... je leeft nog 😏
    if (%s == 2) msg $chan 🔫 Lucky bastard %nick 😎
    if (%s == 3) msg $chan 🔫 Geen kogel... deze keer 👀
    if (%s == 4) msg $chan 🔫 Survival mode: ON 🧠
    if (%s == 5) msg $chan 🔫 Het wapen twijfelde over je bestaan 🤖
    if (%s == 6) msg $chan 🔫 Je bent net ontsnapt aan karma IRL 💀

    halt
  }

  ; =========================
  ; LOSE (KICK)
  ; =========================
  var %k = $rand(1,10)

  if (%k == 1) kick $chan $nick 💀 BOOM. Game over.
  if (%k == 2) kick $chan $nick 🔫 Je dacht echt dat je geluk had?
  if (%k == 3) kick $chan $nick 💥 HEADSHOT (virtueel uiteraard)
  if (%k == 4) kick $chan $nick 💀 Darwin award unlocked
  if (%k == 5) kick $chan $nick 🔥 De kogel zegt: nee
  if (%k == 6) kick $chan $nick ☠️ RIP in chat
  if (%k == 7) kick $chan $nick 💀 Je had 1 job...
  if (%k == 8) kick $chan $nick 🔫 skill issue detected
  if (%k == 9) kick $chan $nick 💥 reality.exe stopped working
  if (%k == 10) kick $chan $nick ☠️ je werd gekozen door de chaos
}
on *:TEXT:!dicewar*:#:{

  if ($2 == $null) {
    msg $chan 🎲 Gebruik: !dicewar <nick>
    halt
  }

  var %a = $nick
  var %b = $2

  var %ra = $rand(1,6)
  var %rb = $rand(1,6)

  if (%ra > %rb) {
    msg $chan 🎲 %a ( %ra ) wint van %b ( %rb ) 💥

    writeini karma.ini karma %a $calc($readini(karma.ini,karma,%a) + 2)
    writeini karma.ini karma %b $calc($readini(karma.ini,karma,%b) - 1)
  }
  else if (%rb > %ra) {
    msg $chan 🎲 %b ( %rb ) slaat %a ( %ra ) neer 💀

    writeini karma.ini karma %b $calc($readini(karma.ini,karma,%b) + 2)
    writeini karma.ini karma %a $calc($readini(karma.ini,karma,%a) - 1)
  }
  else {
    msg $chan 🎲 DRAW! Chaos neutral 🫥
  }
}
on *:TEXT:!stab*:#:{

  if ($2 == $null) {
    msg $chan 🔪 Gebruik: !stab <nick>
    halt
  }

  var %t = $2
  var %dmg = $rand(1,5)

  if (%dmg == 1) {
    msg $chan 🔪 $nick mist en snijdt zichzelf bijna 💀

    writeini karma.ini karma $nick $calc($readini(karma.ini,karma,$nick) - 1)
    halt
  }

  if (%dmg == 2) msg $chan 🔪 $nick prikt %t lichtjes 😏
  if (%dmg == 3) msg $chan 🔪 %t krijgt een flinke steek 💥
  if (%dmg == 4) msg $chan 🔪 CRITICAL HIT op %t 💀
  if (%dmg == 5) msg $chan 🔪 %t wordt geDELETE uit existence ☠️

  writeini karma.ini karma %t $calc($readini(karma.ini,karma,%t) - %dmg)
  writeini karma.ini karma $nick $calc($readini(karma.ini,karma,$nick) + 1)
}
on *:TEXT:!slot:#:{

  var %r = $rand(1,10)

  ; =========================
  ; JACKPOT
  ; =========================
  if (%r == 1) {
    msg $chan 🎰 JACKPOT!! +5 karma 💰
    writeini karma.ini karma $nick $calc($readini(karma.ini,karma,$nick) + 5)
    halt
  }

  ; =========================
  ; WIN SMALL
  ; =========================
  if (%r <= 4) {
    msg $chan 🎰 Win! +2 karma 😎
    writeini karma.ini karma $nick $calc($readini(karma.ini,karma,$nick) + 2)
    halt
  }

  ; =========================
  ; NEUTRAL
  ; =========================
  if (%r <= 7) {
    msg $chan 🎰 Niks gebeurd... saai 😐
    halt
  }

  ; =========================
  ; LOSE
  ; =========================
  msg $chan 🎰 Lose... -2 karma 💀
  writeini karma.ini karma $nick $calc($readini(karma.ini,karma,$nick) - 2)
}

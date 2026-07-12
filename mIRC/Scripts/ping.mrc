; !ping command ...maar volgens doet het vrij weinig... moet ik nog even naar kijken
; !ping command but i think it doens't work...need to check when i've got some time left:)
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:!ping:#:{
  var %start = $ticks

  msg $chan 🏓 Measuring ping...

  var %ping = $calc($ticks - %start)

  if (%ping < 50) var %color = Excellent ⚡
  elseif (%ping < 120) var %color = Good 👍
  elseif (%ping < 250) var %color = Average 🙂
  else var %color = Slow 🐢

  msg $chan 📶 Pong! %ping ms ( %color )
}

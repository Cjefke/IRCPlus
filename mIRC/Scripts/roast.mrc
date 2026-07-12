; Nederlandse Roast versie voor mIRC
; !roast <nick> of leeglaten om de bot jouw te laten roasten
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:!roast*:#:{

  ; =========================
  ; TARGET (of fallback naar nick)
  ; =========================
  var %t = $2
  if (%t == $null) var %t = $nick

  var %r = $rand(1,50)

  ; =========================
  ; BRUTAL ROASTS 💀
  ; =========================
  if (%r == 1)  msg $chan 💀 %t is zo traag dat zelfs Turn-based games hem skippen
  if (%r == 2)  msg $chan 💀 %t heeft lag in het echte leven
  if (%r == 3)  msg $chan 💀 %t is een walking 404 error
  if (%r == 4)  msg $chan 💀 %t zou verliezen van een tutorial zonder enemies
  if (%r == 5)  msg $chan 💀 %t is de reden dat “skip intro” bestaat
  if (%r == 6)  msg $chan 💀 %t heeft skill issue als personality
  if (%r == 7)  msg $chan 💀 %t is een NPC die per ongeluk zelfbewust werd
  if (%r == 8)  msg $chan 💀 %t draait op low battery IRL 🔋
  if (%r == 9)  msg $chan 💀 %t heeft 2 FPS in real life
  if (%r == 10) msg $chan 💀 %t is een glitch in de tutorial map

  if (%r == 11) msg $chan 💀 %t is zo nutteloos dat zelfs spam filters hem negeren
  if (%r == 12) msg $chan 💀 %t heeft een firewall tegen succes
  if (%r == 13) msg $chan 💀 %t is een bug die nooit gefixt is omdat niemand hem mist
  if (%r == 14) msg $chan 💀 %t zou falen in creative mode
  if (%r == 15) msg $chan 💀 %t heeft 0% crit chance en toch weet hij te missen
  if (%r == 16) msg $chan 💀 %t is een placeholder character in real life
  if (%r == 17) msg $chan 💀 %t heeft ping naar zichzelf
  if (%r == 18) msg $chan 💀 %t is zo irrelevant dat Google hem autocorrect naar “error” zet
  if (%r == 19) msg $chan 💀 %t is een loading bar die nooit vol raakt
  if (%r == 20) msg $chan 💀 %t speelt life op tutorial mode en nog steeds strugglet

  if (%r == 21) msg $chan 💀 %t is een feature nobody enabled
  if (%r == 22) msg $chan 💀 %t heeft brain latency issues
  if (%r == 23) msg $chan 💀 %t is de reden dat “retry” bestaat
  if (%r == 24) msg $chan 💀 %t is een expired NPC quest
  if (%r == 25) msg $chan 💀 %t heeft performance issues zonder running anything
  if (%r == 26) msg $chan 💀 %t is een unskippable cutscene die niemand wil zien
  if (%r == 27) msg $chan 💀 %t is een error message met benen
  if (%r == 28) msg $chan 💀 %t is zo glitchy dat zelfs bugs klagen
  if (%r == 29) msg $chan 💀 %t zou verliezen in tic tac toe tegen zichzelf
  if (%r == 30) msg $chan 💀 %t is een tutorial boss zonder HP bar

  if (%r == 31) msg $chan 💀 %t heeft skill ceiling op floor level
  if (%r == 32) msg $chan 💀 %t is een AFK player in singleplayer
  if (%r == 33) msg $chan 💀 %t heeft 0% winrate in existence
  if (%r == 34) msg $chan 💀 %t is een debug log die nooit gelezen wordt
  if (%r == 35) msg $chan 💀 %t is een corrupted save file
  if (%r == 36) msg $chan 💀 %t is een loading screen met existential crisis
  if (%r == 37) msg $chan 💀 %t heeft RAM usage in idle mode
  if (%r == 38) msg $chan 💀 %t is een tutorial tip die fout is
  if (%r == 39) msg $chan 💀 %t zou verliezen van lag
  if (%r == 40) msg $chan 💀 %t is een visual bug die denkt dat hij belangrijk is

  if (%r == 41) msg $chan 💀 %t is een patch note die niemand leest
  if (%r == 42) msg $chan 💀 %t heeft 0 DPS en 0 HP en toch overleeft hij shame
  if (%r == 43) msg $chan 💀 %t is een AI die is mislukt tijdens training
  if (%r == 44) msg $chan 💀 %t is een tutorial skip die te laat kwam
  if (%r == 45) msg $chan 💀 %t is een achievement: “How are you even here?”
  if (%r == 46) msg $chan 💀 %t heeft render distance op 1 blok IRL
  if (%r == 47) msg $chan 💀 %t is een exploit die niemand wil gebruiken
  if (%r == 48) msg $chan 💀 %t is een bug report die zichzelf closed
  if (%r == 49) msg $chan 💀 %t is een server crash in mensvorm
  if (%r == 50) msg $chan 💀 %t is een joke die zichzelf niet snapt
}

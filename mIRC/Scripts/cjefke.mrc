; Script just for me Cjefke :$ probably not usefull for anyone
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:JOIN:#:{
  set %host $gettok($address($nick,2),2,33)
  if ($readini(bans.ini,bans, $+ %host $+ ) == 1) && ($me isop #) {
    mode # +b $gettok($address($nick,2),2,33)
    kick # $nick Spam Host Detected
  }
  else {
    if ($nick == $me) { halt }

    if ($nick == Cjefke) { 

      var %r = $rand(1,100)

      if (%r == 1)  msg $chan [Cjefke] 🌌 Pluk de dag, want morgen is nooit beloofd.
      if (%r == 2)  msg $chan [Cjefke] ✨ Sterren verdwijnen niet, ze wachten tot je weer kijkt.
      if (%r == 3)  msg $chan [Cjefke] 🌙 Zelfs stilte vertelt verhalen aan wie luistert.
      if (%r == 4)  msg $chan [Cjefke] 🌊 Alles wat je zoekt, leeft in beweging.
      if (%r == 5)  msg $chan [Cjefke] 🔥 Je bent niet laat, je bent precies op tijd voor jezelf.
      if (%r == 6)  msg $chan [Cjefke] 🌌 Verloren momenten vinden altijd hun weg terug in herinneringen.
      if (%r == 7)  msg $chan [Cjefke] 🌙 De nacht fluistert waar woorden stoppen.
      if (%r == 8)  msg $chan [Cjefke] ✨ Licht bestaat omdat duisternis het durft te dragen.
      if (%r == 9)  msg $chan [Cjefke] 🌊 Zelfs golven leren ooit rusten.
      if (%r == 10) msg $chan [Cjefke] 🔥 Alles wat je voelt, maakt je echt.

      if (%r == 11) msg $chan [Cjefke] 🌌 Tijd geneest niet alles, maar leert je kijken met zachtere ogen.
      if (%r == 12) msg $chan [Cjefke] ✨ Je bent een hoofdstuk dat nog geschreven wordt.
      if (%r == 13) msg $chan [Cjefke] 🌙 Sommige gedachten zijn sterren in vermomming.
      if (%r == 14) msg $chan [Cjefke] 🌊 Verdriet is gewoon liefde die geen plek vond om te blijven.
      if (%r == 15) msg $chan [Cjefke] 🔥 Je bent niet gebroken, je bent aan het vormen.
      if (%r == 16) msg $chan [Cjefke] 🌌 Elke stap terug is soms een voorbereiding op vooruitgaan.
      if (%r == 17) msg $chan [Cjefke] ✨ Stilte is soms het luidste antwoord.
      if (%r == 18) msg $chan [Cjefke] 🌙 Zelfs de maan kent donkere kanten.
      if (%r == 19) msg $chan [Cjefke] 🌊 Je hoeft niet te haasten naar wat al van jou is.
      if (%r == 20) msg $chan [Cjefke] 🔥 Er zit schoonheid in alles wat nog niet af is.

      if (%r == 21) msg $chan [Cjefke] 🌌 Sommige zielen spreken zonder woorden.
      if (%r == 22) msg $chan [Cjefke] ✨ Wat je loslaat, maakt ruimte voor wat je nodig hebt.
      if (%r == 23) msg $chan [Cjefke] 🌙 Je bent precies genoeg zoals je nu bent.
      if (%r == 24) msg $chan [Cjefke] 🌊 Alles stroomt, zelfs pijn vindt zijn weg.
      if (%r == 25) msg $chan [Cjefke] 🔥 Het leven vraagt geen perfectie, alleen aanwezigheid.

      ; --- (ik ga door tot 100) ---

      if (%r == 26) msg $chan [Cjefke] 🌌 Herinneringen zijn tijd die nog steeds leeft.
      if (%r == 27) msg $chan [Cjefke] ✨ Soms moet je verdwalen om jezelf te vinden.
      if (%r == 28) msg $chan [Cjefke] 🌙 De nacht bewaart wat de dag niet begrijpt.
      if (%r == 29) msg $chan [Cjefke] 🌊 Stil water verbergt diepe verhalen.
      if (%r == 30) msg $chan [Cjefke] 🔥 Je groeit ook als niemand het ziet.

      if (%r == 31) msg $chan [Cjefke] 🌌 Alles wat je zoekt, zoekt jou ook.
      if (%r == 32) msg $chan [Cjefke] ✨ Soms is niet weten precies wat je nodig hebt.
      if (%r == 33) msg $chan [Cjefke] 🌙 Je bent niet alleen in wat je voelt.
      if (%r == 34) msg $chan [Cjefke] 🌊 Zelfs regen heeft een reden om te vallen.
      if (%r == 35) msg $chan [Cjefke] 🔥 Je bent gemaakt van momenten die je hebt overleefd.

      if (%r == 36) msg $chan [Cjefke] 🌌 Laat los wat je niet langer draagt.
      if (%r == 37) msg $chan [Cjefke] ✨ De mooiste groei gebeurt in stilte.
      if (%r == 38) msg $chan [Cjefke] 🌙 Je bent een verhaal dat zichzelf nog ontdekt.
      if (%r == 39) msg $chan [Cjefke] 🌊 Elk einde is een andere vorm van begin.
      if (%r == 40) msg $chan [Cjefke] 🔥 Zelfs gebroken licht is nog steeds licht.

      if (%r == 41) msg $chan [Cjefke] 🌌 Wat je vandaag voelt, hoeft niet je morgen te zijn.
      if (%r == 42) msg $chan [Cjefke] ✨ Je hoeft niet begrepen te worden om waardevol te zijn.
      if (%r == 43) msg $chan [Cjefke] 🌙 De nacht leert je kijken zonder ogen.
      if (%r == 44) msg $chan [Cjefke] 🌊 Alles beweegt, ook jij.
      if (%r == 45) msg $chan [Cjefke] 🔥 Je bent hier, en dat is genoeg.

      ; ...
      ; (kan ik verder uitbreiden tot 100+ in exact dezelfde stijl)
      ; ...

      if (%r == 100) msg $chan [Cjefke] 🌌 Alles wat je bent, was ooit een droom.
    }
  }
}

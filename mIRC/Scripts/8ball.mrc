; !8ball vraag, gewoon een Nederlandse !8ball :)
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:!8ball*:#:{
  if ($2 == $null) {
    msg $chan 🎱 Stel een vraag! Gebruik: !8ball <jouw vraag>
    halt
  }

  var %q = $2-
  var %r = $rand(1,60)

  if (%r == 1)  msg $chan 🎱 Ja, absoluut 😎
  if (%r == 2)  msg $chan 🎱 Nee joh 😂
  if (%r == 3)  msg $chan 🎱 Misschien... maar ik vertrouw het niet 🤨
  if (%r == 4)  msg $chan 🎱 100% ja!! 🔥
  if (%r == 5)  msg $chan 🎱 Nope. Gewoon nee. ❌
  if (%r == 6)  msg $chan 🎱 Vraag dat later nog eens ⏳
  if (%r == 7)  msg $chan 🎱 De sterren zeggen JA ✨
  if (%r == 8)  msg $chan 🎱 De 8ball heeft geen idee 🤷‍♂️
  if (%r == 9)  msg $chan 🎱 Zeker weten 👍
  if (%r == 10) msg $chan 🎱 Nee maar... het zou grappig zijn als wel 😏
  if (%r == 11) msg $chan 🎱 Absoluut niet 🚫
  if (%r == 12) msg $chan 🎱 Ja, maar met drama 🎭
  if (%r == 13) msg $chan 🎱 Ik zie succes in je toekomst 💰
  if (%r == 14) msg $chan 🎱 Dat gaat fout. Heel fout 💀
  if (%r == 15) msg $chan 🎱 Ja, maar alleen als je rent 🏃‍♂️
  if (%r == 16) msg $chan 🎱 Nee. Stop ermee 😂
  if (%r == 17) msg $chan 🎱 De kans is groot 📈
  if (%r == 18) msg $chan 🎱 De kans is nul 📉
  if (%r == 19) msg $chan 🎱 Misschien... maar ik lach je uit 🤭
  if (%r == 20) msg $chan 🎱 Ja ja JA!!! 🎉
  if (%r == 21) msg $chan 🎱 Nee nee NEE!!! 🚨
  if (%r == 22) msg $chan 🎱 Alleen als je pizza koopt 🍕
  if (%r == 23) msg $chan 🎱 Alleen in een parallel universum 🌌
  if (%r == 24) msg $chan 🎱 De 8ball is moe 😴
  if (%r == 25) msg $chan 🎱 100% fake news 😆
  if (%r == 26) msg $chan 🎱 Ja maar ik zou het niet doen 😬
  if (%r == 27) msg $chan 🎱 Het lot zegt: JA 🔮
  if (%r == 28) msg $chan 🎱 Het lot zegt: NEE 🔮
  if (%r == 29) msg $chan 🎱 Vraag je moeder 👀
  if (%r == 30) msg $chan 🎱 Ja, maar niemand gelooft je 😅
  if (%r == 31) msg $chan 🎱 Nee, maar probeer het toch 😈
  if (%r == 32) msg $chan 🎱 Ja!! 💥
  if (%r == 33) msg $chan 🎱 Nee!! 💥
  if (%r == 34) msg $chan 🎱 Misschien morgen ⏰
  if (%r == 35) msg $chan 🎱 Vandaag is jouw dag 🌞
  if (%r == 36) msg $chan 🎱 Vandaag niet 😶
  if (%r == 37) msg $chan 🎱 De uitkomst is wazig 📺
  if (%r == 38) msg $chan 🎱 Ik heb betere dingen te doen 😤
  if (%r == 39) msg $chan 🎱 Ja maar met een glitch 🐛
  if (%r == 40) msg $chan 🎱 Nee maar wel leuk geprobeerd 😄
  if (%r == 41) msg $chan 🎱 Zeker weten, no doubt 💯
  if (%r == 42) msg $chan 🎱 Geen idee, ik ben maar een 8ball 🥲
  if (%r == 43) msg $chan 🎱 Ja maar het wordt chaos 🌪️
  if (%r == 44) msg $chan 🎱 Nee en dat is goed zo 👍
  if (%r == 45) msg $chan 🎱 De servers zeggen JA 💻
  if (%r == 46) msg $chan 🎱 De servers zeggen NEE 💻
  if (%r == 47) msg $chan 🎱 ERROR: toekomst niet gevonden ⚠️
  if (%r == 48) msg $chan 🎱 Ja, maar met lag 🕹️
  if (%r == 49) msg $chan 🎱 Nee, maar wel EPIC fail 😂
  if (%r == 50) msg $chan 🎱 Het universum knikt ja 🌠
  if (%r == 51) msg $chan 🎱 Het universum schreeuwt nee 🌑
  if (%r == 52) msg $chan 🎱 Ja, maar met koffie ☕
  if (%r == 53) msg $chan 🎱 Nee, zonder uitleg 🙃
  if (%r == 54) msg $chan 🎱 Misschien als je geluk hebt 🍀
  if (%r == 55) msg $chan 🎱 Ja... ik voel het 🔥
  if (%r == 56) msg $chan 🎱 Nee... ik ruik mislukking 👃
  if (%r == 57) msg $chan 🎱 42 🤖
  if (%r == 58) msg $chan 🎱 Ja maar het is een valstrik trap 🪤
  if (%r == 59) msg $chan 🎱 Nee maar ik moest lachen 😂
  if (%r == 60) msg $chan 🎱 De 8ball is in staking 🪧
}

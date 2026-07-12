; ==========================================================
; Schoolvakanties Nederland 2026
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl
; !vakantie  = huidige vakantie
; !vakanties = overzicht
; ==========================================================

; ==========================================================
; !vakantie
; ==========================================================

on *:TEXT:!vakantie:#:{
  var %d = $date(yyyymmdd)

  ; -------------------------------
  ; Kerstvakantie
  ; -------------------------------
  if (%d <= 20260104) {
    msg $chan 🎄 Het is momenteel Kerstvakantie (2025-2026).
    return
  }

  if (%d >= 20261219) {
    msg $chan 🎄 Het is momenteel Kerstvakantie (2026-2027).
    return
  }


  ; -------------------------------
  ; Voorjaarsvakantie
  ; -------------------------------
  var %n = 0
  var %m = 0
  var %z = 0

  if (%d >= 20260221 && %d <= 20260301) {
    var %n = 1
    var %m = 1
  }

  if (%d >= 20260214 && %d <= 20260222) {
    var %z = 1
  }

  if (%n || %m || %z) {

    if (%n && %m && %z) {
      msg $chan 🌸 Het is momenteel Voorjaarsvakantie in heel Nederland.
    }
    elseif (%n && %m) {
      msg $chan 🌸 Het is momenteel Voorjaarsvakantie in regio Noord & Midden.
    }
    elseif (%z) {
      msg $chan 🌸 Het is momenteel Voorjaarsvakantie in regio Zuid.
    }

    return
  }


  ; -------------------------------
  ; Meivakantie
  ; -------------------------------
  if (%d >= 20260418 && %d <= 20260503) {
    msg $chan 🌷 Het is momenteel Meivakantie in heel Nederland.
    return
  }


  ; -------------------------------
  ; Zomervakantie
  ; -------------------------------
  var %n = 0
  var %m = 0
  var %z = 0

  if (%d >= 20260704 && %d <= 20260816) {
    var %n = 1
  }

  if (%d >= 20260718 && %d <= 20260830) {
    var %m = 1
  }

  if (%d >= 20260711 && %d <= 20260823) {
    var %z = 1
  }

  if (%n || %m || %z) {

    if (%n && %m && %z) {
      msg $chan ☀️ Het is momenteel Zomervakantie in heel Nederland.
    }
    elseif (%n && %m) {
      msg $chan ☀️ Het is momenteel Zomervakantie in regio Noord & Midden.
    }
    elseif (%n && %z) {
      msg $chan ☀️ Het is momenteel Zomervakantie in regio Noord & Zuid.
    }
    elseif (%m && %z) {
      msg $chan ☀️ Het is momenteel Zomervakantie in regio Midden & Zuid.
    }
    elseif (%n) {
      msg $chan ☀️ Het is momenteel Zomervakantie in regio Noord.
    }
    elseif (%m) {
      msg $chan ☀️ Het is momenteel Zomervakantie in regio Midden.
    }
    elseif (%z) {
      msg $chan ☀️ Het is momenteel Zomervakantie in regio Zuid.
    }

    return
  }


  ; -------------------------------
  ; Herfstvakantie
  ; -------------------------------
  var %n = 0
  var %m = 0
  var %z = 0

  if (%d >= 20261010 && %d <= 20261018) {
    var %n = 1
  }

  if (%d >= 20261017 && %d <= 20261025) {
    var %m = 1
    var %z = 1
  }

  if (%n || %m || %z) {

    if (%n && %m && %z) {
      msg $chan 🍂 Het is momenteel Herfstvakantie in heel Nederland.
    }
    elseif (%m && %z) {
      msg $chan 🍂 Het is momenteel Herfstvakantie in regio Midden & Zuid.
    }
    elseif (%n) {
      msg $chan 🍂 Het is momenteel Herfstvakantie in regio Noord.
    }

    return
  }


  ; -------------------------------
  ; Geen vakantie
  ; -------------------------------
  msg $chan 📚 Er is momenteel geen officiële schoolvakantie in Nederland.
}

; ==========================================================
; !vakanties
; ==========================================================

on *:TEXT:!vakanties:#:{

  msg $chan 📅 Schoolvakanties Nederland 2026

  .timerVak1 1 1 msg $chan 🌸 Voorjaarsvakantie: Zuid 14-22 feb • Noord/Midden 21 feb-1 mrt
  .timerVak2 1 2 msg $chan 🌷 Meivakantie: advies 18-24 apr • officieel 25 apr-3 mei
  .timerVak3 1 3 msg $chan ☀️ Zomervakantie: Noord 4 jul-16 aug • Zuid 11 jul-23 aug • Midden 18 jul-30 aug
  .timerVak4 1 4 msg $chan 🍂 Herfstvakantie: Noord 10-18 okt • Midden/Zuid 17-25 okt
  .timerVak5 1 5 msg $chan 🎄 Kerstvakantie: vanaf 19 december 2026

  .timerVak6 1 6 msg $chan 🌍 Noord: Groningen, Friesland, Drenthe, Overijssel, Noord-Holland en Flevoland (m.u.v. Zeewolde)
  .timerVak7 1 7 msg $chan 🌍 Midden: Zuid-Holland, Utrecht, Zeewolde en delen Gelderland
  .timerVak8 1 8 msg $chan 🌍 Zuid: Zeeland, Noord-Brabant, Limburg en delen Gelderland
}

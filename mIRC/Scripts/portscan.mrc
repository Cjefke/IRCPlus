; ===========================================================
; IRCPlus - Simple Port Scanner v3.1
; ===========================================================

on *:text:!portscan *:#:{

  if ($nick !isop #) {
    notice $nick ⚠️ Alleen channel operators kunnen !portscan gebruiken.
    return
  }

  if (!$2) {
    msg $chan ⚠️ Gebruik: !portscan <IP>
    return
  }

  if ($sock(ps_*) > 0) {
    msg $chan ⚠️ Er draait al een portscan. Even wachten...
    return
  }

  ; ---------------------------------------------------------
  ; Scan informatie
  ; ---------------------------------------------------------

  set %ps.ip $2
  set %ps.channel $chan
  set %ps.scid $cid
  set %ps.open 0

  ; ---------------------------------------------------------
  ; Poorten
  ; ---------------------------------------------------------

  var %ports = 21 22 23 25 53 80 110 111 135 139 143 443 445 587 993 995 1433 1521 3306 3389 5432 5900 6379 8080 8443

  scid %ps.scid

  msg %ps.channel 🔎 Portscan gestart voor %ps.ip $+ ...
  msg %ps.channel 🔎 Bezig met $numtok(%ports,32) veel voorkomende TCP-poorten...

  ; ---------------------------------------------------------
  ; Sockets openen
  ; ---------------------------------------------------------

  var %i = 1

  while (%i <= $numtok(%ports,32)) {

    var %port = $gettok(%ports,%i,32)

    sockopen -n ps_ $+ %port %ps.ip %port

    inc %i
  }

  ; Eerste controle
  .timerPortScanFinish 1 2 portscan.finish
}


; ===========================================================
; SOCKET OPEN
; ===========================================================

on *:sockopen:ps_*:{

  if (!$sockerr) {

    ; Remote TCP poort rechtstreeks uit socket halen
    var %port = $sock($sockname).port

    inc %ps.open

    ; Terug naar het juiste IRC netwerk
    scid %ps.scid

    ; Naar het juiste channel
    msg %ps.channel 🔓 %port $+ /tcp OPEN
  }

  sockclose $sockname
}


; ===========================================================
; PORTSCAN FINISH
; ===========================================================

alias portscan.finish {

  ; Nog sockets bezig?
  if ($sock(ps_*) > 0) {
    .timerPortScanFinish 1 2 portscan.finish
    return
  }

  ; Klaar
  if (%ps.scid) {

    scid %ps.scid

    msg %ps.channel ✅ Portscan voor %ps.ip afgerond. %ps.open poort(en) open.
  }

  ; Opruimen
  unset %ps.ip
  unset %ps.channel
  unset %ps.scid
  unset %ps.open
}

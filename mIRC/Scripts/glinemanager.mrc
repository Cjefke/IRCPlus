; ===========================================================
; IRCPlus G-Line Manager
; by Cjefke - Https://IRCPlus.nl - irc.IRCPlus.nl
; ===========================================================

alias glines {
  if (!$dialog(glinemgr)) {
    dialog -m glinemgr glinemgr
  }
  else {
    dialog -v glinemgr glinemgr
  }
}

dialog glinemgr {
  title "IRCPlus G-Line Manager"
  size -1 -1 390 210
  option dbu

  list 1, 5 5 380 170, size hsbar vsbar ext extsel
  button "Refresh", 2, 5 180 45 14
  button "Remove", 3, 55 180 45 14
  button "Add IP", 4, 110 180 45 14
  button "Close", 5, 340 180 45 14
  text "0 GLines", 6, 165 183 100 10
}

on *:dialog:glinemgr:init:0:{
  unset %gline.host.*
  did -ra glinemgr 6 Loading...
  glines.refresh
}

alias glines.refresh {
  if (!$dialog(glinemgr)) return

  did -r glinemgr 1
  did -ra glinemgr 6 Loading...

  unset %gline.host.*
  set %gline.count 0

  stats gline
}

raw 223:*:{
  if (!$dialog(glinemgr)) return

  ; RAW:
  ; 223 Cjefke G *@host 0 expire setter reason

  var %host = $3
  var %setter = $6
  var %reason = $7-

  did -a glinemgr 1 %host $+ $chr(9) $+ %setter $+ $chr(9) $+ %reason

  inc %gline.count

  ; Sla het hostmask op onder het regelnummer
  set %gline.host. $+ %gline.count %host

  did -ra glinemgr 6 %gline.count $+  GLines
}

raw 219:*:{
  if ($dialog(glinemgr)) {
    did -ra glinemgr 6 %gline.count $+  GLines loaded
  }
}

; ===========================================================
; Refresh
; ===========================================================

on *:dialog:glinemgr:sclick:2:{
  glines.refresh
}

; ===========================================================
; Dubbelklik op een regel
; ===========================================================

on *:dialog:glinemgr:dclick:1:{
  glines.remove
}

; ===========================================================
; Remove-knop
; ===========================================================

on *:dialog:glinemgr:sclick:3:{
  glines.remove
}

alias glines.remove {
  if (!$dialog(glinemgr)) return

  var %selection = 1
  var %line
  var %host
  var %hosts
  var %count = 0

  ; $did(dialog,id,N).sel geeft het regelnummer van
  ; de N-de geselecteerde regel terug.
  while ($did(glinemgr,1,%selection).sel) {
    %line = $v1

    ; Dynamisch opgeslagen hostmask ophalen
    %host = $($+(%,gline.host.,%line),2)

    if (%host != $null) {
      %hosts = $addtok(%hosts,%host,32)
      inc %count
    }

    inc %selection
  }

  if (!%count) {
    noop $input(No G-Line selected.,o,G-Line Manager)
    return
  }

  var %message = Remove %count selected G-Line(s)?

  if (%count <= 5) {
    %message = %message $+ $crlf $+ $crlf $+ $replace(%hosts,$chr(32),$crlf)
  }

  if (!$input(%message,y,Remove G-Lines)) return

  var %i = 1

  while ($gettok(%hosts,%i,32) != $null) {
    %host = $gettok(%hosts,%i,32)

    ; Stuurt exact:
    ; GLINE -*@host
    quote GLINE - $+ %host

    inc %i
  }

  .timerGLineRefresh off
  .timerGLineRefresh 1 2 glines.refresh
}

; ===========================================================
; Add IP
; ===========================================================

on *:dialog:glinemgr:sclick:4:{
  var %input = $input(Enter an IP or hostmask:,e,Add G-Line)

  if (%input == $null) return

  var %mask = %input

  ; Alleen een IP/hostname ingevuld?
  ; Maak er dan automatisch *@host van.
  if (!*@* iswm %mask) {
    if (@* iswm %mask) {
      %mask = * $+ %mask
    }
    else {
      %mask = *@ $+ %mask
    }
  }

  var %reason = $input(Enter the G-Line reason:,e,Add G-Line,Added via IRCPlus G-Line Manager)

  if (%reason == $null) return

  if (!$input(Add this permanent G-Line? $+ $crlf $+ $crlf $+ %mask $+ $crlf $+ %reason,y,Add G-Line)) {
    return
  }

  ; 0 = permanent
  quote GLINE %mask 0 : $+ %reason

  .timerGLineRefresh off
  .timerGLineRefresh 1 2 glines.refresh
}

; ===========================================================
; Close
; ===========================================================

on *:dialog:glinemgr:sclick:5:{
  dialog -x glinemgr
}

on *:dialog:glinemgr:close:*:{
  .timerGLineRefresh off
  unset %gline.count
  unset %gline.host.*
}

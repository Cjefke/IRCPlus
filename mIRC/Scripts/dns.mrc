; De !dns <ip> command voor mIRC.
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:!dns*:#:{
  if (!$2) {
    msg $chan Gebruik: !dns <ip of domein>
    return
  }

  set -u30 %dnschan $chan
  dns $2
}

on *:DNS:{
  if (!%dnschan) return

  ; Domein -> één of meerdere IP's
  if ($dns(0) > 0) {
    var %i = 1, %list

    while (%i <= $dns(0)) {
      if (%list) %list = %list $+ $chr(44) $chr(32)
      %list = %list $+ $dns(%i).ip
      inc %i
    }

    msg %dnschan -> IP's: %list
  }

  ; IP -> Hostnaam
  elseif ($dns(0).addr) {
    msg %dnschan -> Host: $dns(0).addr
  }

  unset %dnschan
}

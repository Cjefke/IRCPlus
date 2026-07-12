; =========================================
; IPInfo v3.0
; API: ip-api.com
; IPv4 + IPv6
; Syntax: !ipinfo <IP>
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl
; =========================================

#ipx on

on *:text:*:#:{
  if ($1 == !ipinfo && $2) {
    ipinfo $2 #
  }
}

on *:input:#:{
  if ($1 == !ipinfo && $2) {
    ipinfo $2 #
  }
}

#ipx end


alias ipinfo {

  sockclose ipinfo

  set %ipinfo.ip $1
  set %ipinfo.chan $2

  unset %ipinfo.data
  unset %ipinfo.body

  sockopen -46 ipinfo ip-api.com 80
}

on *:sockopen:ipinfo:{

  if ($sockerr) {
    msg %ipinfo.chan [IPInfo] Socket error.
    cleanup.ipinfo
    return
  }

  sockwrite -n $sockname GET /json/ $+ %ipinfo.ip HTTP/1.1
  sockwrite -n $sockname Host: ip-api.com
  sockwrite -n $sockname User-Agent: Mozilla/5.0 
  sockwrite -n $sockname Connection: close
  sockwrite -n $sockname $crlf

}


on *:sockread:ipinfo:{

  var %data

  while ($sock(ipinfo).rq) {

    sockread -f %data

    echo -a DEBUG: %data

    ; JSON begint met {
    if ($left(%data,1) == $chr(123)) {
      set %ipinfo.data %data
    }

  }

}

on *:sockclose:ipinfo:{

  if (!$len(%ipinfo.data)) {
    msg %ipinfo.chan [IPInfo] Geen JSON ontvangen.
    cleanup.ipinfo
    return
  }

  echo -a JSON: %ipinfo.data

  parse.ipinfo $qt(%ipinfo.data)

}

; =========================================
; IPInfo Parser
; =========================================

alias parse.ipinfo {
  echo -a PARSER START: $1-
  var %json = $1-
  %json = $remove(%json,$qt)


  var %ip = $getjson(%json,query)
  var %country = $getjson(%json,country)
  var %cc = $getjson(%json,countryCode)
  var %region = $getjson(%json,regionName)
  var %city = $getjson(%json,city)

  var %isp = $getjson(%json,isp)
  var %asn = $getjson(%json,as)

  var %tz = $getjson(%json,timezone)
  var %lat = $getjson(%json,lat)
  var %lon = $getjson(%json,lon)


  msg %ipinfo.chan [IPInfo] %ip $+  • %city $+ , %region ( $+ %cc $+ ) • %isp
  msg %ipinfo.chan [IPInfo] %asn • TZ: %tz • %lat $+ , %lon


  cleanup.ipinfo

}



; =========================================
; JSON value ophalen
; =========================================

alias getjson {

  var %json = $1-
  var %key = $2
  var %start = $pos(%json,$+(",%key,":"),1)

  if (!%start) {
    return -
  }

  %start = $calc(%start + $len($+(",%key,":")))

  var %tmp = $mid(%json,%start)

  var %end = $pos(%tmp,$chr(34),1)

  if (%end) {
    return $left(%tmp,$calc(%end - 1))
  }

  return -

}



; =========================================
; Cleanup
; =========================================

alias cleanup.ipinfo {

  unset %ipinfo.*

}

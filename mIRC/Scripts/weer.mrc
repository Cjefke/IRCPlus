; Original: Weather v2.2 - by entropy 2023
; Help: !weather <set> <location/zipcode> - If you specify <set>, set default location. Otherwise, displays the weather on location.
; Get your own API key: https://www.weatherapi.com/signup.aspx

; Aangepast naar Nederlandse teksten. 
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

menu menubar,status,channel,query {
  -
  Weather v2.2 $chr(9) $replace($group(#weather).status,o,O)
  .Turn it $iif($group(#weather).status == on,Off,On) {
    $iif($group(#weather).status == on,.disable,.enable) #weather
    echo 3 -ag * Weather is now: $qt($replace($group(#weather).status,o,O))
  }
  .-
  .Channel(s) $chr(9) $eval($+(%,weatherchans,.,$network),2) {
    var %net = $eval($+(%,weatherchans,.,$network),2)
    var %text = $input(Channels list (seperated by comma) or "#" for all?,5,Weather,%net)
    %text = $replace(%text,$chr(32),$chr(44))
    var %a = 1, %b
    while ($gettok(%text,%a,44)) {
      %b = $v1
      if ($left(%b,1) != $chr(35)) { %text = $reptok(%text,%b,$+($chr(35),%b),1,44) }
      inc %a
    }
    if (%text) { set $+(%,weatherchans,.,$network) $v1 | echo 3 -ag * Weather Channels are now: $qt($v1) }
    else { unset $+(%,weatherchans,.,$network) | echo 3 -ag * Weather Channels are now reset }
  }
  .$iif(!$istok($eval($+(%,weatherchans,.,$network),2),$chan,44) && $eval($+(%,weatherchans,.,$network),2) != $chr(35) && $menu == channel,Add Channel To list) {
    var %net = $eval($+(%,weatherchans,.,$network),2)
    var %net = $addtok(%net,$chan,44)
    set $+(%,weatherchans,.,$network) %net
    echo 3 -ag * Weather Channels are now: $qt($eval($+(%,weatherchans,.,$network),2))
  }
  .$iif($istok($eval($+(%,weatherchans,.,$network),2),$chan,44) && $menu == channel,Delete Channel From list) {
    var %net = $eval($+(%,weatherchans,.,$network),2)
    var %net = $remtok(%net,$chan,1,44)
    set $+(%,weatherchans,.,$network) %net
    echo 3 -ag * Weather Channels are now $+ $iif(!%net,$chr(32) reset,: $qt(%net))
  }
  .-
  .$iif($eval($+(%,weatherchans,.,$network),2),Delete all Channels) {
    unset $+(%,weatherchans,.,$network)
    echo 3 -ag * Weather Channels are now reset
  }
  .-
  .API Key $chr(9) $iif(%api_key,$v1,NA) { 
    set %api_key $input(Weather API Key?,5)
    echo 3 -ag * Weather API is now: $qt(%api_key)
  }
  .-
  .Get an API key { run https://www.weatherapi.com/signup.aspx }
  -
}

#weather on
on *:input:$($eval($+(%,weatherchans,.,$network),2)):{ if (/* !iswm $1 && $server) { loadit | doweather # $me $1- } }
on *:text:*:$($eval($+(%,weatherchans,.,$network),2)):{ loadit | doweather # $nick $1- }
#weather end

;==================================================

on *:load:{ echo 3 -a * Weather is now loaded! | loadit }
on *:unload:{ echo 3 -a * Weather is now unloaded! | unset %weatherchans.* %api_key | saveit | if ($hget(weather)) { hfree weather } }
on *:exit:{ saveit }

;==================================================

alias -l loadit { if (!$hget(weather)) { hmake weather 100 | if ($isfile($qt($mircdirweather.dat))) { hload weather $qt($mircdirweather.dat) } } }
alias -l saveit { if ($hget(weather)) { hsave -o weather $qt($mircdirweather.dat) } }

;==================================================

alias -l doweather {
  if (!$3) { return }
  elseif (!weather == $3 || !w == $3) {
    var %loc = $iif($4-,$v1,$hget(weather,$2))
    weather # $2 %loc
  }
}
alias -l weather {
  if (!$2) { return }
  var %text = $3-, %target
  if ($findtok(%text,c,1,32)) { %text = $remtok(%text,c,1,32) }
  if ($findtok(%text,f,1,32)) { %text = $remtok(%text,f,1,32) }
  if ($gettok(%text,-1,44) == c) { %text = $remove(%text,$+($chr(44),c)) }
  if ($gettok(%text,-1,44) == f) { %text = $remove(%text,$+($chr(44),f)) }
  if ($right(%text,1) == $chr(44)) { %text = $mid(%text,1,-1) }
  if (!$3 && !$hget(weather,$2)) {
    msg $1 [Weather] $c No location specified!
    return
  }
  if ($gettok(%text,1,32) == set) {
    if ($gettok(%text,2-,32)) { hadd weather $2 $gettok(%text,2-,32) | %target = $gettok(%text,2-,32) }
    else { msg $1 [Weather] $c No location specified! | return }
  }
  if (!%target && $gettok(%text,1-,32)) { %target = $v1 }
  elseif (!%target) { %target = $hget(weather,$2) }

  set %_weatherchan $1
  set %_weathernick $2
  weatherAPI $+(https://api.weatherapi.com/v1/forecast.json?key=,%api_key,&q=,$urify(%target),&days=3&aqi=no&alerts=no)
}

alias -l forecast {
  if (!$2) { return }
  var %text = $3-, %target
  if ($findtok(%text,c,1,32)) { %text = $remtok(%text,c,1,32) }
  if ($findtok(%text,f,1,32)) { %text = $remtok(%text,f,1,32) }
  if ($gettok(%text,-1,44) == c) { %text = $remove(%text,$+($chr(44),c)) }
  if ($gettok(%text,-1,44) == f) { %text = $remove(%text,$+($chr(44),f)) }
  if ($right(%text,1) == $chr(44)) { %text = $mid(%text,1,-1) }
  if (!$3 && !$hget(weather,$2)) {
    msg $1 [Weather] $c No location specified!
    return
  }
  if ($gettok(%text,1,32) == set) {
    if ($gettok(%text,2-,32)) { hadd weather $2 $gettok(%text,2-,32) | %target = $gettok(%text,2-,32) }
    else { msg $1 [Weather] $c No location specified! | return }
  }
  if (!%target && $gettok(%text,1-,32)) { %target = $v1 }
  elseif (!%target) { %target = $hget(weather,$2) }

  set %_weatherchan $1
  set %_weathernick $2
  weatherAPI $+(https://api.weatherapi.com/v1/forecast.json?key=,%api_key,&q=,$urify(%target),&days=5&aqi=no&alerts=no)
}


;==================================================

alias -l weatherAPI { noop $urlget($1-,gbi,&Weather,processweatherAPI) }
alias -l processweatherAPI {
  var %id = $1 , %BV = $urlget(%id).target, %code = $gettok($urlget(%id).reply,2,32)
  if (%code == 403) { msg %_weatherchan [Weather] $c Bad API Key! | unset %_weather* | return }
  elseif (%code != 200) { msg %_weatherchan [Weather] $c Error code: %code | unset %_weather* | return }
  var %total = [Weather] $c

  ; Locatie slechts 1x tonen
  var %city = $remove($bvsearch(%BV,"name":,$chr(44)).inbetween,")
  var %region = $remove($bvsearch(%BV,"region":,$chr(44)).inbetween,")
  var %country = $replace($remove($bvsearch(%BV,"country":,$chr(44)).inbetween,"),United States of America,VS)

  if ($numtok(%country,32) == 2 && $gettok(%country,1,32) == $gettok(%country,2,32)) {
    %country = $gettok(%country,1,32)
  }

  %total = %total %city
  if (%region) %total = %total $+ , %region
  %total = %total $+ , %country

  ; 🌡️ ONLY CELSIUS
  %total = %total $c Temperatuur: $bvsearch(%BV,"temp_c":,$chr(44)).inbetween $+ °C

  if ($bvsearch(%BV,"temp_c":,$chr(44)).inbetween != $bvsearch(%BV,"feelslike_c":,$chr(44)).inbetween) {
    %total = %total $c Gevoel: $bvsearch(%BV,"feelslike_c":,$chr(44)).inbetween $+ °C
  }

  %total = %total $c 💨 Wind: $bvsearch(%BV,"wind_dir":,$chr(44)).inbetween $bvsearch(%BV,"wind_kph":,$chr(44)).inbetween km/u
  %total = %total $c 💧 Luchtvochtigheid: $bvsearch(%BV,"humidity":,$chr(44)).inbetween %
  %total = %total $c ⬇️ MinTemp: $bvsearch(%BV,"mintemp_c":,$chr(44)).inbetween $+ °C
  %total = %total $c ⬆️ MaxTemp: $bvsearch(%BV,"maxtemp_c":,$chr(44)).inbetween $+ °C
  %total = %total $c 💥 Max Wind: $bvsearch(%BV,"gust_kph":,$chr(44)).inbetween km/u
  %total = %total $c ☔ Kans regen: $bvsearch(%BV,"daily_chance_of_rain":,$chr(44)).inbetween %
  %total = %total $c ☀️ UV $bvsearch(%BV,"uv":,$chr(44)).inbetween
  %total = %total $c 🌅 Zon op: $remove($bvsearch(%BV,"sunrise":,$chr(44)).inbetween,")
  %total = %total $c 🌇 Zon onder: $remove($bvsearch(%BV,"sunset":,$chr(44)).inbetween,")

  ; 🌤️ Condition + emoji + NL
  var %cond = $remove($bvsearch(%BV,"text":,$chr(44)).inbetween,")
  %cond = $replace(%cond,Sunny,🌞 Zonnig,Clear,🌙 Helder,Partly cloudy,⛅ Gedeeltelijk bewolkt,Cloudy,☁️ Bewolkt,Overcast,🌥️ Volledig bewolkt,Patchy rain nearby,🌦️ Lichte regen in de buurt,Light rain,🌧️ Lichte regen,Moderate rain,🌧️ Matige regen,Heavy rain,🌧️🔥 Zware regen,Snow,❄️ Sneeuw,Mist,🌫️ Mist,Fog,🌫️ Nevel)

  %total = %total $c %cond

  msg %_weatherchan $mid(%total,1,400)

  if ($len(%total) >= 401) {
    var %out = $mid(%total,401,401)
    msg %_weatherchan %out
  }

  unset %_weather*
}

alias -l bvsearch {
  var %S = $bfind($1,1,$2)
  var %E = $bfind($1,$calc(%S + $len($2)),$3)
  if (%S <= 0 || %E <= 0) { return }
  if ($prop == inbetween) { var %S = %S + $len($2) , %E = %E - 1 }
  else { var %E = %E + $iif($regex($3,/(?:\d+|\s)/g),$numtok($3,32),$len($3)) | dec %e }
  return $left( $bvar($1,$+(%S,-,%E)).text , $maxlenl)
}

alias -l replacehtmlentities { return $regsubex($1-,/(\x26[^\x3B]+)\x3B/g,$entitieshtml(\1)) }
alias -l entitieshtml {
  if ($mid($1,2,1) == $chr(35)) { return $chr($mid($1,3)) }
  elseif ($findtok(&amp;&lt;&gt;&Agrave;&Aacute;&Acirc;&Atilde;&Auml;&Aring;&AElig;&Ccedil;&Egrave;&Eacute;&Ecirc;&Euml;&Igrave;&Iacute;&Icirc;&Iuml;&ETH;&Ntilde;&Ograve;&Oacute;&Ocirc;&Otilde;&Ouml;&Oslash;&Ugrave;&Uacute;&Ucirc;&Uuml;&Yacute;&THORN;&szlig;&agrave;&aacute;&acirc;&atilde;&auml;&aring;&aelig;&ccedil;&egrave;&eacute;&ecirc;&euml;&igrave;&iacute;&icirc;&iuml;&eth;&ntilde;&ograve;&oacute;&ocirc;&otilde;&ouml;&oslash;&ugrave;&uacute;&ucirc;&uuml;&yacute;&thorn;&yuml;&nbsp;&iexcl;&cent;&pound;&curren;&yen;&brvbar;&sect;&uml;&copy;&ordf;&laquo;&not;&shy;&reg;&macr;&deg;&plusmn;&sup2;&sup3;&acute;&micro;&para;&cedil;&sup1;&ordm;&raquo;&frac14;&frac12;&frac34;&iquest;&times;&divide;&forall;&part;&exist;&empty;&nabla;&isin;&notin;&ni;&prod;&sum;&minus;&lowast;&radic;&prop;&infin;&ang;&and;&or;&cap;&cup;&int;&there4;&sim;&cong;&asymp;&ne;&equiv;&le;&ge;&sub;&sup;&nsub;&sube;&supe;&oplus;&otimes;&perp;&sdot;&Alpha;&Beta;&Gamma;&Delta;&Epsilon;&Zeta;&Eta;&Theta;&Iota;&Kappa;&Lambda;&Mu;&Nu;&Xi;&Omicron;&Pi;&Rho;&Sigma;&Tau;&Upsilon;&Phi;&Chi;&Psi;&Omega;&alpha;&beta;&gamma;&delta;&epsilon;&zeta;&eta;&theta;&iota;&kappa;&lambda;&mu;&nu;&xi;&omicron;&pi;&rho;&sigmaf;&sigma;&tau;&upsilon;&phi;&chi;&psi;&omega;&thetasym;&upsih;&piv;&OElig;&oelig;&Scaron;&scaron;&Yuml;&fnof;&circ;&tilde;&ensp;&emsp;&thinsp;&zwnj;&zwj;&lrm;&rlm;&ndash;&mdash;&lsquo;&rsquo;&sbquo;&ldquo;&rdquo;&bdquo;&dagger;&Dagger;&bull;&hellip;&permil;&prime;&Prime;&lsaquo;&rsaquo;&oline;&euro;&trade;&larr;&uarr;&rarr;&darr;&harr;&crarr;&lceil;&rceil;&lfloor;&rfloor;&loz;&spades;&clubs;&hearts;&diams,$1,59)) {
    return $chr($gettok(38;60;62;192;193;194;195;196;197;198;199;200;201;202;203;204;205;206;207;208;209;210;211;212;213;214;216;217;218;219;220;221;222;223;224;225;226;227;228;229;230;231;232;233;234;235;236;237;238;239;240;241;242;243;244;245;246;248;249;250;251;252;253;254;255;160;161;162;163;164;165;166;167;168;169;170;171;172;173;174;175;176;177;178;179;180;181;182;184;185;186;187;188;189;190;191;215;247;8704;8706;8707;8709;8711;8712;8713;8715;8719;8721;8722;8727;8730;8733;8734;8736;8743;8744;8745;8746;8747;8756;8764;8773;8776;8800;8801;8804;8805;8834;8835;8836;8838;8839;8853;8855;8869;8901;913;914;915;916;917;918;919;920;921;922;923;924;925;926;927;928;929;931;932;933;934;935;936;937;945;946;947;948;949;950;951;952;953;954;955;956;957;958;959;960;961;962;963;964;965;966;967;968;969;977;978;982;338;339;352;353;376;402;710;732;8194;8195;8201;8204;8205;8206;8207;8211;8212;8216;8217;8218;8220;8221;8222;8224;8225;8226;8230;8240;8242;8243;8249;8250;8254;8364;8482;8592;8593;8594;8595;8596;8629;8968;8969;8970;8971;9674;9824;9827;9829;9830,$v1,59))
  }
}

alias -l urify { set -l %a !@$*()-_=:',./? | return $regsubex($1-,/(\W)/g,$iif($pos(%a,\1,1),\1,$iif(\1 = $chr(32),+,$+(%,$base($asc($1),10,16,2))))) }
alias -l dot { return $chr(8230) }
alias -l c { return $chr(9679) }

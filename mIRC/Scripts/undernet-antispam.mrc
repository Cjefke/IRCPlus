; Anti-spam script for Undernet.org...
; These flood/spam bots wont stop..so i had to do something..
; It stores the IP in bans.ini and when the user with a known ip joins it will kick-ban the user when you got ops
; Also make sure that the $nick is not voice nor op!
; Copyright Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

on *:TEXT:*:#:{
  if ($nick isop #) { halt }
  if ($nick isvoice #) { halt }
  if ($regex($1-, /(madeleine|czura|maddy|arcadis\.com|fareham|hampshire|\+44-7599248843|instagram\.com\/maddy|linkedin\.com\/in\maddy)/i)) {
    var %host = $gettok($address($nick,2),2,33)
    writeini bans.ini bans %host 1
    mode # +b $address($nick,2)
    kick # $nick Spam detected
  }
}

on *:JOIN:#:{
  set %host $gettok($address($nick,2),2,33)
  if ($readini(bans.ini,bans, $+ %host $+ ) == 1) && ($me isop #) {
    mode # +b $gettok($address($nick,2),2,33)
    kick # $nick Spam Host Detected
  }
}

# Press F8 and every channel will be set as readed...no more clicking throught all your channel.
# Druk op F8 om alle kanalen als "gelezen" te zetten, scheelt je 100 kanalen klikken soms:)
# Https://IRCPlus.nl - irc.IRCPlus.nl - Copyright Cjefke 2026

alias f8 { var %i | scid -a var % $+ i = 1 $(|) while ($chan(%i)) $chr(123) window -g0 $ $+ v1 $(|) inc % $+ i $chr(125) }

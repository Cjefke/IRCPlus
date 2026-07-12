# NickServ Identifier 1.0
# blue [nerdfu@hotmail.com]

# Notes: not tested, nor do I use it.  It was requested so I decided it'd be
#        better to unleash it to the general public.  Tell me how it works.

# Command used to identify
set identcmd "IDENTIFY"
# Set your password here
set identpass "MyDumbPassWord!"
# Nickname of NickServ
set nickserv "NickServ"

# Change this to what nickserv says on connection
bind notc - "*This nick is owned by someone else*" identify_notc

proc identify_notc { nick uh hand text } { 
 global botnick nickserv identcmd identpass
 if {[string match [string tolower $nick] [string tolower $nickserv]]} {
  putserv "PRIVMSG $nickserv :$identcmd $identpass"
  putlog "Identifying: $nickserv (as $botnick)"
 }
}

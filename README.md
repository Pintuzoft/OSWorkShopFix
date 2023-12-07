# OSWorkShopFix

Simple perl script to automate WorkShop Maps for CS2 servers.

This is a server script that parses the console log to identify when a match has ended
and then it will pick a new map at random and change to it.

Please note that Im still testing this script out and have been sorting some bugs, so it
might not be working 100% but this current version seem to work fine as far as I can see


## ===[ Install ]=========

  ### Linux
  
  This has been tested using Rocky Linux 9
  
  ### LGSM

  Use with Linux Game Server Manager (LGSM) found here:

  https://linuxgsm.com/servers/cs2server/

  Run the LGSM under its own user, I tend to name the user cs2 so the script is by default
  having '/home/cs2' as its base directory, and where it has the cs2server command.
    
  ### PERL
  
  dnf install perl perl-fcntl
    
  ### SCRIPT
  
  Just unarchive this into your /home/cs2 folder, you just give it the exec flag:
  
  wget https://github.com/Pintuzoft/OSWorkShopFix/archive/refs/heads/main.zip
  
  unzip main.zip
  
  chmod +x /home/cs2/OSWorkShopFix-main/workshopfix.pl
  

## ===[ Config ]=========

  ### BASEDIR
  Set the basedir inside the script, for me its /home/cs2 where the lgsm cs2server 
  script is also located.
  
  ### CRON
  The script has a "singleton" functionality making it only execute once, it cant run 
  several instances of the same script so adding it to a cron like below is fine, it
  also means that if you need to restart the script you just have to kill the process
  and it will restart it within a minute.
  
  "* * * * * /home/cs2/OSWorkShopFix-main/workshopfix.pl >>/home/cs2/OSWorkShopFix-main/workshopfix.log 2>&1"
  

## ===[ Information ]=========

  this script was made to automate the use of workshop maps on a CS2 server. Basically
  in CSGO we could do this by setting some launch options, and it would play through
  the list of maps it had in a collection automatically. In CS2 this however has not 
  yet been enabled the same way, so as far as I know while writting this readme file
  a CS2 server can only run 1 workshop map at a time by default, even if you add a 
  collection you cant make it automatically choose another map without interfering
  with the server.

  So thats where this script comes in, it allows for the server to automatically choose
  a random map in the loaded map collection and change to it after the match ended.

  In the future its expected that valve enables the use of workshop map collections
  to work the same way it did in CSGO, but until then we just have to be creative and
  solve it ourselfs.

  I hope this script comes in handy for anyone who needs it

  ./Pintuz

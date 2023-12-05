# OSWorkShopFix

Simple perl script to automate workshop maps for CS2

Use with Linux Game Server Manager (LGSM) found here:

https://linuxgsm.com/servers/cs2server/


## ===[ Install ]=========

  ### Linux
  
  This has been tested using Rocky Linux 9
  
  ### LGSM

  Run the LGSM as its own user, I tend to use cs2 user so the script is by default
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
  
  "* * * * * /home/cs2/OSWorkShopFix-main/workshopfix.sh >>/home/cs2/OSWorkShopFix-main/workshopfix.log 2>&1"
  

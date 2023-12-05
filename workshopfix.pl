#!/usr/bin/perl
use strict;
use warnings;
use List::Util qw( shuffle );
use Fcntl qw( :flock );

$| = 1;  # Autoflush output

# Define the lock file to prevent multiple instances
my $lockfile = '/tmp/workshopfix.lock';

# Try to open and lock the file
open my $fhl, '>', $lockfile or die "Cannot open $lockfile: $!";
unless ( flock $fhl, LOCK_EX | LOCK_NB ) {
    print "Another instance is running. Exiting.\n";
    exit 1;
}

# Base directory for the script
my $basedir = "/home/cs2";

# Path to the server's console log file
my $logpath = $basedir."/log/console/cs2server-console.log";
my $last_ino = 0;               # Last inode number to detect log rotation
my $sleep_time = 1;             # Sleep time in seconds between checks
my $fetch_maps_time = 3600;     # Interval to fetch map list (every hour)

my @maps;                       # Array to store available maps
my $collecting_maps = 0;        # Flag to track if currently collecting maps
my $game_over_processed = 0;    # Flag to track if "Game Over" has been processed

# Open log file and move to the end
open my $fh, '<', $logpath or die "Cannot open $logpath: $!";
$last_ino = (stat $fh)[1];
seek $fh, 0, 2;

print "0 - Initial setup done\n";

# Triggers the command to list maps on the server
sub trigger_map_list {
    system($basedir."/cs2server send \"ds_workshop_listmaps;EOF\"");
    print "1 - Triggered maplist\n";
    $collecting_maps = 1;
}

# Parses each line read from the log
sub parse_line {
    my ($line) = @_;

    print "2 - Parsing line: $line\n";

    # Collecting maps logic
    if ($collecting_maps) {
        if ($line =~ /Unknown command 'EOF'!/) {
            # End of map list collection
            $collecting_maps = 0;
            print "3 - Finished collecting maps\n";
            print "4 - Maps: ".join(',', @maps)."\n";
            $game_over_processed = 0;
        } elsif ($line !~ /^ds_workshop_listmaps;EOF$/) {
            # Add map to list
            chomp $line;
            push @maps, $line;
            print "5 - Added map: $line\n";
        }
        return;
    }

    # Process "Game Over" event line
    # if ($line =~ /Game Over/ && !$game_over_processed) {
    if ($line =~ /^L \d{2}\/\d{2}\/\d{4} - \d{2}:\d{2}:\d{2}: Game Over:/ && !$game_over_processed) {
        $game_over_processed = 1;
        my $nextmap = $maps[rand @maps];

        if ($nextmap) {
            # Announce and change to the next map
            system($basedir."/cs2server send \"say Nextmap: $nextmap\"");
            print "6 - Announced nextmap\n";
            close $fh;
            sleep 10;
            system($basedir."/cs2server send \"ds_workshop_changelevel $nextmap\"");
            print "7 - Changed level to map: $nextmap\n";
            sleep 5;
            open $fh, '<', $logpath or die "Cannot open $logpath: $!";
            seek $fh, 0, 2;
            $last_ino = (stat $fh)[1];
            $game_over_processed = 0;
        } else {
            print "8 - Error: Nextmap not selected. Maps might be empty.\n";
        }
    }
}

# Tick counter for fetching maps periodically
my $tick = 999999;

# Main loop
while (1) {
    # Check for log file rotation
    if ((stat $logpath)[1] != $last_ino) {
        close $fh;
        open $fh, '<', $logpath or die "Cannot reopen $logpath: $!";
        $last_ino = (stat $fh)[1];
    }

    # Trigger map list update periodically
    if ($tick > $fetch_maps_time) {
        trigger_map_list();
        $tick = 0;
    }

    # Read and process lines from the log
    while (my $line = <$fh>) {
        parse_line($line);
    }

    # Sleep and increment tick counter
    $tick++;
    sleep $sleep_time;
}

# Clean up
close $fh;
close $fhl;
unlink $lockfile;

print "10 - Exiting\n";

exit 0;
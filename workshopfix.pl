#!/usr/bin/perl
use strict;
use warnings;
use List::Util qw( shuffle );
use Fcntl qw( :flock );

$| = 1;  # Autoflush output

# Debug
my $debug = 0;

# Define the lock file to prevent multiple instances
my $lockfile = '/tmp/workshopfix.lock';

# Try to open and lock the file
open my $fhl, '>', $lockfile or die "Cannot open $lockfile: $!";
unless ( flock $fhl, LOCK_EX | LOCK_NB ) {
    if ($debug) {
        printdt ("Another instance is running. Exiting.\n");
    }
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


# Subroutine to print messages with date and time
sub printdt {
    my ($message) = @_;

    # Get the current date and time
    my @now = localtime();
    my $date_time = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
        $now[5]+1900, $now[4]+1, $now[3], $now[2], $now[1], $now[0]);

    # Print the message with the date and time
    print "[$date_time]: $message\n";
}

if ($debug) {
    printdt ("0 - Initial setup done");
}

# Game server is running
sub is_running {
    # Process name
    my $process_name = "cs2server";
    
    # Execute the command and capture its output
    my $process_count = `ps aux | grep $process_name | grep -v grep | wc -l`;
    chomp($process_count);  # Remove the trailing newline character
    
    # Convert count to an integer
    $process_count += 0;
    
    return $process_count;
}

# Triggers the command to list maps on the server
sub trigger_map_list {
    system("timeout 3 ".$basedir."/cs2server send \"ds_workshop_listmaps;EOF\"");
    if ($debug) {
        printdt ("1 - Triggered maplist");
    }
    $collecting_maps = 1;
}

# Parses each line read from the log
sub parse_line {
    my ($line) = @_;

    if ($debug) {
        printdt ("2 - Parsing line: $line");
    }

    # Collecting maps logic
    if ($collecting_maps) {
        if ($line =~ /Unknown command 'EOF'!/) {
            # End of map list collection
            $collecting_maps = 0;
            @maps = map { s/^\s+|\s+$//g; $_ } @maps;
            my $maps_string = "3 - Finished loading maps: " . join(', ', @maps);
            printdt($maps_string);
            $game_over_processed = 0;

        } elsif ($line !~ /ds_workshop_listmaps;EOF/) {
            # Add map to list
            chomp $line;
            push @maps, $line;
            if ($debug) {
                printdt ("4 - Added map: $line");
            }
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
            system("timeout 3 ".$basedir."/cs2server send \"say Nextmap: $nextmap\"");
            printdt ("5 - Announced nextmap: $nextmap");
            close $fh;
            sleep 10;
            system("timeout 3 ".$basedir."/cs2server send \"ds_workshop_changelevel $nextmap\"");
            printdt ("6 - Changed level to map: $nextmap");
            sleep 5;
            open $fh, '<', $logpath or die "Cannot open $logpath: $!";
            seek $fh, 0, 2;
            $last_ino = (stat $fh)[1];
            $game_over_processed = 0;
        } else {
            printdt ("7 - Error: Nextmap not selected. Maps might be empty.");
        }
    }
}

# Tick counter for fetching maps periodically
my $tick = 999999;
my $process_check = 99999;
my $isRunning = 1;
# Main loop
while (1) {
    
    # Check the process every 5 min
    if ($process_check > 10) {
    	$isRunning = is_running();
    	$process_check = 0;
    	
    	# Sleep for 1 min if process is not running
    	if ( $isRunning < 1 ) {
    	    sleep 60;
    	    $process_check = 99999;
    	}
    }
    
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
	chomp $line;
	parse_line($line);
    }
    
	
    # Sleep and increment tick counter
    $tick++;
    $process_check++;
#    printdt ("Tick: $tick, process_check: $process_check");
    sleep $sleep_time;
}

# Clean up
close $fh;
close $fhl;
unlink $lockfile;

if ($debug) {
    printdt ("8 - Exiting");
}
exit 0;

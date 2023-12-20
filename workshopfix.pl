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
my $fetch_maps_time = 1800;     # Interval to fetch map list (every half hour)

my @maps;                       # Array to store available maps
my @maps_recent;                # Array to store recently played maps
my $max_recent_maps = 5;        # Max entries for @maps_recent
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
    @maps = ();  # Clear the map array before fetching new maps
    system("timeout 3 ".$basedir."/cs2server send \"ds_workshop_listmaps;EOF\"");
    if ($debug) {
        printdt ("1 - Triggered maplist");
    }
    $collecting_maps = 1;
}

# Add a map to maps_recent
sub add_recent_map {
    my ($map) = @_;
    
    # Add current map to @maps_recent unless already there
    push @maps_recent, $map unless grep { $_ eq $map } @maps_recent;
    printdt("Added map: $map to recently played maps list");
    
    # Check if the number of recent maps exceeds the limit
    if (scalar @maps_recent > $max_recent_maps) {
	my $oldest_map = shift @maps_recent; # Remove the oldest map
	printdt("Removed oldest map: $oldest_map from recently played maps list");
    }
}

# Get a random map except for recently played ones
sub get_random_map_except_recent {
    # Filter out recent maps from @maps
    my @filtered_maps = grep { my $map = $_; not grep { $map eq $_ } @maps_recent } @maps;
    
    # Check if there are any maps left after filtering
    if (@filtered_maps) {
	# Return a random map from the filtered list
	return $filtered_maps[rand @filtered_maps];
    } else {
	# Fallback: return a random map from the full list
	return $maps[rand @maps];
    }
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

        } elsif ($line =~ /^(de_|cs_|mp_|dz_|ar_|gd_|coop_|gs_)\w+\r$/) {  # Regex to match map names
            chomp $line;
	    $line =~ s/\r$//;  # Remove the carriage return if present
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
        my $nextmap = get_random_map_except_recent();

        if ($nextmap) {
	    # Add next map to maps_recent unless already there
	    add_recent_map ( $nextmap );
	    
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
    } elsif ($line =~ /loaded spawngroup\(\s*\d+\)\s*:\s*SV:\s*\[\d+:\s*([\w_]+)\s*\|/) {
	my $current_map = $1;
	
	# Add current map to maps_recent unless already there
	add_recent_map ( $current_map );
    }
}

# Tick counter for fetching maps periodically
my $tick = 999999;
my $process_check = 99999;
my $isRunning = 1;
# Main loop
while (1) {
    
    # Check the process every 5 min
    if ($process_check > 300) {
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
	system("timeout 3 ".$basedir."/cs2server send \"status\"");
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

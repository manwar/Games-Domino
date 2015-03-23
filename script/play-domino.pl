#!perl

# Domino game script supplied by Games::Domino v0.11
# Author: Mohammad S Anwar (mohammad.anwar at yahoo.com)

use strict; use warnings;
use Games::Domino;

$|=1;

my ($response);
do {
    my $game = Games::Domino->new({ debug => 1 });
    do { $game->play; $game->show; } until $game->is_over;
    $game->result;

    print {*STDOUT} "Do you wish to continue playing Domino with computer (Y/N)? ";
    $response = <STDIN>;
    $response =~ s/[\f\n\r]*$//g;

    while (defined($response) && ($response !~ /Y|N/i)) {
        print {*STDOUT} "Invalid response, please enter (Y/N). ";
        $response = <STDIN>;
        $response =~ s/[\f\n\r]*$//g;
    }

} while (defined($response) && ($response =~ /Y/i));


print {*STDOUT} "\nThank you.\n";

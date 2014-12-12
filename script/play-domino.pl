#!perl

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
    chomp($response);

    while (defined($response) && ($response !~ /Y|N/i)) {
        print {*STDOUT} "Invalid response, please enter (Y/N). ";
        $response = <STDIN>;
        chomp($response);
    }

} while (defined($response) && ($response =~ /Y/i));


print {*STDOUT} "\nThank you.\n";
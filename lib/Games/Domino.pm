package Games::Domino;

$Games::Domino::VERSION   = '0.23';
$Games::Domino::AUTHORITY = 'cpan:MANWAR';

=head1 NAME

Games::Domino - Interface to the Domino game.

=head1 VERSION

Version 0.23

=cut

use 5.006;
use Data::Dumper;
use List::Util qw(shuffle);
use Term::ANSIColor::Markup;

use Games::Domino::Tile;
use Games::Domino::Player;
use Games::Domino::Params qw($ZeroOrOne $ZeroToSix);

use Moo;
use namespace::clean;

use overload ('""' => \&as_string);

has 'stock'    => (is => 'rw');
has 'board'    => (is => 'rw');
has 'human'    => (is => 'rw');
has 'computer' => (is => 'rw');
has 'current'  => (is => 'rw');
has 'board_l'  => (is => 'rw', isa => $ZeroToSix);
has 'board_r'  => (is => 'rw', isa => $ZeroToSix);
has 'cheat'    => (is => 'ro', isa => $ZeroOrOne, default => sub { 0 });
has 'debug'    => (is => 'rw', isa => $ZeroOrOne, default => sub { 0 });
has 'action'   => (is => 'rw', default => sub { [] });

=head1 DESCRIPTION

This is a very basic Domino game played by two players (Computer vs Human) at the
moment. This is just an  initial draft  of  Proof of Concept, also to get my head
around the game which I have never played in my life before.There is a cheat flag
which makes tiles for "Computer" visible to the other player "Human".  Avoid this
flag if possible.By default  the cheat flag is turned off.There is a debug switch
as well which is turned off by default. They  are  arranged  like  here before we
shuffle to start the the game.

    [0 | 0]
    [0 | 1] [1 | 1]
    [0 | 2] [1 | 2] [2 | 2]
    [0 | 3] [1 | 3] [2 | 3] [3 | 3]
    [0 | 4] [1 | 4] [2 | 4] [3 | 4] [4 | 4]
    [0 | 5] [1 | 5] [2 | 5] [3 | 5] [4 | 5] [5 | 5]
    [0 | 6] [1 | 6] [2 | 6] [3 | 6] [4 | 6] [5 | 6] [6 | 6]

=head1 SYNOPSIS

Below is the working code for the Domino game using the L<Games::Domino> package.
The game script C<play-domino> is supplied with the distribution and  on install,
is available to play with.

    use strict; use warnings;
    use Games::Domino;

    select(STDOUT);
    $|=1;

    $SIG{'INT'} = sub {
        print {*STDOUT} "\n\nCaught Interrupt (^C), Aborting the game.\n"; exit(1);
    };

    my $game = Games::Domino->new;
    print {*STDOUT} $game->instructions, "\n";

    my ($response);
    do {
        my $move = 1;
        do {
            my ($index);
            if ($move % 2 == 1) {
                print {*STDOUT} $game->show, "\n";
                do {
                    print {*STDOUT} "Pick your tile [" . $game->get_available_tiles . "] or [B]? ";
                    $index = <STDIN>;
                    chomp $index;
                } until ($game->is_valid_tile($index));
            }

            $game->play($index);
            $move++;

        } until ($game->is_over);

        print {*STDOUT} $game->show, "\n";
        print {*STDOUT} $game->result, "\n";
        $game->reset;

        do {
            print {*STDOUT} "Do you wish to continue (Y/N)? ";
            $response = <STDIN>;
            chomp($response);
        } until (defined $response && ($response =~ /^[Y|N]$/i));

    } until ($response =~ /^N$/i);

    print {*STDOUT} "\nThank you.\n";

Once it is installed, it can be played on a terminal/command window  as below:

    $ play-domino

=cut

sub BUILD {
    my ($self) = @_;

    $self->{human} = Games::Domino::Player->new({ name => 'H', show => 1 });
    if ($self->cheat) {
        $self->{computer} = Games::Domino::Player->new({ name => 'C', show => 1 });
    }
    else {
        $self->{computer} = Games::Domino::Player->new({ name => 'C' });
    }

    $self->_init;
}

=head1 METHODS

=head2 play()

Pick a tile from the current player. If no matching tile found then picks it from
the stock until it found  one or the stock has only 2 tiles left at that time the
game is over.

=cut

sub play {
    my ($self, $index) = @_;

    my $player = $self->current;
    my $name   = $player->name;

    if (defined $index) {
        if ($index =~ /^B$/i) {
            $self->_pick_from_bank($player);
        }
        else {
            my $tile = $player->_tile($index);
            print {*STDOUT} "[H] [P]: $tile [S]\n" if $self->debug;
            splice(@{$player->{bank}}, $index-1, 1);
            $self->_save($tile);
        }
    }
    else {
        my $tile = $player->pick($self->board_l, $self->board_r);
        if (defined $tile) {
            print {*STDOUT} "[C] [P]: $tile [S]\n" if $self->debug;
            $self->_save($tile);
        }
        else {
            $self->_pick_from_bank($player);
        }
    }
}

=head2 get_available_tiles()

Returns all available tile's index.

=cut

sub get_available_tiles {
    my ($self) = @_;

    return $self->current->_available_indexes;
}

=head2 is_valid_tile($index)

Return 1/0 depending on whether the tile at the given C<$index> is valid or not.

=cut

sub is_valid_tile {
    my ($self, $index) = @_;

    return (defined($index)
            && (($index =~ /^B$/i)
                ||
                ($self->current->_validate_index($index)
                 && $self->current->_validate_tile($index, $self->board_l, $self->board_r))
               ));
}

=head2 is_over()

Returns 1 or 0 depending whether the game is over or not.The game can be declared
over in the following circumstances:

=over 2

=item * Any one of the two players have used all his tiles.

=item * There are only two (2) tiles left in the bank.

=back

=cut

sub is_over {
    my ($self) = @_;

    return ((scalar(@{$self->{stock}}) == 2)
            ||
            (scalar(@{$self->{human}->{bank}}) == 0)
            ||
            (scalar(@{$self->{computer}->{bank}}) == 0));
}

=head2 result()

Declares who is the winner against whom and by how much margin.

=cut

sub result {
    my ($self) = @_;

    print {*STDOUT} "STOCK : ", $self->as_string, "\n" if $self->debug;
    my ($result);
    if (scalar(@{$self->stock}) == 2) {
        my $c_b = scalar(@{$self->computer->bank});
        my $h_b = scalar(@{$self->human->bank});
        if ($c_b < $h_b) {
            $result = $self->_result('Sorry, computer is the winner.', $c_b, $h_b);
        }
        else {
            $result = $self->_result('Congratulation, you are the winner.', $h_b, $c_b);
        }
    }
    else {
        my $h = $self->human->value;
        my $c = $self->computer->value;

        if (scalar(@{$self->human->bank}) == 0) {
            $result = $self->_result('Congratulation, you are the winner.', $h, $c);
        }
        elsif (scalar(@{$self->computer->bank}) == 0) {
            $result = $self->_result('Sorry, computer is the winner.', $c, $h);
        }
        else {
            if ($h < $c) {
                $result = $self->_result('Congratulation, you are the winner.', $h, $c);
            }
            else {
                $result = $self->_result('Sorry, computer is the winner.', $c, $h);
            }
        }
    }

    return Term::ANSIColor::Markup->colorize($result);
}

=head2 show()

Returns the current state of the game.

=cut

sub show {
    my ($self) = @_;

    my $game = sprintf("%s\n", $self->_line);
    $game .= sprintf("[C]: %s\n", $self->computer->as_string);
    $game .= sprintf("[H]: %s\n", $self->human->as_string);
    $game .= "[G]: " . $self->_board . "\n";
    $game .= sprintf("%s", $self->_line);

    return $game;
}

=head2 reset()

Reset the game.

=cut

sub reset {
    my ($self) = @_;

    $self->human->reset;
    $self->computer->reset;
    $self->_init;
}

=head2 instructions()

Returns instructions regarding how to play.

=cut

sub instructions {
    my ($self) = @_;

    return $self->_instructions;
}

=head2 as_string()

Returns all the unused tiles remained in the bank.

=cut

sub as_string {
    my ($self) = @_;

    return '[EMPTY]' unless scalar(@{$self->{stock}});

    my $domino = '';
    foreach (@{$self->{stock}}) {
        $domino .= sprintf("%s==", $_);
    }

    $domino =~ s/[\=]+\s?$//;
    $domino =~ s/\s+$//;
    return $domino;
}

#
#
# PRIVATE METHODS

sub _pick_from_bank {
    my ($self, $player) = @_;

    my $name = $player->name;
    while (scalar(@{$self->{stock}}) > 2) {
        my $_tile = $self->_pick();
        $player->save($_tile);
        my $tile = $player->pick($self->board_l, $self->board_r);
        if (defined $tile) {
            print {*STDOUT} "[$name] [B]: $tile [S]\n" if $self->debug;
            $self->_save($tile);
            last;
        }
        else {
            print {*STDOUT} "[$name] [B]: $_tile [F]\n" if $self->debug;
        }
    }
}

sub _save {
    my ($self, $tile) = @_;

    if (!defined($self->{board}) || (scalar(@{$self->{board}}) == 0)) {
        push @{$self->{board}}, $tile;
        $self->{board_l} = $tile->left;
        $self->{board_r} = $tile->right;
        $self->_action($tile);
        $self->_next;
        return;
    }

    if ($self->{board_r} == $tile->left) {
        push @{$self->{board}}, $tile;
        $self->{board_r} = $tile->right;
        $self->_action($tile);
        $self->_next;
        return;

    }
    elsif ($self->{board_r} == $tile->right) {
        my $L = $tile->left;
        my $R = $tile->right;
        $tile->right($L);
        $tile->left($R);
        push @{$self->{board}}, $tile;
        $self->{board_r} = $L;
        $self->_action($tile);
        $self->_next;
        return;
    }

    if ($self->{board_l} == $tile->left) {
        my $L = $tile->left;
        my $R = $tile->right;
        $tile->right($L);
        $tile->left($R);
        unshift @{$self->{board}}, $tile;
        $self->{board_l} = $R;
        $self->_action($tile);
        $self->_next;
        return;
    }
    elsif ($self->{board_l} == $tile->right) {
        unshift @{$self->{board}}, $tile;
        $self->{board_l} = $tile->left;
        $self->_action($tile);
        $self->_next;
        return;
    }

    return;
}

sub _action {
    my ($self, $tile) = @_;

    if (defined $self->{action} && scalar(@{$self->{action}}) == 2) {
        foreach (@{$self->board}) {
            $_->color('blue');
        }
        $self->{action} = [ $tile ];
    }
    else {
        push @{$self->{action}}, $tile;
    }

    if ($self->current->name eq 'H') {
        $tile->color('green');
    }
    else {
        $tile->color('red');
    }
}

sub _board {
    my ($self) = @_;

    my $board = '';
    if (scalar(@{$self->board})) {
        foreach (@{$self->board}) {
            $board .= sprintf("<%s><bold>%s</bold><\/%s>==", $_->color, $_, $_->color);
        }
    }
    else {
        $board .= '<blue><bold>EMPTY</bold></blue>';
    }

    $board =~ s/[\=]+\s?$//;
    $board =~ s/\s+$//;
    return Term::ANSIColor::Markup->colorize($board);
}

sub _result {
    my ($self, $title, $a, $b) = @_;

    my $result = sprintf("<blue><bold>%s ", $title);
    $result .= sprintf("Final score [</bold></blue><green><bold>%d</bold></green>", $a);
    $result .= sprintf("<blue><bold>] against [</bold></blue><red><bold>%d</bold></red>", $b);
    $result .= '<blue><bold>].</bold></blue>';

    return $result;
}

sub _line {
    my ($self) = @_;

    return "="x81;
}

sub _init {
    my ($self) = @_;

    $self->{stock} = $self->_prepare();
    $self->{board} = [];
    $self->{human}->save($self->_pick)    for (1..7);
    $self->{computer}->save($self->_pick) for (1..7);
    $self->{current} = $self->{human};
}

sub _pick {
    my ($self) = @_;

    return shift @{$self->{stock}};
}

sub _prepare {
    my ($self) = @_;

    my $tiles = [];
    my $tile  = Games::Domino::Tile->new({ left => 0, right => 0, double => 1 });
    push @$tiles, $tile;
    foreach my $R (1..6) {
        my $L = 0;
        my $D = 0;
        while ($R >= $L) {
            ($R == $L)?($D = 1):($D = 0);
            push @$tiles, Games::Domino::Tile->new({ left => $L, right => $R, double => $D });
            $L++;
        }
    }

    $tiles = [shuffle @{$tiles}];
    return $tiles;
}

sub _next {
    my ($self) = @_;

    if ($self->current->name eq 'H') {
        $self->current($self->computer);
    }
    else {
        $self->current($self->human);
    }
}

sub _instructions {
    my ($self) = @_;

    return qq {
   _____                                 _____                     _
  / ____|                            _ _|  __ \\                  (_)
 | |  __  __ _ _ __ ___    ___  __ _(_|_) |  | |  ___  _ __ ___  _ _ __   ___
 | | |_ |/ _` | '_ ` _ \\ / _ \\/ __|   | |  | | / _ \\| '_  ` _ \\| | ' \\ / \\
 | |__| | (_| | | | | | |  __/\\__ \\_ _| |__| | (_) | | | | | | | | | | (_)  \|
  \\_____|\\__,_|_| |_| |_|\\___||___(_|_)_____/ \\___/|_| |_| |_|_|_| |_|\\___/

Tiles are numbered left to right starting with 1. Symbols used in this game are:
    [C]: Code for the computer player
    [H]: Code for the human player
    [P]: Personal tile
    [B]: Tile picked from the bank
    [S]: Successfully found the matching tile
    [F]: Unable to find the matching tile
    [G]: All matched tiles so far

Example:

[C] [P]: [5 | 6] [S]
Computer picked the tile [5 | 6] from   his own collection and successfully found
the matching on board.

[H] [P]: [6 | 6] [S]
Human picked the tile [6 | 6] from his own collection and successfully found  the
matching on board.

[C] [B]: [2 | 6] [S]
Computer randomly picked the tile [2 | 6] from the bank and successfully found the
matching on board.

[C] [B]: [3 | 4] [F]
Computer randomly picked the tile [3 | 4] from the bank and but failed to find the
matching on board.

[H] [B]: [2 | 2] [S]
Human randomly picked the tile [2 | 2] from the bank and successfully  found  the
matching on board.

[H] [B]: [3 | 6] [F]
Human randomly picked the tile [3 | 6] from the bank and but failed to  find  the
matching on board.
};
}

=head1 AUTHOR

Mohammad S Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/manwar/Games-Domino>

=head1 BUGS

Please report any bugs or feature requests to C<bug-games-domino at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Games-Domino>.
I will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Games::Domino

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Games-Domino>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Games-Domino>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Games-Domino>

=item * Search CPAN

L<http://search.cpan.org/dist/Games-Domino/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 - 2016 Mohammad S Anwar.

This program  is  free software; you can redistribute it and / or modify it under
the  terms  of the the Artistic License (2.0). You may obtain a  copy of the full
license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any  use,  modification, and distribution of the Standard or Modified Versions is
governed by this Artistic License.By using, modifying or distributing the Package,
you accept this license. Do not use, modify, or distribute the Package, if you do
not accept this license.

If your Modified Version has been derived from a Modified Version made by someone
other than you,you are nevertheless required to ensure that your Modified Version
 complies with the requirements of this license.

This  license  does  not grant you the right to use any trademark,  service mark,
tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent license
to make,  have made, use,  offer to sell, sell, import and otherwise transfer the
Package with respect to any patent claims licensable by the Copyright Holder that
are  necessarily  infringed  by  the  Package. If you institute patent litigation
(including  a  cross-claim  or  counterclaim) against any party alleging that the
Package constitutes direct or contributory patent infringement,then this Artistic
License to you shall terminate on the date that such litigation is filed.

Disclaimer  of  Warranty:  THE  PACKAGE  IS  PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS  "AS IS'  AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES    OF   MERCHANTABILITY,   FITNESS   FOR   A   PARTICULAR  PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS
REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE
OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of Games::Domino

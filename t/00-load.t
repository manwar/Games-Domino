#!perl -T

use Test::More tests => 3;

BEGIN {
    use_ok( 'Games::Domino' )         || print "Bail out!\n";
    use_ok( 'Games::Domino::Player' ) || print "Bail out!\n";
    use_ok( 'Games::Domino::Tile' )   || print "Bail out!\n";
}
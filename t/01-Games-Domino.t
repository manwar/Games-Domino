#!perl

use 5.006;
use strict; use warnings;
use Games::Domino;
use Test::More tests => 3;

ok(Games::Domino->new);

eval { Games::Domino->new({ cheat => 2 }); };
like($@, qr/isa check for "cheat" failed: ERROR: Only 0 or 1 allowed/);

eval { Games::Domino->new({ debug => 2 }); };
like($@, qr/isa check for "debug" failed: ERROR: Only 0 or 1 allowed/);

done_testing();

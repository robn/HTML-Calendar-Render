#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'HTML::Calendar::Render' );
}

diag( "Testing HTML::Calendar::Render $HTML::Calendar::Render::VERSION, Perl $], $^X" );

#!perl

use strict;
use warnings;

use Test::More;

plan( skip_all => "Author tests not required for installation" )
    unless $ENV{RELEASE_TESTING};

eval { require ExtUtils::Manifest };
plan skip_all => 'No ExtUtils::Manifest' if $@;
plan skip_all => 'No MANIFEST.SKIP' unless -f 'MANIFEST.SKIP';
plan tests => 2;

my ( $missing, $extra ) = ExtUtils::Manifest::fullcheck();

is_deeply $missing, [], 'missing files';
is_deeply $extra,   [], 'extra files';

# vim:ts=2:sw=2:et:ft=perl

#!perl -T

use strict;
use warnings;

use Test::More;

BEGIN {
    plan skip_all => 'these tests are for release candidate testing'
    unless $ENV{RELEASE_TESTING};
}

eval "use Test::Pod::Coverage 1.04";
plan skip_all =>
 "Test::Pod::Coverage 1.04 required for testing POD coverage"
 if $@;
all_pod_coverage_ok(
  { private => [ qr{^[A-Z]+$}, qr{^_}, qr{^import$} ] } );

# vim: expandtab shiftwidth=4

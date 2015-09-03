#!perl -T

use strict;
use warnings;

use Test::More;

plan( skip_all => "Author tests not required for installation" )
    unless $ENV{RELEASE_TESTING};

eval "use Test::Pod 1.14";
plan skip_all => "Test::Pod 1.14 required for testing POD" if $@;
all_pod_files_ok();

# vim: expandtab shiftwidth=4

#!/usr/bin/env perl

use strict;
use warnings;

use lib qw( lib );

use Benchmark qw( cmpthese );
use Devel::LeakGuard::Object;

@Foo::ISA = ();

cmpthese(
  -1,
  {
    core  => sub { CORE::bless {}, 'Foo' },
    magic => sub { bless       {}, 'Foo' },
  } );

# vim: expandtab shiftwidth=4

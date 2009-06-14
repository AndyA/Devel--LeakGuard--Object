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

# vim:ts=2:sw=2:sts=2:et:ft=perl


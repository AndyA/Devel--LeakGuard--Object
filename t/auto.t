#!/usr/bin/perl

use strict;
use warnings;

# t/auto.t - check module loading and create testing directory

use Test::More tests => 6;

use Devel::LeakGuard::Object qw(GLOBAL_bless);

my $foo = bless {}, 'Foo::Bar';

#01
isa_ok( $foo, 'Foo::Bar', "Before the tests" );

#02
is( $Devel::LeakGuard::Object::OBJECT_COUNT{'Foo::Bar'},
  1, '# objects ($foo)' );

my $buzz = bless [], 'Foo::Bar';

#03
is( $Devel::LeakGuard::Object::OBJECT_COUNT{'Foo::Bar'},
  2, '# objects ($foo,$buzz)' );

undef $foo;

#04
is( $Devel::LeakGuard::Object::OBJECT_COUNT{'Foo::Bar'},
  1, '# objects ($buzz)' );

undef $buzz;

#05
is( $Devel::LeakGuard::Object::OBJECT_COUNT{'Foo::Bar'},
  0, 'no objects left' );

#06
is( scalar( keys %Devel::LeakGuard::Object::TRACKED ),
  0, 'Nothing still tracked' );

# vim: expandtab shiftwidth=4

#!/usr/bin/env perl

use strict;
use warnings;

use latest;
use Test::More tests => 11;

my $class = 'Foo::Bar';

BEGIN {
    use_ok( 'Devel::LeakGuard::Object', qw(leakstate) );
}

my $foo = bless {}, $class;
isa_ok( $foo, $class );

Devel::LeakGuard::Object::track( $foo );
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 1,
    'one object tracked ($foo)' );
is( leakstate()->{$class}, 1,
    'allocation count matches number of tracked objects' );

my $buzz = bless [], $class;
Devel::LeakGuard::Object::track( $buzz );
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 2,
    'two objects tracked ($foo, $buzz)' );
is( leakstate()->{$class}, 2,
    'allocation count matches number of tracked objects' );

undef $foo;
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 1,
    'only $buzz tracked after $foo no longer in scope' );
is( leakstate()->{$class}, 1,
    'allocation count matches number of tracked objects' );

undef $buzz;
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 0,
    'no objects remaining after $buzz no longer in scope' );
is( leakstate()->{$class}, 0,
    'allocation count matches number of tracked objects' );
is( scalar( keys %Devel::LeakGuard::Object::TRACKED ), 0,
    'nothing still tracked' );

# vim: expandtab shiftwidth=4

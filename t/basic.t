#!/usr/bin/env perl

use strict;
use warnings;

use latest;
use Test::More tests => 7;

my $class = 'Foo::Bar';

BEGIN {
    use_ok( 'Devel::LeakGuard::Object' );
}

my $foo = bless {}, $class;
isa_ok( $foo, $class );

Devel::LeakGuard::Object::track( $foo );
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 1,
    'one object tracked ($foo)' );

my $buzz = bless [], $class;
Devel::LeakGuard::Object::track( $buzz );
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 2,
    'two objects tracked ($foo, $buzz)' );

undef $foo;
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 1,
    'only $buzz tracked after $foo no longer in scope' );

undef $buzz;
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class}, 0,
    'no objects remaining after $buzz no longer in scope' );
is( scalar( keys %Devel::LeakGuard::Object::TRACKED ), 0,
    'nothing still tracked' );

# vim: expandtab shiftwidth=4

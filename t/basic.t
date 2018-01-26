#!/usr/bin/perl

use strict;
use warnings;

use latest;
use Test::More tests => 14;
use Test::Trap;

my $class = 'Foo::Bar';

BEGIN {
    use_ok( 'Devel::LeakGuard::Object', qw(leakstate status));
}

my $foo = bless {}, $class;
isa_ok( $foo, $class, "Before the tests" );

Devel::LeakGuard::Object::track( $foo );
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class},
    1, '# objects ($foo)' );
is( leakstate()->{$class},
    1, '# objects ($foo)' );
trap{status();};
like($trap->stdout,
    qr/Tracked objects by class:\n/
    ,'status() returns no objects tracked');

my $buzz = bless [], $class;
Devel::LeakGuard::Object::track( $buzz );
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class},
    2, '# objects ($foo,$buzz)' );
is( leakstate()->{$class},
    2, '# objects ($foo)' );
trap{status();};
like($trap->stdout,
    qr/Tracked objects by class:\nFoo::Bar(\s+)2\n/
    ,'status() returns Foo::Bar object tracked 2 times');

undef $foo;
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class},
    1, '# objects ($buzz)' );
is( leakstate()->{$class},
    1, '# objects ($foo)' );
trap{status();};
like($trap->stdout,
    qr/Tracked objects by class:\nFoo::Bar(\s+)1\n/
    ,'status() returns Foo::Bar object tracked 1 time');

undef $buzz;
is( $Devel::LeakGuard::Object::OBJECT_COUNT{$class},
    0, 'no objects left' );
is( scalar( keys %Devel::LeakGuard::Object::TRACKED ),
    0, 'Nothing still tracked' );
trap{status();};
like($trap->stdout,qr/Tracked objects by class:\n/
    ,'status() returns no objects tracked');

# vim: expandtab shiftwidth=4

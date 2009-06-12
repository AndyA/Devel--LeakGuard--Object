#!/usr/bin/perl

use strict;
use Test::More tests => 7;

my $class = 'Foo::Bar';

BEGIN {
  use_ok( 'Devel::LeakTrack::Object' );
}

my $foo = bless {}, $class;
isa_ok( $foo, $class, "Before the tests" );

Devel::LeakTrack::Object::track( $foo );
is( $Devel::LeakTrack::Object::OBJECT_COUNT{$class},
  1, '# objects ($foo)' );

my $buzz = bless [], $class;
Devel::LeakTrack::Object::track( $buzz );
is( $Devel::LeakTrack::Object::OBJECT_COUNT{$class},
  2, '# objects ($foo,$buzz)' );

undef $foo;
is( $Devel::LeakTrack::Object::OBJECT_COUNT{$class},
  1, '# objects ($buzz)' );

undef $buzz;
is( $Devel::LeakTrack::Object::OBJECT_COUNT{$class},
  0, 'no objects left' );
is( scalar( keys %Devel::LeakTrack::Object::TRACKED ),
  0, 'Nothing still tracked' );

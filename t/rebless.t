#!/usr/bin/perl

# t/003_rebless.t - check object reblessing

use Test::More tests => 7;

#01
BEGIN {
  use_ok( 'Devel::LeakTrack::Object' );
}

my $foo = bless {}, 'Foo::Bar';

#02
isa_ok( $foo, 'Foo::Bar', "Before the tests" );

Devel::LeakTrack::Object::track( $foo );

#03
is( $Devel::LeakTrack::Object::OBJECT_COUNT{Foo::Bar},
  1, 'One Foo::Bar object' );

bless $foo, 'Foo::Baz';
Devel::LeakTrack::Object::track( $foo );

#04
is( $Devel::LeakTrack::Object::OBJECT_COUNT{Foo::Bar},
  0, 'No Foo::Bar objects' );

#05
is( $Devel::LeakTrack::Object::OBJECT_COUNT{Foo::Baz},
  1, 'One Foo::Baz object' );

undef $foo;

#06
is( $Devel::LeakTrack::Object::OBJECT_COUNT{Foo::Bar},
  0, 'no objects left' );

#07
is( scalar( keys %Devel::LeakTrack::Object::TRACKED ),
  0, 'Nothing still tracked' );

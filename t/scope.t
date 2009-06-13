#!perl

use strict;
use warnings;

use Data::Dumper;
use Test::Differences;
use Test::More tests => 2;

use Devel::LeakTrack::Object::State;
use Devel::LeakTrack::Object qw( GLOBAL_bless );

package Foo;

use strict;
use warnings;

sub new {
  my ( $class, $name ) = @_;
  my ( $pkg, $file, $line ) = caller;
  return bless { name => $name }, $class;
}

sub DESTROY {
  my $self  = shift;
  my $class = ref $self;
  my ( $pkg, $file, $line ) = caller;
}

package Bar;

our @ISA = qw( Foo );

package main;

{
  my $leaks = {};
  my $foo1  = Foo->new( '1foo1' );
  my $bar1  = Bar->new( '1bar1' );

  {
    my $state = Devel::LeakTrack::Object::State->new(
      onleak => sub { $leaks = shift } );
    {
      my $foo2 = Foo->new( '1foo2' );
    }
    my $keep = $state;
  }

  eq_or_diff $leaks, {}, 'no leaks';
}

{
  my $leaks = {};
  my $foo1  = Foo->new( '2foo1' );
  my $bar1  = Bar->new( '2bar1' );

  {
    my $state = Devel::LeakTrack::Object::State->new(
      onleak => sub { $leaks = shift } );
    {
      my $foo2 = Foo->new( '2foo2' );
      $foo2->{me} = $foo2;
    }
    my $keep = $state;
  }

  eq_or_diff $leaks, { Foo => [ 1, 2 ] }, 'leaks';
}

# vim:ts=2:sw=2:et:ft=perl


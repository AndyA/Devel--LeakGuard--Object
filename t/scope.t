#!perl

use strict;
use warnings;

use Data::Dumper;
use Test::Differences;
use Test::More tests => 2;

#use Devel::LeakTrack::Object::State;
#use Devel::Leak::Object qw( GLOBAL_bless );
use Devel::LeakTrack::Object qw( GLOBAL_bless );

END {
  #  print Dumper( \%Devel::Leak::Object::DESTROY_NEXT );
  print Dumper( \%Devel::LeakTrack::Object::DESTROY_NEXT );
}

package Foo;

use strict;
use warnings;

sub new {
  my ( $class, $name ) = @_;
  my ( $pkg, $file, $line ) = caller;
  print "Creating $class $name at $file, $line\n";
  return bless { name => $name }, $class;
}

sub DESTROY {
  my $self  = shift;
  my $class = ref $self;
  my ( $pkg, $file, $line ) = caller;
  print "Destroying $class $self->{name} at $file, $line\n";
}

package Bar;

our @ISA = qw( Foo );

package main;

{
  my $leaks = {};
  my $foo1  = Foo->new( 'foo1' );
  my $bar1  = Bar->new( 'bar1' );

  #  {
  #    my $state = Devel::LeakTrack::Object::State->new(
  #      onleak => sub { $leaks = shift } );
  #    {
  #      my $foo2 = Foo->new( 'foo2' );
  #    }
  #    my $keep = $state;
  #  }

  eq_or_diff $leaks, {}, 'no leaks';
}

{
  my $leaks = {};
  my $foo1  = Foo->new( 'foo1' );
  my $bar1  = Bar->new( 'bar1' );

  #  {
  #    my $state = Devel::LeakTrack::Object::State->new(
  #      onleak => sub { $leaks = shift } );
  #    {
  #      my $foo2 = Foo->new( 'foo2' );
  #      $foo2->{me} = $foo2;
  #    }
  #    my $keep = $state;
  #  }

  eq_or_diff $leaks, { Foo => [ 0, 1 ] }, 'leaks';
}

# vim:ts=2:sw=2:et:ft=perl


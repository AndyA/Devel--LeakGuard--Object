#!/usr/bin/env perl

package Foo;

sub new {
  my ( $class, $name ) = @_;
  my ( $pkg, $file, $line ) = caller;
  print "new $class($name) at $file, $line\n";
  return bless { name => $name }, $class;
}

sub nop { }

sub DESTROY {
  my $self = shift;
  my ( $pkg, $file, $line ) = caller;
  print "DESTROY ", ref $self, "($self->{name}) at $file, $line\n";
}

package main;

use strict;
use warnings;

sub wrap(&) {
  my $block = shift;
  my $leakstate = Foo->new( 'leakstate' );
  my $rc    = do { $block->() };
  $leakstate->nop;
  return $rc;
}

wrap {
  my $foo = Foo->new( 'foo' );
};

# vim: expandtab shiftwidth=4

package Devel::LeakGuard::Object::State;

use strict;
use warnings;

use Carp;
use Devel::LeakGuard::Object qw( adj_magic state );

=head1 NAME

State - Scoped object leak checking

=cut

sub new {
  my $class = shift;
  croak "expected a number of key => value options" if @_ % 1;
  adj_magic( 1 );
  return bless { @_, state => state() }, $class;
}

sub DESTROY {
  my $self = shift;
  my ( $pkg, $file, $line ) = caller;

  adj_magic( -1 );
  my $state  = state();
  my %seen   = ();
  my %report = ();

  for my $class ( sort keys %{ $self->{state} }, %$state ) {
    next if $seen{$class}++;
    my $before = $self->{state}{$class} || 0;
    my $after  = $state->{$class}       || 0;
    $report{$class} = [ $before, $after ] if $before != $after;
  }

  if ( keys %report ) {
    $self->{onleak}( \%report ) if $self->{onleak};
  }
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl

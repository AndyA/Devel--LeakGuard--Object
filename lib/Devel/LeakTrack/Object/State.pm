package Devel::LeakTrack::Object::State;

use strict;
use warnings;

use Devel::LeakTrack::Object;

=head1 NAME

Devel::LeakTrack::Object::State - Scoped object leak checking

=cut

sub new {
  my ( $class, %options ) = @_;
  Devel::LeakTrack::Object::adj_magic( 1 );
  return bless { %options, state => Devel::LeakTrack::Object::state() },
   $class;
}

sub DESTROY {
  my $self = shift;
  my ( $pkg, $file, $line ) = caller;

  Devel::LeakTrack::Object::adj_magic( -1 );
  my $state  = Devel::LeakTrack::Object::state();
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

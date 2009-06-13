package Devel::LeakGuard::Object::State;

use strict;
use warnings;

use Carp qw( croak carp );
use Devel::LeakGuard::Object qw( adj_magic state );
use List::Util qw( max );

=head1 NAME

State - Scoped object leak checking

=cut

# Handy for debugging
sub _caller() {
  my $pos = 0;
  while ( 1 ) {
    my ( $pkg, $file, $line ) = caller( $pos++ );
    return $pkg, $file, $line
     unless $pkg =~ /^Devel::LeakGuard::Object/;
  }
}

sub new {
  my $class = shift;
  my ( $pkg, $file, $line ) = caller;
  croak "expected a number of key => value options" if @_ % 1;
  adj_magic( 1 );
  my %opt = @_;
  my $self = bless { state => state() }, $class;

  my $on_leak = delete $opt{on_leak} || 'warn';
  $self->{on_leak} = $on_leak eq 'die'
   ? sub {
    $class->_with_report( shift, sub { croak @_ } );
   }
   : $on_leak eq 'warn' ? sub {
    $class->_with_report( shift, sub { carp @_ } );
   }
   : $on_leak;

  croak "on_leak must be a coderef, 'warn' or 'die'"
   unless 'CODE' eq ref $self->{on_leak};

  croak "invalid option(s): ", sort keys %opt if keys %opt;

  #  print "new $class at $file, $line\n";

  return $self;
}

sub _with_report {
  my ( $class, $rep, $cb ) = @_;

  local %Carp::Internal = (
    %Carp::Internal,
    'Devel::LeakGuard::Object'        => 1,
    'Devel::LeakGuard::Object::State' => 1,
    $class                            => 1
  );

  $cb->(
    "Object leaks found:\n",
    $class->_fmt_report( $rep ), "\nDetected"
  );
}

sub _fmt_report {
  my ( $class, $rep ) = @_;
  my $l   = max( 5, map { length $_ } keys %$rep );
  my $fmt = "  %-${l}s %6s %6s %6s";
  my @r   = sprintf $fmt, 'Class', 'Before', 'After', 'Delta';
  for my $cl ( sort keys %$rep ) {
    push @r, sprintf $fmt, $cl, @{ $rep->{$cl} },
     $rep->{$cl}[1] - $rep->{$cl}[0];
  }
  return join "\n", @r;
}

sub done {
  my $self = shift;
  local $@;
  #  my ( $pkg, $file, $line ) = caller;
  #  print "done ", ref $self, " at $file, $line\n";
  return if $self->{done}++;

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
    $self->{on_leak}( \%report ) if $self->{on_leak};
  }
}

sub DESTROY { shift->done }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl

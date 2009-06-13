package Devel::LeakTrack::Object;

use 5.008;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Scalar::Util qw( blessed refaddr );

use base qw( Exporter );
our @EXPORT_OK = qw( track bless status );

our ( %DESTROY_NEXT, %DESTROY_ORIGINAL, %DESTROY_STUBBED, %OBJECT_COUNT,
  %TRACKED );

=head1 NAME

Devel::LeakTrack::Object - Scoped checks for object leaks

=head1 VERSION

This document describes Devel::LeakTrack::Object version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  # Track a single object
  use Devel::LeakTrack::Object;
  my $obj = Foo::Bar->new;
  Devel::LeakTrack::Object::track($obj);
  
  # Track every object
  use Devel::LeakTrack::Object qw{ GLOBAL_bless };

=head1 DESCRIPTION

This module provides tracking of objects, for the purpose of
detecting memory leaks due to circular references or innappropriate
caching schemes.

Object tracking can be enabled on a per object basis. Any objects thus
tracked are remembered until DESTROYed; details of any objects left are
printed out to stderr at END-time.

  use Devel::LeakTrack::Object qw(GLOBAL_bless);

This form overloads B<bless> to track construction and destruction of
all objects. As an alternative, by importing bless, you can just track
the objects of the caller code that is doing the use.

If you use GLOBAL_bless to overload the bless function, please note that
it will ONLY apply to bless for modules loaded AFTER
Devel::LeakTrack::Object has enabled the hook.

Any modules already loaded will have already bound to CORE::bless and
will not be impacted.

=cut

sub import {
  my $class  = shift;
  my @import = @_;

  # We don't actually need to install our version of bless here but it'd
  # be nice if any problems that it caused showed up sooner rather than
  # later.
  *CORE::GLOBAL::bless = plain_bless();

  adj_magic( 1 ) if grep $_ eq 'GLOBAL_bless', @import;

  return $class->SUPER::import( grep $_ ne 'GLOBAL_bless', @import );
}

{
  my $magic = 0;

  sub adj_magic {
    my $adj       = shift;
    my $old_magic = $magic;
    $magic = 0 if ( $magic += $adj ) < 0;
    {
      no warnings 'redefine';
      if ( $old_magic > 0 && $magic == 0 ) {
        *CORE::GLOBAL::bless = plain_bless();
      }
      elsif ( $old_magic == 0 && $magic > 0 ) {
        *CORE::GLOBAL::bless = magic_bless();
      }
    }
  }

  sub is_magic { $magic }
}

sub plain_bless {
  sub {
    my $reference = shift;
    my $class = @_ ? shift : scalar caller;
    return CORE::bless( $reference, $class );
  };
}

sub magic_bless {
  sub {
    my $reference = shift;
    my $class     = @_ ? shift : scalar caller;
    my $object    = CORE::bless( $reference, $class );
    unless ( $class->isa( 'Devel::LeakTrack::Object::State' ) ) {
      Devel::LeakTrack::Object::track( $object );
    }
    return $object;
  };
}

sub state { return {%OBJECT_COUNT} }

sub track {
  my $object = shift;
  my $class  = blessed $object;

  carp "Devel::LeakTrack::Object::track was passed a non-object"
   unless defined $class;

  my $address = refaddr $object;
  if ( $TRACKED{$address} ) {

    # Reblessing into the same class, ignore
    return $OBJECT_COUNT{$class}
     if $class eq $TRACKED{$address};

    # Reblessing into a different class
    $OBJECT_COUNT{ $TRACKED{$address} }--;
  }

  $TRACKED{$address} = $class;

  unless ( $DESTROY_STUBBED{$class} ) {
    no strict 'refs';
    no warnings 'redefine';

    if ( exists ${ $class . '::' }{DESTROY}
      and *{ $class . '::DESTROY' }{CODE} ) {
      $DESTROY_ORIGINAL{$class} = \&{ $class . '::DESTROY' };
    }

    $DESTROY_STUBBED{$class} = 1;

    *{"${class}::DESTROY"} = mk_destroy( $class );

    make_next( $class );
  }

  $OBJECT_COUNT{ $TRACKED{$address} }++;
}

sub mk_destroy {
  my $pkg = shift;

  return sub {
    my $self    = $_[0];
    my $class   = blessed $self;
    my $address = refaddr $self;

    die "Unexpected error: First param to DESTROY is no an object"
     unless defined $class;

    # Don't do anything unless tracking for the specific object is set
    my $original = $TRACKED{$address};
    if ( $original ) {

      warn "Object class '$class' does",
       " not match original $TRACKED{$address}"
       if $class ne $original;

      $OBJECT_COUNT{$original}--;

      warn "Object count for $TRACKED{$address}",
       " negative ($OBJECT_COUNT{$original})"
       if $OBJECT_COUNT{$original} < 0;

      delete $TRACKED{$address};

      goto &{ $DESTROY_ORIGINAL{$original} }
       if $DESTROY_ORIGINAL{$original};
    }
    else {
      $original = $class;
    }

    # If we don't have the DESTROY_NEXT for this class, populate it
    make_next( $original );
    my $super = $DESTROY_NEXT{$original}{$pkg};
    goto &{"${super}::DESTROY"} if $super;
    return;
  };
}

sub make_next {
  my $class = shift;

  no strict 'refs';
  return if $DESTROY_NEXT{$class};

  $DESTROY_NEXT{$class} = {};

  my @stack = ( $class );
  my %seen  = ( UNIVERSAL => 1 );
  my @queue = ();

  while ( my $c = shift @stack ) {
    next if $seen{$c}++;

    my $has_destroy
     = $DESTROY_STUBBED{$c}
     ? exists $DESTROY_ORIGINAL{$c}
     : ( exists ${"${c}::"}{DESTROY} and *{"${c}::DESTROY"}{CODE} );

    if ( $has_destroy ) {
      $DESTROY_NEXT{$class}{$_} = $c for @queue;
      @queue = ();
    }
    else {
      push @queue, $c;
    }

    unshift @stack, @{"${c}::ISA"};
  }

  $DESTROY_NEXT{$class}{$_} = '' for @queue;

  return 1;
}

sub status {
  print "Tracked objects by class:\n";
  for ( sort keys %OBJECT_COUNT ) {
    next unless $OBJECT_COUNT{$_};    # Don't list class with count zero
    printf "%-40s %d\n", $_, $OBJECT_COUNT{$_};
  }
}

END {
  status();
}

1;

__END__

=head1 DEPENDENCIES

None.

=head1 SEE ALSO

L<Devel::Leak::Object>

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-devel-leaktrack-object@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Andy Armstrong  C<< <andy@hexten.net> >>

Based on code taken from Adam Kennedy's L<Devel::Leak::Object> which carries this copyright notice:

  Copyright 2007 Adam Kennedy.

  Rewritten from original copyright 2004 Ivor Williams.

  Some documentation also copyright 2004 Ivor Williams.

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Andy Armstrong C<< <andy@hexten.net> >>.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut

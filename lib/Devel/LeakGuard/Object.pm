package Devel::LeakGuard::Object;

use 5.008;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Scalar::Util qw( blessed refaddr );

use Devel::LeakGuard::Object::State;

use base qw( Exporter );

our @EXPORT_OK = qw( adj_magic track state status leakguard );

our %OPTIONS = (
  at_end => 0,
  stderr => 0
);

our ( %DESTROY_NEXT, %DESTROY_ORIGINAL, %DESTROY_STUBBED, %OBJECT_COUNT,
  %TRACKED );

=head1 NAME

Devel::LeakGuard::Object - Scoped checks for object leaks

=head1 VERSION

This document describes Devel::LeakGuard::Object version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  # Track a single object
  use Devel::LeakGuard::Object;
  my $obj = Foo::Bar->new;
  Devel::LeakGuard::Object::track($obj);
  
  # Track every object
  use Devel::LeakGuard::Object qw{ GLOBAL_bless };

=head1 DESCRIPTION

This module provides tracking of objects, for the purpose of
detecting memory leaks due to circular references or innappropriate
caching schemes.

Object tracking can be enabled on a per object basis. Any objects thus
tracked are remembered until DESTROYed; details of any objects left are
printed out to stderr at END-time.

  use Devel::LeakGuard::Object qw( GLOBAL_bless );

This form overloads B<bless> to track construction and destruction of
all objects. As an alternative, by importing bless, you can just track
the objects of the caller code that is doing the use.

If you use GLOBAL_bless to overload the bless function, please note that
it will ONLY apply to bless for modules loaded AFTER
Devel::LeakGuard::Object has enabled the hook.

Any modules already loaded will have already bound to CORE::bless and
will not be impacted.

=cut

{
  my $magic = 0;

  my $plain_bless = sub {
    my $ref = shift;
    my $class = @_ ? shift : scalar caller;
    return CORE::bless( $ref, $class );
  };

  my $magic_bless = sub {
    my $ref    = shift;
    my $class  = @_ ? shift : scalar caller;
    my $object = CORE::bless( $ref, $class );
    unless ( $class->isa( 'Devel::LeakGuard::Object::State' ) ) {
      Devel::LeakGuard::Object::track( $object );
    }
    return $object;
  };

  sub import {
    my $class  = shift;
    my @args   = @_;
    my @import = ();

    unless ( *CORE::GLOBAL::bless eq $plain_bless ) {
      # We don't actually need to install our version of bless here but
      # it'd be nice if any problems that it caused showed up sooner
      # rather than later.
      local $SIG{__WARN__} = sub {
        warn "It looks as if something else is already "
         . "overloading bless; there may be troubles ahead";
      };
      *CORE::GLOBAL::bless = $plain_bless;
    }

    for my $a ( @args ) {
      if ( 'GLOBAL_bless' eq $a ) {
        adj_magic( 1 );
      }
      elsif ( $a =~ /^:(.+)$/ ) {
        croak "Bad option: $1" unless exists $OPTIONS{$1};
        $OPTIONS{$1}++;
      }
      else {
        push @import, $a;
      }
    }

    return __PACKAGE__->export_to_level( 1, $class, @import );
  }

  sub adj_magic {
    my $adj       = shift;
    my $old_magic = $magic;
    $magic = 0 if ( $magic += $adj ) < 0;
    {
      no warnings 'redefine';
      if ( $old_magic > 0 && $magic == 0 ) {
        *CORE::GLOBAL::bless = $plain_bless;
      }
      elsif ( $old_magic == 0 && $magic > 0 ) {
        *CORE::GLOBAL::bless = $magic_bless;
      }
    }
  }
}

=head2 C<< leakguard >>

=cut

sub leakguard(&@) {
  my $block    = shift;
  my $state    = Devel::LeakGuard::Object::State->new( @_ );
  my $rc       = $block->();
  my ( undef ) = ( $state );
  return $rc;
}

=head2 C<< state >>

=cut

sub state { return {%OBJECT_COUNT} }

=head2 C<< track >>

=cut

sub track {
  my $object = shift;
  my $class  = blessed $object;

  carp "Devel::LeakGuard::Object::track was passed a non-object"
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

    *{"${class}::DESTROY"} = _mk_destroy( $class );

    _mk_next( $class );
  }

  $OBJECT_COUNT{ $TRACKED{$address} }++;
}

sub _mk_destroy {
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
    _mk_next( $original );
    my $super = $DESTROY_NEXT{$original}{$pkg};
    goto &{"${super}::DESTROY"} if $super;
    return;
  };
}

sub _mk_next {
  my $class = shift;

  no strict 'refs';
  return if $DESTROY_NEXT{$class};

  $DESTROY_NEXT{$class} = {};

  my @stack = ( $class );
  my %seen  = ( UNIVERSAL => 1 );
  my @queue = ();

  while ( my $c = pop @stack ) {
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

    push @stack, reverse @{"${c}::ISA"};
  }

  $DESTROY_NEXT{$class}{$_} = '' for @queue;
}

sub status {
  my $fh = $OPTIONS{stderr} ? *STDERR : *STDOUT;
  print $fh "Tracked objects by class:\n";
  for ( sort keys %OBJECT_COUNT ) {
    next unless $OBJECT_COUNT{$_};    # Don't list class with count zero
    print $fh sprintf "%-40s %d\n", $_, $OBJECT_COUNT{$_};
  }
}

END { status() if $OPTIONS{at_end} }

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

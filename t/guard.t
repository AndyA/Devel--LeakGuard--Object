#!perl

use strict;
use warnings;

use Data::Dumper;
use Test::Differences;
use Test::More tests => 6;

use Devel::LeakGuard::Object::State;
use Devel::LeakGuard::Object qw( leakguard );

package Foo;

use strict;
use warnings;

sub new {
  my ( $class, $name ) = @_;
  #  my ( $pkg, $file, $line ) = caller;
  #  print "new $class($name) at $file, $line\n";
  return bless { name => $name }, $class;
}

#sub DESTROY {
#  my $self = shift;
#  my ( $pkg, $file, $line ) = caller;
#  print "DESTROY ", ref $self, "($self->{name}) at $file, $line\n";
#  $self->{name} .= ' [destroyed]';
#}

package Bar;

our @ISA = qw( Foo );

package main;

{
  eval 'leakguard {}';
  ok !$@, 'no error from bare leakguard' or diag $@;
}

{
  my $leaks = {};
  my $foo1  = Foo->new( '1foo1' );
  my $bar1  = Bar->new( '1bar1' );

  leakguard {
    my $foo2 = Foo->new( '1foo2' );
  }
  on_leak => sub { $leaks = shift };

  eq_or_diff $leaks, {}, 'no leaks';
}

{
  my $leaks = {};
  my $foo1  = Foo->new( '2foo1' );
  my $bar1  = Bar->new( '2bar1' );

  leakguard {
    my $foo2 = Foo->new( '2foo2' );
    $foo2->{me} = $foo2;
  }
  on_leak => sub { $leaks = shift };

  eq_or_diff $leaks, { Foo => [ 0, 1 ] }, 'leaks';
}

{
  my @w = ();
  local $SIG{__WARN__} = sub { push @w, @_ };
  leakguard {
    my $foo1 = Foo->new( '3foo1' );
    $foo1->{me} = $foo1;
  };
  s/line \d+/line #/g for @w;
  eq_or_diff [@w],
   [   "Object leaks found:\n"
     . "  Class Before  After  Delta\n"
     . "  Foo        1      2      1\n"
     . "Detected at t/guard.t line #\n"
     . "" ], 'implicit warn';
}

{
  my @w = ();
  local $SIG{__WARN__} = sub { push @w, @_ };
  leakguard {
    my $foo1 = Foo->new( '4foo1' );
    $foo1->{me} = $foo1;
  }
  on_leak => 'warn';
  s/line \d+/line #/g for @w;
  eq_or_diff [@w],
   [   "Object leaks found:\n"
     . "  Class Before  After  Delta\n"
     . "  Foo        2      3      1\n"
     . "Detected at t/guard.t line #\n"
     . "" ], 'explicit warn';
}

{
  my @w = ();
  local $SIG{__DIE__} = sub { push @w, @_ };
  eval {
    leakguard {
      my $foo1 = Foo->new( '5foo1' );
      $foo1->{me} = $foo1;
    }
    on_leak => 'die';
  };
  s/line \d+/line #/g for @w;
  eq_or_diff [@w],
   [   "Object leaks found:\n"
     . "  Class Before  After  Delta\n"
     . "  Foo        3      4      1\n"
     . "Detected at t/guard.t line #\n"
     . "" ], 'die';
}

# vim:ts=2:sw=2:et:ft=perl


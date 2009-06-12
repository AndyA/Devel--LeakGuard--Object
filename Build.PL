require 5.008;

use strict;
use warnings;

use lib 'inc';

use Module::Build;
use MyBuilder;

my $builder = MyBuilder->new(
  module_name          => 'Devel::LeakTrack::Object',
  license              => 'perl',
  dist_author          => 'Andy Armstrong <andy@hexten.net>',
  dist_version_from    => 'lib/Devel/LeakTrack/Object.pm',
  recursive_test_files => 1,
  requires             => {
    'Scalar::Util' => '1.19',
    'Test::More'   => '0.42',
  },
  add_to_cleanup => ['Devel-LeakTrack-Object-*'],
);

$builder->create_build_script();

# manifest.t
use strict;
use warnings FATAL => 'all';
use Test::More;

unless ($ENV{TEST_AUTHOR}) {
  plan(skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.');
}

require ExtUtils::Manifest;
is_deeply [ExtUtils::Manifest::manicheck()], [], 'missing';
is_deeply [ExtUtils::Manifest::filecheck()], [], 'extra';

done_testing();

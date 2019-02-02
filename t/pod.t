#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More;

unless ($ENV{TEST_AUTHOR}) {
  plan(skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.');
}

# Ensure a recent version of Test::Pod
my $min_tp = 1.48;
eval "use Test::Pod $min_tp";
plan skip_all => "Test::Pod $min_tp required for testing POD" if $@;

all_pod_files_ok();

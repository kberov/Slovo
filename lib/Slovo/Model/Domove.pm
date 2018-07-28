package Slovo::Model::Domove;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
my $table = 'domove';
has table => $table;
has 'dbx';

1;

package Slovo::Model;
use Mojo::Base -base, -signatures;

has 'dbx';
has c => sub { Slovo::Controller->new() };
sub table { Carp::croak 'Method not implemented' }
1;

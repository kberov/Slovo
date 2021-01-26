package Slovo::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

has not_found_id   => sub { $_[0]->stranici->not_found_id };
has not_found_code => 404;

has description => 'Slovo is a simple extensible CMS.';
has keywords    => 'SSOT, CRM, ERP, CMS, Perl, Mojolicious, SQL';

sub generator { return 'Slovo ' . $Slovo::VERSION . ' - ' . $Slovo::CODENAME }


1;

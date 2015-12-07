use Test;
use Pod::To::HTML;
plan 1;
my $r;

=begin pod
=for comment
foo foo not rendered
bla bla    bla

This isn't a comment
=end pod

$r = node2html $=pod[0];
ok $r ~~ ms/ ^ '<p>' 'This isn&#39;t a comment' '</p>' $ /;

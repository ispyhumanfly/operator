use Test;
use Pod::To::HTML;
plan 3;
my $r;

=begin pod
The seven suspects are:

=item  Happy
=item  Dopey
=item  Sleepy
=item  Bashful
=item  Sneezy
=item  Grumpy
=item  Keyser Soze
=end pod

$r = pod2html $=pod[0];
ok $r ~~ ms[[
    '<p>' 'The seven suspects are:' '</p>'
    '<ul>'
        '<li>' '<p>' Happy '</p>' '</li>'
        '<li>' '<p>' Dopey '</p>' '</li>'
        '<li>' '<p>' Sleepy '</p>' '</li>'
        '<li>' '<p>' Bashful '</p>' '</li>'
        '<li>' '<p>' Sneezy '</p>' '</li>'
        '<li>' '<p>' Grumpy '</p>' '</li>'
        '<li>' '<p>' Keyser Soze '</p>' '</li>'
    '</ul>'
]];

=begin pod
=item1  Animal
=item2     Vertebrate
=item2     Invertebrate

=item1  Phase
=item2     Solid
=item2     Liquid
=item2     Gas
=item2     Chocolate
=end pod

$r = pod2html $=pod[1];
ok $r ~~ ms[[
    '<ul>'
        '<li>' '<p>' Animal '</p>' '</li>'
        '<ul>'
            '<li>' '<p>' Vertebrate '</p>' '</li>'
            '<li>' '<p>' Invertebrate '</p>' '</li>'
        '</ul>'
        '<li>' '<p>' Phase '</p>' '</li>'
        '<ul>'
            '<li>' '<p>' Solid '</p>' '</li>'
            '<li>' '<p>' Liquid '</p>' '</li>'
            '<li>' '<p>' Gas '</p>' '</li>'
            '<li>' '<p>' Chocolate '</p>' '</li>'
        '</ul>'
    '</ul>'
]];

=begin pod
=comment CORRECT...
=begin item1
The choices are:
=end item1
=item2 Liberty
=item2 Death
=item2 Beer
=end pod

$r = pod2html $=pod[2];
ok $r ~~ ms[[
    '<ul>'
        '<li>' '<p>' 'The choices are:' '</p>' '</li>'
        '<ul>'
            '<li>' '<p>' Liberty '</p>' '</li>'
            '<li>' '<p>' Death '</p>' '</li>'
            '<li>' '<p>' Beer '</p>' '</li>'
        '</ul>'
    '</ul>'
]];

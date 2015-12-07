use Test;
use Pod::To::HTML;
plan 3;
my $r;

=begin pod
This ordinary paragraph introduces a code block:

    $this = 1 * code('block');
    $which.is_specified(:by<indenting>);
=end pod

$r = node2html $=pod[0];
ok $r ~~ ms[[
    '<p>' 'This ordinary paragraph introduces a code block:' '</p>'
    '<pre>$this = 1 * code(&#39;block&#39;);'
'$which.is_specified(:by&lt;indenting&gt;);</pre>']];

=begin pod
This is an ordinary paragraph

    While this is not
    This is a code block

    =head1 Mumble mumble

    Suprisingly, this is not a code block
        (with fancy indentation too)

But this is just a text. Again

=end pod

$r = node2html $=pod[1];
ok $r ~~ ms[['<p>' 'This is an ordinary paragraph' '</p>'
'<pre>While this is not'
'This is a code block</pre>'
'<h1 id="Mumble_mumble">' '<a class="u" href="#___top" title="go to top of document">'
    'Mumble mumble'
'</a>' '</h1>'
'<p>' 'Suprisingly, this is not a code block (with fancy indentation too)' '</p>'
'<p>' 'But this is just a text. Again' '</p>']];

my %*POD2HTML-CALLBACKS = code => sub (:$node, :&default) {
    ok $node.contents ~~ /:i code/, 'Callback called';
}

say $=pod[0].perl;
pod2html $=pod[0];

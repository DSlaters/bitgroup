#!/usr/bin/perl
# {{perl}}
# A snipit for reading/writing nodal XML files
# - It can handle:		Attributes, Mixed content
# - It cannot handle:	Badly formed XML, CDATA sections
use strict;

# The XML is parse into a tree
# - each node in the tree is a hash of attributes plus -name and -content keys
# - each -content value is a ref to a list of ordered nodes/texts
# - only one root is allowed
sub xmlParse {
	
	# First convert XML into a list split at every tag, ie. <tag> </tag> or <tag/>
	# - Each tag is five list items (first /, name, atts, second /, text between this and next)
	@_ = shift =~ /<\s*(\/?)([-a-z0-9_:]+)\s*(.*?)\s*(\/)?>\s*(.*?)\s*(?=<|$)/gi;
	
	# Loop through all the tags and compile them into a tree
	my $ptr = my $root = {};
	my @path = ();
	while ( $#_ >= 0 ) {
		my ( $close, $name, $atts, $leaf, $text ) = ( shift, shift, shift, shift, shift );
		# Create a new node in the current content and update ptr if <tag/> or <tag>
		# - Includes hash of atts: /PATTERN/g returns a key,val list which can be treated as a hash
		unless ($close) {
			my $node = { -name => $name, $atts =~ /([-a-z0-9_:]+)\s*=\s*"(.*?)"/gi };
			push @{$$ptr{-content}}, $node;       # Push the node onto the current content list
			push @path, $ptr;                       # Move current focus into the new node
			$ptr = $node;
		}
		$ptr = pop @path if $close or $leaf;        # Move ptr up one level is </tag> or <tag/>
		push @{$$ptr{-content}}, $text if $text;  # Add the after-node-content part to the current level
	}
	return $root;
}


# Construct XML text from passed hash tree
sub xmlBuild {
	my ($level, $ptr) = @_;
	my $indent;
	$indent .= '   ' for 1..$level;
	my $xml = '';
	my $name = $$ptr{-name};
	$xml .= "$indent$name" if $name;
	for ( @{$$ptr{-content}} ) { $xml .= ref eq 'HASH' ? "\n".xmlBuild( $level+1, $_ ) : " => $_\n" }
	return $xml;
}

return 1;

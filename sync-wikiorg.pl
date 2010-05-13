#!/usr/bin/perl
#
# Synchronise the wiki-organisation content from one wiki to another
# - src and dst defined in wikid.conf by: $srcwiki, $srcuser, $srcpass, $dstwiki, $dstuser, $dstpass
# - if no src details are supplied, OD is used
#
require "wiki.pl";

$srcwiki = 'http://www.organicdesign.co.nz/wiki/index.php';
$srcuser = '';
$srcpass = '';

require "wikid.conf";

$srcdomain = $1 if $srcwiki =~ m|//(.+?)/|;
$comment = "Imported from $srcdomain by sync-wikiorg.pl";

wikiLogin( $srcwiki, $srcuser, $srcpass ) if $srcuser;
wikiLogin( $dstwiki, $dstuser, $dstpass ) if $dstuser;

# The DPL queries which select all the wiki organisation articles
# - does not select record instances
$query = "
	{{#dpl:namespace=Form}}
	{{#dpl:uses=Template:Portal}}
	{{#dpl:category=Records}}
	{{#dpl:category=RecordAdmin}}
	{{#dpl:category=Symbols}}
	{{#dpl:category=Formatting templates}}
	{{#dpl:category=Organisational templates}}
";

$query = "{{#dpl:category=Icons}}";

# Get the list of titles from the DPL queries
@titles = wikiParse( $srcwiki, $query, 1 );

# Ensure the list exhibits only unique titles
%tmp = ();
$tmp{$_} = 1 for @titles;
@titles = sort keys %tmp;

# Copy the titles from source wiki to destination wiki
for $title ( @titles ) {
	$text = wikiRawPage( $srcwiki, $title );
	if ( $title =~ /^(Image|File):(.+)$/ ) {

		# Get the URL of the image


		# Title is an image (not finished)
		wikiUploadFile( $wiki, $sourcefile, $destname, $summary );

	} else {

		# Title is a normal article
		wikiEdit( $dstwiki, $title, $text, $comment );

	}
}

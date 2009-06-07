#!/usr/bin/perl
use HTTP::Request;
use LWP::UserAgent;

$client = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0',
	from       => 'export-images.pl@organicdesign.co.nz',
	timeout    => 10,
);

$wiki = $ARGV[0];

$dir = $wiki =~ /(https?:\/\/(.+?))\// ? $2 : die "Please supply long form wiki URL";
$base = $1;
$content = $client->get("$wiki?title=Special:Imagelist&limit=500")->content;
@files = $content =~ /href\s*=\s*['"](\/[^'"]+?\/.\/..\/[^'"]+?)['"]/g;

mkdir $dir;
for $url (@files) {
	$file = $url =~ /.+\/(.+?)$/ ? $1 : die "Bad name ($url)";
	print "$file\n";
	open FH, '>', "$dir/$file";
	binmode FH;
	print FH $client->get("$base$url")->content;
	close FH;
}

use threads;
use Net::SMTP;
$n = 3;

@threads = ();
push( @threads, threads->new( \&send ) ) for ( 1 .. $n );
sleep( 3 );
$_->join for @threads;

sub send {
	$thread = threads->tid();
	$to   = "thread$thread\@bar.com";
	$from = "thread$thread\@foo.com";
	$smtp = Net::SMTP->new( '127.0.0.1:2525' );
	$smtp->mail( $from );
	$smtp->to( $to );
	$smtp->data();
	$smtp->datasend( "To: $to\n" );
	$smtp->datasend( "From: $from\n" );
	$smtp->datasend( "\n" );
	$smtp->datasend( "[Thread$thread] Line $_: Hello, World!\n" ) for ( 1 .. 20 );
	$smtp->dataend();
	$smtp->quit;
}

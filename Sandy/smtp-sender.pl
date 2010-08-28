use threads;
use Net::SMTP;

# Send message from 3 threads simultaneously
threads->new( \&send ) for ( 1 .. 3 );

# Send a 20 line message to the local a SMTP server on port 2525
sub send {
	threads->detach;
	$tid  = threads->tid();
	$to   = "thread$thread\@bar.com";
	$from = "thread$thread\@foo.com";
	$smtp = Net::SMTP->new( '127.0.0.1:2525' );
	$smtp->mail( $from );
	$smtp->to( $to );
	$smtp->data();
	$smtp->datasend( "To: $to\n" );
	$smtp->datasend( "From: $from\n" );
	$smtp->datasend( "\n" );
	$smtp->datasend( "[Thread$tid] Line $_: Hello, World!\n" ) for ( 1 .. 20 );
	$smtp->dataend();
	$smtp->quit;
}

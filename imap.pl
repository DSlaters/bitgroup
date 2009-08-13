#!/usr/bin/perl
    use Net::IMAP::Simple::SSL;

    # open a connection to the IMAP server
    $server = new Net::IMAP::Simple::SSL( 'organicdesign.co.nz' );

    # login
    $server->login( 'nad', '***' );
    
    # select the desired folder
    $number_of_messages = $server->select( 'Inbox' );

    # go through all the messages in the selected folder
if(0) {
    foreach $msg ( 1..5 ) {

        if ( $server->seen( $msg ) ) {
            print "This message has been read before...\n"
        }

        # get the message, returned as a reference to an array of lines
        $lines = $server->get( $msg );

        # print it
        print @$lines;

        # get the message, returned as a temporary file handle
        $fh = $server->getfh( $msg );
        print <$fh>;
        close $fh;

    }
}
    # the list of all folders
    @folders = $server->mailboxes();
#	print "folders: @folders\n";

    # create a folder
    $server->create_mailbox( 'Contacts.newfolder' );

    # rename a folder
#    $server->rename_mailbox( 'newfolder', 'renamedfolder' );

    # delete a folder
#    $server->delete_mailbox( 'renamedfolder' );

    # copy a message to another folder
   print  $server->copy( 1, 'Contacts' );

    # close the connection
    $server->quit();

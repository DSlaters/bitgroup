#################################################
#                                               #
#     Configuration file for EmailToFile.pl     #
#                                               #
#################################################


# Name of service for starting/stopping etc
$::daemon = 'EmailToFile';

# One line description to show up in services list
$::description = 'MT4 Bot';

# Messages older than this many seconds will not be processed
$::maxage = 520000;

# Only read this many bytes from a message
$::maxsize = 4096;

# How many milliseconds the service should sleep between connections
$::sleep = 30000;

# Remove this or set to 0 to enable detection of already processed messages
$::last = -1;

# Definition of email sources to check
$::sources = {

	# Name/ID of first email data source
	TaiShinki => {

		# Email server connection details for "TaiShinki" data source
		proto   => 'IMAP',
		host    => 'imap.gmail.com',
		user    => 'test.taishinki@gmail.com',
		pass    => 'arantest',

		# Rule to capture MT4 alerts
		MT4Alert => {

			rules => {
				subject => 'MT4 alert',
				content => '^\s*(\w+ \w+).+?:\s*([A-Z]{6}\.?)\s*,\s*(\d+)'
			},

			format => '2,$content2,$content3,$content1',
			file   => '/var/www/trigger$1.txt'
		},

		# Rule to capture ChartSetup's with (buy/sell)
		ChartSetup1 => {

			rules => {
				subject => 'MT4 chart setup',
				content => '^\s*([A-Z]{6}\.?)\s*,\s*([MHD]\d+)\s*:\s*(.+?)\s+\(?((s)ell|(b)uy)\)?\s*$'
			},

			format => '1,$content1,$content2,$content3,$content5$content6',
			file   => '/var/www/trigger$1.txt'
		},

		# Rule to capture ChartSetup's without (buy/sell)
		ChartSetup2 => {

			rules => {
				subject => 'MT4 chart setup',
				content => '^\s*([A-Z]{6}\.?)\s*,\s*([MHD]\d+)\s*:\s*([^(]+?)\s*$'
			},

			format => '1,$content1,$content2,$content3,',
			file   => '/var/www/trigger$1.txt'
		}

	}

}

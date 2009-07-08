#!/usr/bin/perl
# - based on wiki.pl{{perl}}{{Category:Robots}}
# - Licenced under LGPL (http://www.gnu.org/copyleft/lesser.html)
# - Authors: [http://www.organicdesign.co.nz/Nad Nad], [http://www.organicdesign.co.nz/Sven Sven]
# - Source: http://www.organicdesign.co.nz/wiki.pl
# - Started: 2008-03-16
# - Updated: 2009-02-27
# - Tested versions: 1.6.10, 1.8.4, 1.9.3, 1.10.2, 1.11.0, 1.12.rc1, 1.13.2, 1.14.0
# http://www.mediawiki.org/wiki/Manual:Parameters_to_index.php#What_to_do
# - Provides details on required name fields in forms

# NOTES REGARDING CHANGING TO PERL PACKAGE AND ADDING API SUPPORT
# - constructor:
#   - login
#   - get wiki version and whether to use HTML or API
#   - get namespaces
#   - get messages used in patterns (and make methods use messages in their regexp's so lang-independent)

$::wikipl_version = '1.9.0'; # 2009-05-30

use HTTP::Request;
use LWP::UserAgent;
use POSIX qw(strftime);

sub wikiLogin;
sub wikiLogout;
sub wikiEdit;
sub wikiAppend;
sub wikiLastEdit;
sub wikiRawPage;
sub wikiStructuredPage;
sub wikiGetVersion;
sub wikiGetNamespaces;
sub wikiGetList;
sub wikiDelete;
sub wikiRestore;
sub wikiUploadFile;
sub wikiDeleteFile;
sub wikiDownloadFile;
sub wikiDownloadFiles;
sub wikiProtect;
sub wikiUpdateTemplate;
sub wikiMove;
sub wikiExamineBraces;
sub wikiGuid;

# Set up a global client for making HTTP requests as a browser
$::client = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.8.1.14)',
	from       => 'wiki.pl@organicdesign.co.nz',
	timeout    => 10,
	max_size   => 100000
);

sub logAdd {
	my $entry = shift;
	if ( $::log ) {
		open LOGH, '>>', $::log or die "Can't open $::log for writing!";
		print LOGH localtime()." : $entry\n"; close LOGH;
	} else { print STDERR "$entry\n" }
	return $entry;
}

sub logHash {
	my $href = shift;
	while(($key, $value) = each %$href) {
		print STDERR "$key => $value\n";
	}
}

# Login to a MediaWiki
# todo: check if logged in first
sub wikiLogin {
	my ($wiki, $user, $pass, $domain) = @_;
	my $url = "$wiki?title=Special:Userlogin";
	my $success = 0;
	my $retries = 1;
	while ($retries--) {
		my $html = '';
		if ($::client->get($url)->is_success) {
			my %form = (wpName => $user, wpPassword => $pass, wpDomain => $domain, wpLoginattempt => 'Log in', wpRemember => '1');
			my $response = $::client->post("$url&action=submitlogin&type=login", \%form);
			$html = $response->content;
			$success = $response->is_redirect || ($response->is_success && $html =~ /You are now logged in/);
		}
		if ($success) {
			logAdd "$user successfully logged in to $wiki.";
			$retries = 0;
		}
		else {
			if ($html =~ /<div class="errorbox">\s*(<h2>.+?<\/h2>\s*)?(.+?)\s*<\/div>/is) { logAdd "ERROR: $2" }
			else { logAdd "ERROR: couldn't log $user in to $wiki!" }
		}
	}
	return $success;
}

# Logout of a MediaWiki
sub wikiLogout {
	my $wiki = shift;
	my $success = $::client->get("$wiki?title=Special:Userlogout")->is_success;
	logAdd $success
		? "Successfully logged out of $wiki."
		: "WARNING: couldn't log out of $wiki!";
	return $success;
}

# Edit a MediaWiki page
# todo: don't return success if edited succeeded but made no changes
sub wikiEdit {
	my ($wiki, $title, $content, $comment, $minor) = @_;
	logAdd "Attempting to edit \"$title\" on $wiki";
	my $success = 0;
	my $err = 'ERROR';
	my $retries = 1;

	while ($retries--) {
	    my @matches;
		# Request the page for editing and extract the edit-token
		my $response = $::client->get("$wiki?title=$title&action=edit");
			if ($response->is_success and (
			$response->content =~ m|<input type='hidden' value="(.+?)" name="wpEditToken" />|g
			)) {

			# Got token etc, now submit an edit-form
			my %form = (
				wpEditToken => $1,
				wpTextbox1  => $content,
				wpSummary   => $comment,
				wpSave      => 'Save page'
			);
			$form{wpMinoredit} = 1 if $minor;

			my $tokens = @{[$response->content =~ m|(<input type='hidden'.+type="hidden" value=".*?" />)|gs]};

			# Grabbing fields separately as hidden input order may vary in global regex
			$response->content =~ m|<input type='hidden' value="(.*?)" name="wpSection" />|     && ($form{wpSection} = $1);
			$response->content =~ m|<input type='hidden' value="(.*?)" name="wpStarttime" />|   && ($form{wpStarttime} = $1);
			$response->content =~ m|<input type='hidden' value="(.*?)" name="wpEdittime" />|    && ($form{wpEdittime} = $1);
			$response->content =~ m|<input name="wpAutoSummary" type="hidden" value="(.*?)" />| && ($form{wpAutoSummary} = $1);
			$response = $::client->post("$wiki?title=$title&action=submit", \%form);

			if ($response->content =~ /<!-- start content -->Someone else has changed this page/) {
				$err = 'EDIT CONFLICT';
				$retries = 0;
			} else { $success = !$response->is_error }
			} else { $err = $response->is_success ? 'MATCH FAILED' : 'RQST FAILED' }
		if ($success) { $retries = 0; logAdd "\"$title\" updated." }
		else { logAdd "$err: Couldn't edit \"$title\" on $wiki!\n" }
	}
	return $success;
}

# Append a wiki page
sub wikiAppend {
	my ($wiki,$title,$append,$comment) = @_;
	my $content = wikiRawPage($wiki,$title);
	$content = '' if $content eq '(There is currently no text in this page)';
	return wikiEdit($wiki,$title,$content.$append,$comment);
}

# Get the date of last edit of an article
sub wikiLastEdit {
	my($wiki,$title) = @_;
	# Request the last history entry and extract date
	my $response = $::client->request(HTTP::Request->new(GET => "$wiki?title=$title&action=history&limit=1"));
	return $1 if $response->is_success and $response->content =~ /<a.+?>(\d+:\d+.+?\d)<\/a>/;
}

# Retrieve the raw content of a page
sub wikiRawPage {
	my($wiki,$title,$expand) = @_;
	my $response = $::client->get("$wiki?title=$title&action=raw".($expand ? '&templates=expand' : ''));
	return $response->content if $response->is_success;
}

# Return a hash of sections, each containing text, lists, links and templates
# - if only one parameter supplied, then it's assumed to be the wikitext content to extract structure from
sub wikiStructuredPage {
	my($wiki,$title) = @_;
	$page = $title ? wikiRawPage($wiki, $title, 1) : $wiki;
	my %page = ();
	for (split /^=+\s*/m,$page) {
		/(.+?)\s*=+\s*(.+?)\s*/s;
		my($heading,$content) = ($1, $2);

		# todo: extract lists, links, templates from content

		# if heading, add a node and put content, lists, links in it, else put under root
		if ($1) {
			print "$1\n----\n";
		}
	}
	return %page;
}

# Returns mediawiki version string
sub wikiGetVersion {
	my $wiki = shift;
	my $response = $::client->get("$wiki?title=Special:Version&action=render");
	return $1 if $response->content =~ /MediaWiki.+?: ([0-9.]+[0x20-0x7e]+)/;
}

# Return a hash (number => name) of the wiki's namespaces
sub wikiGetNamespaces {
	my $wiki = shift;
	my $response = $::client->get("$wiki?title=Special:Allpages");
	$response->content =~ /<select id="namespace".+?>\s*(.+?)\s*<\/select>/s;
	return ($1 =~ /<option.*?value="([0-9]+)".*?>(.+?)<\/option>/gs, 0 => '');
}

# Returns hash (anchor => href) list elements in article content
sub wikiGetList {
	my( $wiki, $title ) = @_;
	my $response = $::client->get("$wiki?title=$title");
	$response->content =~ /<!-- start content -->(.+)<!-- end content -->/s;
	my $html = $1;
	my %list = $html =~ /<li>.*?<a.*?href="(.+?)".*?>(.+?)<\/a>\s*<\/li>/gs;
	my %tmp = (); # bugfix: swap keys/vals
	while (my($k, $v) = each %list) { $tmp{$v} = $k };
	return %tmp;
}

# Todo error checking on the type of failure, e.g. no user rights to delete
# Capture error if article already deleted
sub wikiDelete {
	my( $wiki, $title, $reason ) = @_;
	my $url = "$wiki?title=$title&action=delete";
	unless($reason) {
		$reason = "content was: \'$title\'";
	}
	my $success = 0;
	my $err = 'ERROR';
	my $retries = 1;
	while ($retries--) {
		my $html = '';
		my $response = $::client->get($url);
		if ($response->is_success && $response->content =~ m/<input name="wpEditToken".*? value="(.*?)".*?<\/form>/s) {
			my %form = (wpEditToken => $1, wpReason => $reason);
			$response = $::client->post($url, \%form);
			$html = $response->content;
			$success = $response->is_success && $html =~ /Action complete/;
		}
		if ($success) {
			logAdd "$user successfully deleted $title.";
			$retries = 0;
		}
		# Parser response to determine if user has sysop privileges
	}
	return $success;
}

# Todo logAdd the revision/all revisions
sub wikiRestore {
	my( $wiki, $title, $reason, $revision ) = @_;
	my $url = "$wiki?title=Special:Undelete";
	unless($reason) {
		$reason = "Restoring: \'$title\'";
	}
	my $success = 0;
	my $err = 'ERROR';
	my $retries = 1;
	while ($retries--) {
		my $html = '';
		my $response = $::client->get("$url&target=$title");
		if ($response->is_success && $response->content =~ m/<input name="wpEditToken".*? value="(.*?)".*?<\/form>/s) {
			my %form = (wpComment => $reason, target => $title, wpEditToken => $1, restore=>"Restore");
			my @timestamps = $response->content =~ m/<input .*?"(ts\d*?)".*?/g;

			# Restore specified $revision
			if ($revision) {
				if($#timestamps <($revision-1)) {
					$revision = $#timestamps;
					logAdd("Warning: \$revision specifed does not exist");
				}
				$form{$timestamps[$revision-1]} = 1;
			} else { @form{@timestamps} = (undef) x @timestamps }

			$response = $::client->post("$url&action=submit", \%form);
			$html     = $response->content;
			$success  = $response->is_success && $html =~ /has been restored/;
		}
		if ($success) {
			logAdd "$user successfully restored $title.";
			$retries = 0;
		}
		# Parser response to determine if user has sysop privileges
	}
	return $success;
}


# Upload a files into a wiki using its Special:Upload page
sub wikiUploadFile {
    my ($wiki, $sourcefile, $destname, $summary ) = @_;
    my $url = "$wiki?title=Special:Upload&action=submit";
    my $success = 0;
    my $err = 'ERROR';
    my $retries = 1;
    while ($retries--) {
		%form = (
			wpSourceType => 'file',
			wpDestFile   => $destname,
			wpUploadDescription => $summary,
			wpUpload     => "Upload file",
			wpDestFileWarningAck => '',
			wpUploadFile => [$sourcefile => $destname],
			wpWatchthis  => '0',
	    );
		my $response = $::client->post($url, \%form, Content_Type => 'form-data');
		$success = $response->is_success;

		# Check if file is already uploaded
		if ($success && $response->content =~ m/Upload warning.+?(A file with this name exists already|File name has been changed to)/s) {
			$response->content =~ m/<input type='hidden' name='wpSessionKey' value="(.+?)" \/>/;
			# Need to grab the wpSessionKey input field
			$form{'wpSessionKey'}         = $1;
			$form{'wpIgnoreWarning'}      = 'true';
			$form{'wpDestFileWarningAck'} = 1,
			$form{'wpLicense'}            = '';
			$form{'wpUpload'}             =  "Save file",
			$response = $::client->post("$url&action=submit", \%form, Content_Type => 'form-data');
			logAdd("Uploaded a new version of $destname");
		} else { logAdd("Uploaded $destname") }
	}
    return $success;
}


# Delete an uploaded file from a wiki
sub wikiDeleteFile {
	my ($wiki, $imagename, $comment) =@_;
	my $url = "$wiki?title=Image:$imagename&action=delete";
	my $success = 0;
	my $err = 'ERROR';
	my $retries = 1;
	while ($retries--) {
		my $response = $::client->get("$url");
			if ($response->is_success &&
				$response->content =~ m/Permission error.+?The action you have requested is limited to users in the group/s) {
				logAdd("Error: $user does not have the permissions to delete $imagename");
				return $success;
			}
			if ($response->is_success &&
				$response->content =~ m/Internal error.+?Could not delete the page or file specified/s) {
				logAdd("Error: Could not delete $imagename - already deleted?");
				return $success;
			}
			if ($response->is_success &&
				$response->content =~ m/Delete $imagename.+?<input.+?name="wpEditToken".+?value="(.*?)".+?Reason for deletion:/is) {
				%form = (
					wpEditToken            => $1,
					wpDeleteReasonList     => "other",
					wpReason               => $comment || "",
					'mw-filedelete-submit' => "Delete",
				);
				logAdd("Deleted Image:$imagename");
				$response = $::client->post("$url", \%form);

				my $html = $response->content;
				$success = $response->is_success && $html =~ /Action complete/;
			}
	}
	return $success;
}


# Download an uploaded file by name from a wiki to a local file
# - if no namespace is supplied with the source then "Image" is used
# - if no destination filename is specified, the image name is used
sub wikiDownloadFile {
	my ($wiki, $src, $dst) = @_;
	$src  =~ /^((.+?):)?(.+)$/;
	$src  = $1 ? "$2$src" : "Image:$src";
	$dst  = $dst ? $dst : $2;
	my $base = $wiki =~ /(https?:\/\/(.+?))\// ? $1 : return 0;
	my $page = $::client->get("$wiki?title=$src&action=render")->content;
	if (my $url = $page =~ /href\s*=\s*['"](\/[^"']+?\/.\/..\/[^'"]+?)["']/ ? $1 : 0) {
		my $file = $url =~ /.+\/(.+?)$/ ? $1 : die 'wiki-downloaded-file';
		logAdd("Downloading \"$src\"");
		open FH, '>', $file;
		binmode FH;
		print FH $::client->get("$base$url")->content;
		close FH;
	}
}


# Download all uploaded files from a wiki to a local directory
# - to a maximum of 500 images
sub wikiDownloadFiles {
	my ($wiki, $dir) = @_;
	$dir   = $wiki =~ /(https?:\/\/(.+?))\// ? $2 : 'wiki-downloaded-files';
	my $base  = $1;
	my $list  = $::client->get("$wiki?title=Special:Imagelist&limit=500")->content;
	my @files = $list =~ /href\s*=\s*['"](\/[^"']+?\/.\/..\/[^'"]+?)["']/g;

	mkdir $dir;
	for my $url (@files) {
		if (my $file = $url =~ /.+\/(.+?)$/ ? $1 : 0) {
			logAdd("Dwonloading \"$file\"");
			open FH, '>', "$dir/$file";
			binmode FH;
			print FH $::client->get("$base$url")->content;
			close FH;
		}
	}
}


# Change protection state of an article
# - relevant from 1.8+. From 1.12+ so may as well use API
# - see http://www.mediawiki.org/wiki/API:Edit_-_Protect
# - we need this working so that we can use a bot to change #security annotations to protection when SS4 ready
sub wikiProtect {
	# Standard way first, use API later with wikiGetVersion check
	 my (
		$wiki,
		$title,
		$comment ,
		$restrictions, # hashref of action=group pairs
		$expiry,       # optional expiry date string
		$cascade,      # optional boolean for cascading restrictions over transcluded articles
	) = @_;

	if (not $restrictions) { $restrictions = { "edit" => "", "move" => "" }	}

	# A list of defaults which could be used in usage logAdd reporting
	#	my $defaults = {
	#						"(default)"                => "",
	#						"block unregistered users" => "autoconfirmed",
	#						"Sysops only"              => "sysop"
	#					};

	my $url = "$wiki?title=$title&action=protect";
	my $success = 0;
	my $err = 'ERROR';
	my $retries = 1;
	while ($retries--) {
		my $response = $::client->get($url);
			if ($response->is_success and
				$response->content =~ m/Confirm protection.+?The action you have requested is limited to users in the group/s) {
				logAdd("$user does not have permission to protect $title");
				return($success);
			}
		if ($response->is_success and
			$response->content =~ m/Confirm protection.+?You may view and change the protection level here for the page/s) {
			# Same problem, post on line 392 doesn't return content
			$success = $response->is_success && $response->content =~ m/<input.+?name="wpEditToken".+?value="(.*?)"/s;

			%form = (
				"wpEditToken"       => $1,
				"mwProtect-expiry"  => $expiry   || "",
				"mwProtect-reason"  => $comment  || "",
			);

			$form{"mwProtect-level-$_"} = $restrictions->{$_} for keys %{$restrictions};
			# Allowing for cascade option
			if ($cascade && $restrictions->{'edit'} == "sysop") { $form{"mwProtect-cascade"} = 1 }
			$response = $::client->post($url, \%form);
			logAdd("Setting protect article permissions");
			logHash(\%form);
		}
	}
	return $success;
}

# Replace parameters in a template call using examineBraces
# (done) - allow for no param hash which would result in {{template}}
# - account for both templates or parser-functions, i.e. {{foo|args..}} or {{#foo:args...}}
# - allow for multiple templates of same name by matching first param, then second etc
#
# - e.g.
#   wikiUpdateTemplate( $wiki, $title, "#foo", { 'id' => 123, 'bar' => 'baz' } )
#
#   if two #foo calls exist, then only one having an "id" param equal to 123 would be updated
#   if two have such an id, then the comparison would resort to the second arg and so on
#   if this process cannot result in an unambiguous update it should fail with an error saying so
sub wikiUpdateTemplate {
	my (
		$wiki,
		$title,
		$template, # Name of template to update
		$params  , # hashref of param/value pairs to update the template with
		$ambig   , #
		$comment ,
		$minor
	) = @_;

	$success = 0;

	$template || ($template = "template");
	my $wtext = wikiRawPage($wiki, $title);

	# Use examine braces to get all content
	my @articleBraces = examineBraces($wtext);

	# Array of matches
	my @matches  = ();
	# Array of ambig braces
	my @brace    = ();
	my$templateParams;
	my $newparams;
	foreach (@articleBraces) {
		if ($_->{'NAME'} eq $template) {
			push(@matches, $_);
		}
	}

	if( scalar(@matches) < 1){return($success)}           # no braces of matching name
	elsif (scalar(@matches) == 1){
		$templateParams = substr($wtext, $matches->[0]->{'OFFSET'}, $matches->[0]->{'LENGTH'});
		push(@brace, $matches[0]);
	}   												  # single match
	else{ 												  # ambiguous
		if(ref($params) !="HASH" || scalar(%$params)< 1){ # no params
			return ($success);
		}
		# Check $ambig is in instances of $template
			my $ambkey = (keys %{$ambig})[0];
			my $ambvalue = $ambig->{$ambkey};
			foreach(@matches) {

				$templateParams = substr($wtext, $_->{'OFFSET'}, $_->{'LENGTH'});
				if($templateParams =~ m/$ambkey\s*=\s*$ambvalue/g) {
					push(@brace, $_);
				}
			}

			if (scalar @brace > 1){ # None found
				logAdd("Aborting ambiguous parameter match found");
				return $success;
			} else {
				# Update with new parameters
				$newparams="{{$brace[0]->{'NAME'}";
				my $isparser = ($brace[0]->{'NAME'} =~ /:$/);
				my $sep= ($isparser ? "" : "|");
				foreach( keys %$params) {
					($newparams .= "${sep}$_=$params->{$_}");
					if($isparser) {
						$sep = "|";
						$isparser = 0;
					}
				}
				$newparams.="}}";
			}
			# Update template content in article - this is NOT WORKING!
			substr($wtext, $brace[0]->{'OFFSET'}, $brace[0]->{'LENGTH'}, $newparams);
			$success = wikiEdit($wiki, $title, $wtext, $comment, $minor);
	}
	return $success;
}

# Using Special:Movepage/article
# wpNewTitle
# wpMovetalk (logical checkbox)
# wpMove (action=submit)
sub wikiMove {
	my ($wiki, $oldname, $newname, $reason, $movetalk) = @_;
	my $url = "$wiki?title=Special:Movepage&target=$oldname";
	logAdd("URL=>$url");
	my $success = 0;
	my $err = 'ERROR';
	my $retries = 1;
	while ($retries--) {
		my $response = $::client->get($url);

		# Todo: Need to catch output where user does not have move privileges

		# Permissions Errors
		#You must be a registered user and logged in to move a page

		# Special:Movepage seems to move any non-existent page then throw the message after posting;
		# This action cannot be performed on this page
		# <input type="hidden" value="095485e50db577baa80c407d0e032e43+\" name="wpEditToken"/>
		#### Interesting 'value' and 'name' can be reversed, and single or double quoted

		if ($response->is_success && $response->content =~ m/<h1 class="firstHeading">Permissions Errors<\/h1>/) {
			logAdd("User $user does not have permissions to move $oldname");
			return 0;
		}

		if ($response->is_success && $response->content =~ m/<h1 class="firstHeading">Move page<\/h1>/) {
			$success = $response->is_success;
			$response->content =~ m/<input.+?name=['"]wpEditToken["'].+?value=['"](.*?)["']/s;
			%form = (
				wpEditToken   => $1,
				wpNewTitle    => $newname,
				wpReason      => $reason   || "",
				wpMovetalk    => $movetalk || ""
			);
			$response = $::client->post("$url&action=submit", \%form);
			logAdd("Moving $oldname to $newname");
		}
	}
	return $success;
}

# Return information on brace-structure in passed wikitext
# - see http://www.organicdesign.co.nz/MediaWiki_code_snippets
sub wikiExamineBraces {
	my $content = shift;
	my @braces  = ();
	my @depths  = ();
	my $depth   = 0;
	while ($content =~ m/\G.*?(\{\{\s*([#a-z0-9_]*:?)|\}\})/sig) {
		my $offset = pos($content)-length($2)-2;
		if ($1 eq '}}') {
			$brace = $braces[$depths[$depth-1]];
			$$brace{LENGTH} = $offset-$$brace{OFFSET}+2;
			$$brace{DEPTH}  = $depth--;
		} else {
			push @braces, { NAME => $2, OFFSET => $offset };
			$depths[$depth++] = $#braces;
		}
	}
	return @braces;
}

# Create a GUID article title compatible with the RecordAdmin extension
sub wikiGuid {
	$guid = strftime('%Y%m%d', localtime).'-';
	$guid .= chr( rand() < .72 ? int(rand(26)+65) : int(rand(10)+48) ) for 1..5;
	return $guid;
}
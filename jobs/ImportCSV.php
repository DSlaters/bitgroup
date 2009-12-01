<?php
/**
 * Adds MediaWiki hooks handling ImportCSV form
 */
if ( !defined( 'MEDIAWIKI' ) ) die( 'Not an entry point.' );

$wgImportCSVDataDir = dirname( __FILE__ ) . '/data';

$wgHooks['WikidAdminTypeFormRender_ImportCSV'][] = 'wfImportCSV_Render';
$wgHooks['WikidAdminTypeFormProcess_ImportCSV'][] = 'wfImportCSV_Process';

/**
 * Render a form in Special:WikidAdmin for the AAPImport type
 */
function wfImportCSV_Render( &$html ) {
	global $wgImportCSVDataDir;
	$html = 'Title format: <input name="format" /><br />';
	$html .= 'Template name: <input name="template" /><br />';
	$html .= 'Use an existing file: <select name="file"><option />';
	foreach ( glob( "$wgImportCSVDataDir/*" ) as $file ) $html .= '<option>' . basename( $file ) . '</option>';
	$html .= '</select><br />Or upload a new file:<br /><input name="upload" type="file" />';
	return true;
}

/**
 * Process posted data from ImportCSV form
 */
function wfImportCSV_Process( &$job, &$start ) {
	global $wgImportCSVDataDir, $wgRequest, $wgSiteNotice;
	$job['template'] = $wgRequest->getText( 'template' );
	$job['title'] = $wgRequest->getText( 'format' );

	# Handle upload if one specified, otherwise use existing one (if specified)
	if ( $target = basename( $_FILES['upload']['name'] ) ) {
		$job['file'] = "$wgImportCSVDataDir/$target"; 
		if ( file_exists( $job['file'] ) ) unlink( $job['file'] );
		if ( move_uploaded_file( $_FILES['upload']['tmp_name'], $job['file'] ) ) {
			$wgSiteNotice = "<div class='successbox'>File \"$target\" uploaded successfully</div>";
		} else $wgSiteNotice = "<div class='errorbox'>File \"$target\" was not uploaded for some reason :-(</div>";
	} else $job['file'] = $wgImportCSVDataDir . '/' . $wgRequest->getText('file');

	# Start the job if a valid file was specified, error if not
	if ( !$start = is_file( $job['file'] ) ) $wgSiteNotice = "<div class='errorbox'>No valid file specified, job not started!</div>";

	if ( $wgSiteNotice ) $wgSiteNotice .= "<div style='clear:both'></div>";

	return true;
}

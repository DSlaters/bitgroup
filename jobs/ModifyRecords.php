<?php
/**
 * Adds MediaWiki hooks handling ModifyRecords form
 */
if ( !defined( 'MEDIAWIKI' ) ) die( 'Not an entry point.' );

$wgHooks['WikidAdminTypeFormRender_ImportCSV'][] = 'wfImportCSV_Render';
$wgHooks['WikidAdminTypeFormProcess_ImportCSV'][] = 'wfImportCSV_Process';

/**
 * Render a form in Special:WikidAdmin for the AAPImport type
 */
function wfModifyRecords_Render( &$html ) {
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
function wfModifyRecords_Process( &$job, &$start ) {
	global $wgRequest, $wgSiteNotice;
	$job['template'] = $wgRequest->getText( 'template' );
	$job['title'] = $wgRequest->getText( 'format' );

	# Start the job if a valid file was specified, error if not
	if ( !$start = is_file( $job['file'] ) ) $wgSiteNotice = "<div class='errorbox'>No valid file specified, job not started!</div>";

	if ( $wgSiteNotice ) $wgSiteNotice .= "<div style='clear:both'></div>";

	return true;
}

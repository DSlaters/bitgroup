<?php
/**
 * Adds MediaWiki hooks handling ModifyRecords form
 */
if ( !defined( 'MEDIAWIKI' ) ) die( 'Not an entry point.' );

$wgHooks['WikidAdminTypeFormRender_ModifyRecords'][] = 'wfModifyRecords_Render';
$wgHooks['WikidAdminTypeFormProcess_ModifyRecords'][] = 'wfModifyRecords_Process';

/**
 * Render a form in Special:WikidAdmin for the AAPImport type
 */
function wfModifyRecords_Render( &$html ) {
	$html = '<table>';
	$html .= '<tr><td>Action:</td><td><select name="wpChangeType">';
	$html .= '<option value="name">Change a record name and all values referencing it</option>';
	$html .= '<option value="name">Change all occurences of a particular value</option>';
	$html .= '<option value="name">Change a field name and all references to it</option>';
	$html .= '<option value="name">Change the name of a record type and all references to it</option>';
	$html .= '</select></td></tr>';
	$html .= '<tr><td>From:</td><td><input name="wpFrom" /></td></tr>';
	$html .= '<tr><td>To:</td><td><input name="wpTo" /></td></tr>';
	$html .= '</table>';
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

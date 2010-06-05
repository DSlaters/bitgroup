<?php
/**
 * Adds MediaWiki hooks for handling custom form for the ModifyRecords job type
 *
 * Copyright (C) 2007-2010 Aran Dunkley and others
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 * http://www.gnu.org/copyleft/gpl.html
 *
 */
if ( !defined( 'MEDIAWIKI' ) ) die( 'Not an entry point.' );


/**
 * Render the form
 */
$wgHooks['WikidAdminTypeFormRender_ModifyRecords'][] = 'wfModifyRecords_Render';
function wfModifyRecords_Render( &$html ) {
	$html = '<table>';
	$html .= '<tr><td>Action:</td><td><select name="wpChangeType">';
	$html .= '<option value="record">Change a record name and all values referencing it</option>';
	$html .= '<option value="value">Change all occurences of a particular value</option>';
	$html .= '<option value="field">Change a field name and all references to it</option>';
	$html .= '<option value="type">Change the name of a record type and all references to it</option>';
	$html .= '</select></td></tr>';
	$html .= '<tr><td>From:</td><td><input name="wpFrom" /></td></tr>';
	$html .= '<tr><td>To:</td><td><input name="wpTo" /></td></tr>';
	$html .= '</table>';
	return true;
}

/**
 * Process submitted form
 */
$wgHooks['WikidAdminTypeFormProcess_ModifyRecords'][] = 'wfModifyRecords_Process';
function wfModifyRecords_Process( &$job, &$start ) {
	global $wgRequest, $wgSiteNotice;
	$job['ChangeType'] = $wgRequest->getText( 'wpChangeType' );
	$job['From'] = $wgRequest->getText( 'wpFrom' );
	$job['To'] = $wgRequest->getText( 'wpTo' );
	return $start = true;
}

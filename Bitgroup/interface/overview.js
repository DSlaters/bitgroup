/**
 * This is the default node view which renders a simple navigation into the content within
 */
function Overview() {

	// do any initialisation of the view here such as loading dependencies etc

}

/**
 * Render the content into the #content div
 */
Overview.prototype.render = function(app) {
	var rows = '';
	for( i in app.data ) rows += '<tr><th>' + i + ':</th><td>' + app.data[i] + '</td></tr>\n';
	$('#content').html('<table>' + rows + '</table>');
};

// Create a singleton instance of our new view in the app's available views list
window.app.views.push( new Overview() );


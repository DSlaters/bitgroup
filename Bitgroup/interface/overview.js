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
	var content = '';
	var data = false;

	// A group is selected
	if(app.group) {

		// A node in the group is selected
		if(app.node) {
			if(app.node in app.data) {
				content += '<h1>' + app.msg('node').ucfirst() + ' "' + app.node + '" [' + app.group + ']</h1>\n';
				data = app.data[app.node];
			} else content += '<h1>' + app.msg('node-notfound', app.node) + '</h1>\n';
		}

		// No node is selected
		else {
			content += '<h1>' + app.msg('group').ucfirst() + ' "' + app.group + '"</h1>\n';
			data = app.data;
		}
	}

	// No group is selected
	else {
		content += '<h1>' + app.msg('user-info') + '</h1>\n'
		data = app.user;
	}

	// Render the data
	if(data) {
		var rows = '';
		for( i in data ) {
			var v = data[i];
			if(typeof v == 'object' && 'type' in v) {
				v = v.type;
				i = '<a href="#' + i + '">' + i + '</a>';
			}
			rows += '<tr><th>' + i + '</th><td>' + v + '</td></tr>\n';
		}
		content += '<table>' + rows + '</table>\n';
	}

	// Populate the content area
	$('#content').html(content);
};

// Create a singleton instance of our new view in the app's available views list
window.app.views.push( new Overview() );

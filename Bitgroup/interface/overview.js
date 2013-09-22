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
				content += '<h3>' + app.msg('node').ucfirst() + ' "' + app.node + '" [' + app.group + ']</h3>\n';
				data = app.data[app.node];
			} else content += '<h3>' + app.msg('node-notfound', app.node) + '</h3>\n';
		}

		// No node is selected
		else {
			content += '<h3>' + app.msg('group').ucfirst() + ' "' + app.user.groups[app.group] + '"</h3>\n';
			data = app.data;
		}
	}

	// No group is selected
	else {
		content += '<h3>' + app.msg('user-info') + '</h3>\n'
		data = app.user;
	}

	// Render the data
	if(data) {
		var rows = '';
		for( i in data ) {
			var v = (typeof data[i] == 'object' && '0' in data[i]) ? data[i][0] : data[i];
			if(typeof v == 'object' && 'type' in v) {
				v = v.type[0];
				i = '<a href="#' + i + '">' + i + '</a>';
			}
			rows += '<tr><th>' + i + '</th><td>' + v + '</td></tr>\n';
		}
		content += '<table>' + rows + '</table>\n';
	}

	// Render a live table for inbox messages
	content += '<br /><br /><h3>' + app.msg('inbox') + '</h3><div id="inbox"></div>\n';

	// Populate the content area
	$('#content').html(content);

	// Connect the table to the state data so it populates when it arrives
	var inbox = document.getElementById('inbox');
	inbox.setValue = function(val) {
		if(typeof val == 'object' && val.length > 0) {
			var rows = '<tr><th>' + app.msg('from') + '</th><th>' + app.msg('subject') + '</th></tr>\n';
			for( var i in val ) {
				var msg = val[i];
				rows += '<tr><td>' + msg.from + '</td><td>' + msg.subject + '</td></tr>\n';
			}
			$(this).html('<table>' + rows + '</table>');
		} else $(this).html(app.msg('nomessages'));
	};
	app.componentConnect('_inbox', inbox);
};

// Create a singleton instance of our new view in the app's available views list
window.app.views.push( new Overview() );


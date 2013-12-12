/**
 * This is the default node view which renders a simple navigation into the content within
 */
function Overview() {

	// do any initialisation of the view here such as loading dependencies etc

}

/**
 * Render the content into the #content div
 */
Overview.prototype.render = function() {
	var content = '';
	var data = false;

	// A node in the group is selected
	if(app.node) {
		if(app.node in app.data) {
			content += '<h3>' + app.msg('node').ucfirst() + ' "' + app.node + '" [' + app.group + ']</h3>\n';
			data = app.data[app.node];
		} else content += '<h3>' + app.msg('err-nosuchnode', app.node) + '</h3>\n';
	}

	// No node is selected
	else {
		var heading = app.group ? app.msg('group').ucfirst() + ' "' + app.user.groups[app.group] + '"' : app.user.name;
		content += '<h3>' + heading + '</h3>\n';
		data = app.data;
	}

	// Render the data
	if(data) {
		var rows = '';
		for( var i in data ) {
			var v = (data[i] && typeof data[i] == 'object' && '0' in data[i]) ? data[i][0] : data[i];
			if(v && typeof v == 'object' && 'type' in v) {
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
		var rows = '';
		for( var i in val ) {
			var msg = val[i];
			rows += '<tr><td>' + msg.from + '</td>'
					  + '<td>' + msg.subject + '</td>'
					  + '<td>' + msg.type + '</td></tr>\n';
		}
		if(rows) {
			rows = '<tr><th>' + app.msg('from') + '</th>'
				 + '<th>' + app.msg('subject') + '</th>'
				 + '<th>' + app.msg('type') + '</th></tr>\n'
				 + rows;
			$(this).html('<table>' + rows + '</table>');
		} else $(this).html(app.msg('nomessages'));
	};
	app.componentConnect(inbox, 'inbox');


	// TODO: Render a live table of members and their online information
	
};

// Create a singleton instance of our new view in the app's available views list
app.views.push( new Overview() );


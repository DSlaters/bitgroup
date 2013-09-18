/**
 * This is the view which allows the creation of new groups
 */
function NewGroup() {

	// do any initialisation of the view here such as loading dependencies etc

}

/**
 * Render the content into the #content div
 */
NewGroup.prototype.render = function(app) {

	// Put the group creation process into a function so it can be run after Bitgroup and Bitmessage are available if necessary
	var createGroup = function() {
		var info = app.notify(app.msg('newgroup-info'),'info');
		var form = '<div class="form"><label for="groupname">Name: </label><input type="text" id="groupname" />'
			+ '<input type="button" id="creategroup" value="' + app.msg('creategroup') + '" /></div>';
		$('#content').html(info + form);
		$('#creategroup').click(function() {
			$.ajax({
				type: 'POST',
				url: '/_newgroup',
				data: JSON.stringify({name:$('#groupname').val()}), 
				contentType: "application/json; charset=utf-8",
				dataType: 'html',
				success: function(group) { window.location = '/' + encodeURIComponent(group); }
			});
		});
	};

	// If the Bitgroup or Bitmessage daemon are both running, render the form
	if(app.state.bm == 'Connected' && app.state.bg == 'Conected') createGroup();

	// Otherwise,
	else {

		// Notify user that BM and BG must be running
		$('#notify').html(app.notify(app.msg('newgroup-noservice'),'error'));

		// Add a handler to the poller to check if bm and bg become available
		var handler = function() {

			// If they're available now,
			if(app.state.bg == 'Connected' && app.state.bm == 'Connected') {

				// Remove the warning
				$('#notify').html('');

				// Remove the ticker handler
				$(document).off('bgPoller', null, handler);

				// Render the form
				createGroup();
			}
		};
		$(document).on('bgPoller', handler);

		// If the user leaves the page, remove the handler
		$(document).one('bgHashChange', function() {
			$(document).off('bgPoller', null, handler);
		});

	}


};

// Create a singleton instance of our new view in the app's available views list
window.app.views.push( new NewGroup() );


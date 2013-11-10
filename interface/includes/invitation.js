/**
 * This is the view which allows a group member to invite other people to join the group
 */
function Invitation() {

	// Add the Invitation view to the menu if a group is selected, but no node
	$(document).on( "bgRenderViews", function(event) {
		if(app.group && !app.node) event.args.views.push('Invitation');
	});
}

/**
 * Render the content into the #content div
 */
Invitation.prototype.render = function() {

	// render the group creation form and the no service message in the notification
	var info = app.notify(app.msg('invitation-info', app.group.name), 'info');
	var form = '<div class="form"><p><label for="recipient">' + app.msg('invitation-recipient').ucfirst() + '</label></p><p><input type="text" id="recipient" />'
		+ '<input type="button" id="invitation" value="' + app.msg('invite').ucfirst() + '" /></p></div>';
	$('#content').html('<div class="needservice">' + info + form + '</div>');
	$('#notify').html(app.noservice);

	// Define the method to handle the form submission
	$('#invitation').click(function() {

		// Remove any errors from previous attempts and add please wait info
		$('#notify').html(app.noservice + app.notify(app.msg('wait'),'info'));
		app.needService();

		// Send the new group creation request
		$.ajax({
			type: 'POST',
			url: '/_invite.json',
			data: $.toJSON({
				'id': app.id,
				'recipient':$('#recipient').val()
			}),
			contentType: "application/json; charset=utf-8",
			dataType: 'json',
			success: function(data) {
				if('success' in data) {

					// Notify that the invitation has been successfully sent
					$('#notify').html(app.noservice + app.notify(app.msg('invitation-sent')));

				} else $('#notify').html(app.noservice + app.notify(data.err,'error'));
				app.needService();
			},
			error: function() {
				$('#notify').html(app.noservice + app.notify(app.msg('err-connection'),'error'));
				app.needService();
			}
		});
	});

	// Call the needService method now and on a regular interval until user leaves the page
	app.needService();
	$(document).on('bgPoller', app.needService);
	$(document).one('bgHashChange', function() { $(document).off('bgPoller', null, app.needService); });
};

// Create a singleton instance of our new view in the app's available views list
app.views.push( new Invitation() );


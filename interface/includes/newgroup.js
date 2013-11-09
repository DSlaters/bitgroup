/**
 * This is the view which allows the creation of new groups
 */
function NewGroup() {

	// Add the NewGroup view to the menu if no group is selected
	$(document).on( "bgRenderViews", function(event) {
		if(!app.group) event.args.views.push('NewGroup');
	});
}

/**
 * Render the content into the #content div
 */
NewGroup.prototype.render = function() {

	// render the group creation form and the no service message in the notification
	var info = app.notify(app.msg('newgroup-info'),'info');
	var form = '<div class="form"><label for="groupname">' + app.msg('name').ucfirst() + ': </label><input type="text" id="groupname" />'
		+ '<input type="button" id="creategroup" value="' + app.msg('creategroup') + '" /></div>';
	$('#content').html(info + form);
	$('#notify').html(app.noservice);

	// Define the method to handle the form submission
	$('#creategroup').click(function() {

		// Remove any errors from previous attempts and add please wait info
		$('#notify').html(app.noservice + app.notify(app.msg('wait'),'info'));
		app.needService();

		// Send the new group creation request
		$.ajax({
			type: 'POST',
			url: '/_newgroup.json',
			data: $.toJSON({'name':$('#groupname').val()}), 
			contentType: "application/json; charset=utf-8",
			dataType: 'json',
			success: function(data) {
				if('name' in data) {

					// Notify that the new group has been successfully created
					$('#notify').html(app.noservice + app.notify(app.msg('newgroup-created',data.name, data.addr, '/'
						+ encodeURIComponent(data.prvaddr)),'success groupcreated'));

					// Add the new group to the groups menu
					app.user.groups[data.prvaddr] = data.name;
					$('#personal-groups').html(app.renderGroupsList());

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
app.views.push( new NewGroup() );


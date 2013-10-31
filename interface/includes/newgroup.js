/**
 * This is the view which allows the creation of new groups
 */
function NewGroup() {

	// do any initialisation of the view here such as loading dependencies etc

}

/**
 * Render the content into the #content div
 */
NewGroup.prototype.render = function() {

	// render the group crreation form
	var info = app.notify(app.msg('newgroup-info'),'info');
	var form = '<div class="form"><label for="groupname">Name: </label><input type="text" id="groupname" />'
		+ '<input type="button" id="creategroup" value="' + app.msg('creategroup') + '" /></div>';
	$('#content').html(info + form);

	// Add notification that BM and BG must be running
	var noservice = app.notify(app.msg('newgroup-noservice'),'error noservice');
	$('#notify').html(noservice);

	// Define the method to handle the form submission
	$('#creategroup').click(function() {

		// Remove any errors from previous attempts and add please wait info
		$('#notify').html(noservice + app.notify(app.msg('wait'),'info'));
		showHide();

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
					$('#notify').html(noservice + app.notify(app.msg('groupcreated',data.name, data.addr, '/' + encodeURIComponent(data.prvaddr)),'success groupcreated'));

					// Add the new group to the groups menu
					app.user.groups[data.prvaddr] = data.name;
					$('#personal-groups').html(app.renderGroupsList());

				} else $('#notify').html(noservice + app.notify(data.err,'error'));
				showHide();
			},
			error: function() {
				$('#notify').html(noservice + app.notify(app.msg('err-connection'),'error'));
				showHide();
			}
		});
	});

	// If the Bitgroup or Bitmessage daemon are both running, render the form
	var showHide = function() {
		if(app.getData('bm') == CONNECTED && app.getData('bg') == CONNECTED) {
			$('#content').show();
			$('.noservice').hide();
		} else {
			$('#content').hide();
			$('.noservice').show();
		}
	};
	showHide();
	
	// Call the show/hide on regular interval
	$(document).on('bgPoller', showHide);

	// If the user leaves the page, remove the handler
	$(document).one('bgHashChange', function() {
		$(document).off('bgPoller', null, showHide);
	});
};

// Create a singleton instance of our new view in the app's available views list
app.views.push( new NewGroup() );


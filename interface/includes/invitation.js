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
	$('#content').html('todo...');
};

// Create a singleton instance of our new view in the app's available views list
app.views.push( new Invitation() );


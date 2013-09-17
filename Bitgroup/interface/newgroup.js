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

	$('#content').html('<div class="info">' + app.msg('newgroup-info') + '</div>');

};

// Create a singleton instance of our new view in the app's available views list
window.app.views.push( new NewGroup() );


/**
 * The main application singleton class
 */
function App() {

	this.views = []; // the availaber view classes - this first is the default if no view is specified by the current node
	this.group;      // the current group
	this.node;       // the current node
	this.view;       // the current view

	// Call the app's initialise function after the document is ready
	$(document).ready(function() { window.app.init.call(window.app) });

	// Regiester hash changes with our handler
	$(window).hashchange(function() { window.app.onLocationChange.call(window.app) });

};

/**
 * Hash change handler - set the current node and view for the application from the hash fragment of the location
 */
App.prototype.onLocationChange = function() {
	var hash = window.location.hash;
	elements = hash.split('/', hash.substr(1));
	this.node = elements.length > 0 ? elements[0] : false;

	// Check that the view is valid and convert to the class
	if(elements.length > 1) {
		for( var view in views ) {
			if(view.constructor.name.toLower() == elements[1].toLower()) this.view = view;
		}
	} else this.view = false;

	// TODO: view may want the additional elements
};

/**
 * All dependencies are loaded, initialise the application
 */
App.prototype.init = function() {

	// Load the node data for this request then run the application
	var url = this.group;
	if(url) url = '/' + url;
	url += '/_data.json';
	$.ajax({
		type: 'GET',
		url: url,
		dataType: 'json',
		context: this,
		success: function(json) {
			this.data = json
			this.run()
		}
	});		

	// Call the location change event to set the current node and view
	this.onLocationChange();
};

/**
 * All group data is loaded, initialise the selected skin and render the current node and view
 */
App.prototype.run = function() {

	// Render the page
	this.render();

};

/**
 * Render the page
 */
App.prototype.render = function() {
	var page = '';

	// Get the current skin and load it's styles
	var skin = 'skin' in this.data ? this.data.skin : 'default';
	this.loadStyleSheet('/skins/' + skin + '/style.css');

	// TODO: render the top bar

	// Get the list of view names used by this node + the default view
	var views = [this.views[0].constructor.name];
	if('views' in this.data) views += this.data.views;

	// Render the views menu
	page += '<ul id="views">';
	for( i = 0; i < views.length; i++ ) {
		var name = views[i];

		// Get the view class matching the name if any
		var view = false;
		for( var v in this.views ) if(view.constructor.name == name) view = v;
		
		// Add a menu item for this view (disabled if no class matched)
		var c = ' class="disabled"';
		if(view) c = name == this.view.constructure.name ? ' class="selected"' : '';
		var id = 'view-' + name.replace(' ','').toLowerCase();
		page += '<li' + c + ' id="' + id + '">' + name + '</li>\n';
	}
	page += '</ul>\n'

	// Add an empty content area for the view to render into
	var view = this.view;
	if(view == false) view = this.views[0];
	page += '<div id="content">';
	page += '<div>\n';

	// Add the completed page structure to the HTML document body
	$('body').html(page);

	// Call the view's render method to populate the content area
	view.render(this);
};

/**
 * Load a CSS fro the passed URL
 */
App.prototype.loadStyleSheet = function(url) {
	if (document.createStyleSheet) document.createStyleSheet(url);
	else $('<link rel="stylesheet" type="text/css" href="' + url + '" />').appendTo('head'); 
};

// Create a new instance of the application
window.app = new App();

/**
 * The main application singleton class
 */
function App() {

	this.views = []; // the availabe view classes - this first is the default if no view is specified by the current node
	this.user;       // the current user data
	this.group;      // the current group name
	this.node;       // the current node name
	this.view;       // the current view instance
	this.data = {};  // the current group's data
	this.sep = '/';  // separator character used in hash fragment

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
	elements = hash.substr(1).split(this.sep);
	this.node = elements.length > 0 ? elements[0] : false;

	// Check that the view is valid and convert to the class
	var oldview = this.view
	this.view = false;
	if(elements.length > 1) {
		for( var i = 0; i < this.views.length; i++ ) {
			var view = this.views[i];
			if(view.constructor.name.toLowerCase() == elements[1].toLowerCase()) this.view = view;
		}
	}

	// If the view has changed, call the event handler for it
	if(oldview != this.view) this.onViewChange();

	// TODO: view may want the additional URI elements
	
};

/**
 * All dependencies are loaded, now load the data for this group, then run the application
 */
App.prototype.init = function() {
	if(this.group) {
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
	} else this.run(); // just run app now if no group selected as no data to load
};

/**
 * All group data is loaded, initialise the selected skin and render the current node and view
 */
App.prototype.run = function() {

	// Call the location change event to set the current node and view
	this.onLocationChange();

	// Render the page
	this.renderPage();

};

/**
 * Render the page
 */
App.prototype.renderPage = function() {
	var page = '';

	// Get the current view class, or the default one if none
	var view = this.view;
	if(view == false) view = this.views[0];

	// Get the current skin and load it's styles
	var skin = 'skin' in this.data ? this.data.skin : 'default';
	this.loadStyleSheet('/skins/' + skin + '/style.css');

	// Render the top bar
	page += '<div id="personal"><h1>' + this.msg('groups') + '</h1><ul id="personal-groups">\n';
	var groups = this.user.groups;
	for( var i = 0; i < groups.length; i++ ) {
		var g = groups[i];
		var link = '<a href="/' + g + '">' + g +'</a>';
		page += '<li id="personal-groups-' + this.getId(g) + '">' + link + '</li>\n';
	}
	page += '</ul></div>\n';

	// Get the list of view names used by this node + the default view
	var views = [this.views[0].constructor.name];
	if('views' in this.data) views = views.concat(this.data.views);

	// Render the views menu
	page += '<h1>' + this.msg('views') + '</h1><ul id="views">';
	for( var i = 0; i < views.length; i++ ) {
		var name = views[i];

		// Get the view class matching the name if any
		var vi = false;
		for( var j = 0; j < this.views.length; j++ ) if(this.views[j].constructor.name == name) vi = this.views[j];

		// Add a menu item for this view (disabled if no class matched)
		var c = ' class="disabled"';
		var item = name;
		if(vi) {
			item = '<a href="#' + this.node + this.sep + item + '">' + item + '</a>';
			c = name == view.constructor.name ? ' class="selected"' : '';
		}
		var id = 'view-' + this.getId(name);
		page += '<li' + c + ' id="' + id + '">' + item + '</li>\n';
	}
	page += '</ul>\n'

	// Add an empty content area for the view to render into
	page += '<div id="content">';
	page += '<div>\n';

	// Add the completed page structure to the HTML document body
	$('body').html(page);

	// Call the view's render method to populate the content area
	view.render(this);
};

/**
 * When the view changes, update the views list classes and call the render method
 */
App.prototype.onViewChange = function() {
	var view = this.view ? this.view : this.views[0];
	$('#views li.selected').removeClass('selected');
	$('#view-' + this.getId(view)).addClass('selected');
	view.render(this);
};

/**
 * Load a CSS from the passed URL
 */
App.prototype.loadStyleSheet = function(url) {
	if (document.createStyleSheet) document.createStyleSheet(url);
	else $('<link rel="stylesheet" type="text/css" href="' + url + '" />').appendTo('head'); 
};

/**
 * Convert a name to a valid identifier
 */
App.prototype.getId = function(name) {
	if(typeof name != 'string') name = name.constructor.name;
	return name.replace(' ','').toLowerCase();
};

/**
 * Message dialog and error logging
 */
App.prototype.error = function(msg,type = 'info') {
	alert(type + ': ' + msg);
};

/**
 * Return message from key
 */
App.prototype.msg = function(key) {
	// TODO: variable replacements in messages and lang code
	var lang = this.user.lang;
	if(lang in window.messages && key in window.messages[lang]) return window.messages[lang][key];
	if(key in window.messages.en) return window.messages.en[key];
	return '&lt;' + key + '&gt;';
};

// Create a new instance of the application
window.app = new App();

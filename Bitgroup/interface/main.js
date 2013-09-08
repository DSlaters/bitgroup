/**
 * The main application singleton class
 */
function App() {

	this.views = [];   // the availabe view classes - this first is the default if no view is specified by the current node
	this.user;         // the current user data
	this.group;        // the current group name
	this.data = {};    // the current group's data
	this.node;         // the current node name
	this.view;         // the current view instance
	this.sep = '/';    // separator character used in hash fragment
	this.queue = {};   // queue of data updates to send to the service
	this.maxage;       // max lifetime in seconds of queue data
	this.lastsync = 0; // unix timestamp of last data sync - if greater than maxage, all data will be loaded

	// Call the app's initialise function after the document is ready
	$(document).ready(function() { window.app.init.call(window.app) });

	// Regiester hash changes with our handler
	$(window).hashchange(function() { window.app.locationChange.call(window.app) });
};

/**
 * Hash change handler - set the current node and view for the application from the hash fragment of the location
 */
App.prototype.locationChange = function() {
	var hash = window.location.hash;
	elements = hash.substr(1).split(this.sep);
	var oldnode = this.node;
	var newnode = elements.length > 0 ? elements[0] : false;

	// Check that the view is valid and convert to the class
	var oldview = this.view
	var newview = false;
	if(elements.length > 1) {
		for( var i = 0; i < this.views.length; i++ ) {
			var view = this.views[i];
			if(view.constructor.name.toLowerCase() == elements[1].toLowerCase()) newview = view;
		}
	}

	// Allow extensions to hook in here
	var args = {
		node: newnode,
		view: newview,
		path: elements,
	};
	$.event.trigger({type: "bgHashChange", args: args});

	// Set the new data
	this.node = args.node;
	this.view = args.view;

	// If the node or the view has changed, call the event handler for it
	if(oldnode != this.node) this.nodeChange();
	else if(oldview != this.view) this.viewChange();

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
	this.locationChange();

	// Render the page
	this.renderPage();

	// Initialise a poller for regular data transfers to and from the service
	setInterval( function() {
		$.event.trigger({type: "bgPoller"});
		window.app.syncData();
	}, 1000 );
};

/**
 * Render the page
 */
App.prototype.renderPage = function() {
	var page = '';

	// Get the current skin and load it's styles
	var skin = 'skin' in this.data ? this.data.skin : 'default';
	this.loadStyleSheet('/skins/' + skin + '/style.css');

	// Render the top bar
	page += '<div id="personal">\n';
	page += '<a id="user-page" href="/">' + this.msg('user-page') + '</a>\n';
	page += '<h1>' + this.msg('groups').ucfirst() + '</h1><ul id="personal-groups">\n';
	var groups = this.user.groups;
	for( var i = 0; i < groups.length; i++ ) {
		var g = groups[i];
		var link = '<a href="/' + g + '">' + g +'</a>';
		page += '<li id="personal-groups-' + this.getId(g) + '">' + link + '</li>\n';
	}
	page += '</ul></div>\n';

	// Render the views menu
	page += '<h1>' + this.msg('views').ucfirst() + '</h1><ul id="views">' + this.renderViewsMenu() + '</ul>\n'

	// Add an empty content area for the view to render into
	page += '<div id="content">';
	page += '<div>\n';

	// Add the completed page structure to the HTML document body
	$('body').html(page);

	// Call the view's render method to populate the content area
	this.view.render(this);
};

/**
 * Render the views menu
 */
App.prototype.renderViewsMenu = function() {
	var html = '';

	// Get the current view class, or the default one if none
	var view = this.view;
	if(view == false) view = this.view = this.views[0];

	// Get the list of view names used by this node + the default view
	var views = [this.views[0].constructor.name];
	if(this.node && this.node in this.data && 'views' in this.data[this.node])
		views = views.concat(this.data[this.node].views);

	// Render the views menu
	for( var i = 0; i < views.length; i++ ) {
		var name = views[i];

		// Get the view class matching the name if any
		var vi = false;
		for( var j = 0; j < this.views.length; j++ ) if(this.views[j].constructor.name == name) vi = this.views[j];

		// Add a menu item for this view (disabled if no class matched)
		var c = ' class="disabled"';
		var item = name;
		if(vi) {
			item = '<a href="#' + this.node + this.sep + item + '">' + this.msg('view-'+ item.toLowerCase()) + '</a>';
			c = name == view.constructor.name ? ' class="selected"' : '';
		}
		var id = 'view-' + this.getId(name);
		html += '<li' + c + ' id="' + id + '">' + item + '</li>\n';
	}
	return html;
};

/**
 * When the node changes, rebuild the views menu and update the view
 */
App.prototype.nodeChange = function() {
	$('#views').html(this.renderViewsMenu());
	this.viewChange();
};

/**
 * When the view changes, update the views list classes and call the render method
 */
App.prototype.viewChange = function() {
	if($('#views').length > 0) {
		var view = this.view ? this.view : this.views[0];
		$('#views li.selected').removeClass('selected');
		$('#view-' + this.getId(view)).addClass('selected');
		view.render(this);
	}
};

/**
 * Called on a regular interval to send queued data to the service and receive any queued items
 */
App.prototype.syncData = function() {
	var ts = this.unixtime();
	$.ajax({
		type: 'POST',
		url: '/' + this.group + '/_sync.json',
		data: JSON.stringify([ts,this.queue]),
		contentType: "application/json; charset=utf-8",
		dataType: 'json',
		success: function(data) {
			
			// If the result is an object, then it's the whole data structure
			if(data.length === 'undefined') {
				this.data = json;
				this.renderPage(); // just rebuild the page instead of raising events for all the changes

			// A list of change events was returned, update the local data and trigger change events
			else {
				for( k in data ) {
					var v = data[k];
					this.setData(k,v);
					$.event.trigger({type: "bgDataChange-"+k, args: {val:v}});
				}
			}
		}
	});

	// Clear the queue now that it's data's been sent
	// TODO: only clear queue after acknowledgement of reception
	this.queue = {};
};

/**
 * Return the data for the passed key
 * TODO: don't use eval for this, make a path walking function like node.py
 */
App.prototype.getData = function(key) {
	return eval( 'this.data.' + key );
};

/**
 * Set the data for the passed key to the passed value
 * TODO: don't use eval for this, make a path walking function like node.py
 */
App.prototype.setData = function(key,val) {
	eval( 'this.data.' + key + '=val' );
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
App.prototype.msg = function(key, s1, s2, s3, s4, s5) {
	var lang = this.user.lang;
	var str;

	// Get the string in the user's language if defined
	if(lang in window.messages && key in window.messages[lang]) str = window.messages[lang][key];

	// Fallback on the en version if not found
	else if(key in window.messages.en) str = window.messages.en[key];

	// Otherwise use the message key in angle brackets
	else str = '&lt;' + key + '&gt;';

	// Replace variables in the string
	str = str.replace('$1', s1);
	str = str.replace('$2', s2);
	str = str.replace('$3', s3);
	str = str.replace('$4', s4);
	str = str.replace('$5', s5);

	return str;
};

App.prototype.unixtime = function() {
	return Math.round(new Date().getTime() / 1000);
};

/**
 * Connect a DOM element to a data source
 */
App.prototype.connect = function(key, element) {
	element.dataSource = key;

	// Set the current value
	$(element).val(this.getData(key));

	// When the value changes from the server update the element
	$(document).on( "bgDataChange-" + key, function(event) { $(element).val(event.args.val); });

	// When the element value changes, queue the change for the server
	$(element).change(function() {
		var app = window.app;
		app.queueAdd(this.dataSource, $(this).val());
	});

/**
 * Queue a changed item for sending to the service
 */
App.prototype.queueAdd = function(key, val) {
};

};

/**
 * Add ucfirst method to strings
 */
String.prototype.ucfirst = function() {
    return this.charAt(0).toUpperCase() + this.slice(1);
}

/**
 * Add JSON support for older browsers that don't have it
 */
if (!window.JSON) {
	window.JSON = {
		parse: function (sJSON) { return eval("(" + sJSON + ")"); },
		stringify: function (vContent) {
			if (vContent instanceof Object) {
				var sOutput = "";
				if (vContent.constructor === Array) {
					for (var nId = 0; nId < vContent.length; sOutput += this.stringify(vContent[nId]) + ",", nId++);
					return "[" + sOutput.substr(0, sOutput.length - 1) + "]";
				}
				if (vContent.toString !== Object.prototype.toString) { return "\"" + vContent.toString().replace(/"/g, "\\$&") + "\""; }
				for (var sProp in vContent) { sOutput += "\"" + sProp.replace(/"/g, "\\$&") + "\":" + this.stringify(vContent[sProp]) + ","; }
				return "{" + sOutput.substr(0, sOutput.length - 1) + "}";
			}
			return typeof vContent === "string" ? "\"" + vContent.replace(/"/g, "\\$&") + "\"" : String(vContent);
		}
	};
}

// Create a new instance of the application
window.app = new App();

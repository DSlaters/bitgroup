/**
 * The main application singleton class
 */
function App() {

	// An identity for this client connection - python socket seems to be missing the ability to identify the stream
	this.id = Math.uuid(5)

	this.user;             // the current user data
	this.group;            // the current group name
	this.views = [];       // the availabe view classes - this first is the default if no view is specified by the current node
	this.view;             // the current view instance
	this.node;             // the current node name
	this.sep = '/';        // separator character used in hash fragment

	this.data = {};        // the current group's data
	this.queue = {};       // queue of data updates to send to the background service in the form keypath : [val, timestamp]
	this.syncTime = 5000;  // milliseconds between each sync request

	// Populate the properties that were sent in the page
	for( var i in window.tmp ) this[i] = window.tmp[i];

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
	}, this.syncTime );
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
	page += 'UUID: ' + this.id
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
		views = views.concat(this.data[this.node].views[0]);

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

	// Convert the queue from a hash into a list
	var data = [];
	for( var k in this.queue ) data.push([k, this.queue[k][0], this.queue[k][1]]);
	var lastSync = this.timestamp();

	// Send the sync request
	$.ajax({
		type: 'POST',
		url: '/' + this.group + '/_sync.json',
		data: data.length > 0 ? JSON.stringify(data) : '', 
		contentType: "application/json; charset=utf-8",
		headers: { 'X-Bitgroup-ID': this.id },
		dataType: 'json',
		context: this,
		success: function(data) {

			// If the result is an object, then it's the whole data structure
			if(data.length === undefined) {
				this.data = data;
				this.renderPage(); // just rebuild the page instead of raising events for all the changes
			}

			// A list of changed keys was returned, update the local data and trigger change events
			// - note these have no timestamp since we're not merging with another queue
			// - note2 the data is set with queue set to false
			else {
				for( var i = 0; i < data.length; i++ ) {
					var k = data[i][0];
					var v = data[i][1];
					var ts = data[i][2];
					console.info('data received (@' + ts + '): ' + k + ' = "' + v + '"');
					this.setData(k, v, false, ts);
				}
			}

			// Remove all items queued before the sync request was made
			var tmp = {};
			for( var k in this.queue ) if(this.queue[k][1] > lastSync) tmp[k] = this.queue[k];
			this.queue = tmp;
		}
	});
};

/**
 * Return the data for the passed key
 * - return the timestamp to if ts set
 * TODO: don't use eval for this, make a path walking function like node.py
 */
App.prototype.getData = function(key, ts) {
	var val = eval('this.data.' + key);
	if(val === undefined) console.info( 'undefined value for ' + key );
	return ts === true ? val : val[0];
};

/**
 * Set the data for the passed key to the passed value
 * TODO: don't use eval for this, make a path walking function like node.py
 */
App.prototype.setData = function(key, val, queue, ts) {

	// Get the current value and timestamp
	var oldval = this.getData(key, true);
	var oldts = oldval[1];
	oldval = oldval[0]

	// Bail now if the value hasn't changed
	if(JSON.stringify(oldval) == JSON.stringify(val)) return false;

	// Bail if the new data is older than the current data
	if(ts === undefined) ts = this.timestamp();
	else if(oldts > ts) {
		console.info('The local version of ' + key + ' is more recent (@' + oldts + ') than the passed version (@' + ts +')');
		return false;
	}

	// Trigger the data changed event
	$.event.trigger({type: "bgDataChange-" + key.replace('.', '-'), args: {app:this, val:val}});

	// Update the value with the timestamp
	val = [val, ts];
	eval('this.data.' + key + '=val');

	// Add the change to the outgoing sync queue (if it didn't come from the incoming queue)
	if(queue === undefined) queue = true;
	if(queue) this.queue[key] = val;

	console.info(key + ' changed from "' + oldval + '" to "' + val[0] + '" (@' + ts + ')' + (queue ? ' - queued' : ''));
	return true;
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
App.prototype.error = function(msg, type) {
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

/**
 * Return a millisecond timestamp - must match app.py's timestamp
 */
App.prototype.timestamp = function() {
	return new Date().getTime() - 1378723000000;
};

/**
 * Detect the general type of an interface component based on its DOM attributes
 */
App.prototype.componentType = function(element) {
	element = $(element)[0];
	var type = false;
	if($(element).attr('type') == 'checkbox') type = 'checkbox';
	else if(element.tagName == 'SELECT') type = 'select';
	else if($(element).hasClass('checklist')) type = 'checklist';
	else if($(element).attr('value') !== undefined || element.tagName == 'textarea') type = 'input';
	else if(element.tagName == 'DIV') type = 'div';
	else if(element.tagName == 'SPAN') type = 'span';
	return type;
};

/**
 * Return whether the passed component type allows user input
 */
App.prototype.componentIsInput = function(type) {
	return type == 'input' || type == 'checkbox' || type == 'select' || type == 'checklist' || type == 'textarea';
};

/**
 * Set the value of an interface component based on its general type
 */
App.prototype.componentSet = function(element, val, type) {
	if(type === undefined) type = this.componentType(element);
	if(type == 'div' || type == 'span') $(element).html(val);
	else if(type == 'input' || type == 'textarea') $(element).val(val);
	else if(type == 'checkbox') $(element).attr('checked',val ? true : false);
	else if(type == 'select') {
		if(typeof val != 'object') val = [val];
		$('option',element).each(function() { this.selected = val.indexOf($(this).text()) >= 0 });
	}
	else if(type == 'checklist') {
		if(typeof val != 'object') val = [val];
		$('input',element).each(function() { this.checked = val.indexOf($(this).next().text()) >= 0 });
	}
};

/**
 * Get the value of an interface component based on its general type
 */
App.prototype.componentGet = function(element, val, type) {
	var val = false;
	if(type === undefined) type = this.componentType(element);
	if(type == 'div' || type == 'span') val = $(element).html();
	else if(type == 'input' || type == 'textarea') val = $(element).val();
	else if(type == 'checkbox') val = $(element).is(':checked');
	else if(type == 'select') {
		if($(element).attr('multiple') === undefined) val = $('option[selected]',element).text();
		else {
			val = [];
			$('option',element).each(function() { if($(this).is(':selected')) val.push($(this).text()) });
		}
	}
	else if(type == 'checklist') {
		val = [];
		$('input',element).each(function() { if($(this).is(':checked')) val.push($(this).next().text()); });
	}
	return val;
};

/**
 * General renderer for interface components
 */
App.prototype.componentRender = function(type, data, atts) {
	if(data === undefined) data = '';
	if(atts === undefined) atts = {};
	if(!('id' in atts)) atts.id = Math.uuid(5);
	html = '';
	attstr = '';
	for(k in atts) attstr += ' ' + k + '="' + atts[k] + '"';

	// HTML
	if(type == 'div' || type == 'span') html = '<' + type + attstr + '>' + data + '</' + type + '>';

	// Text input
	else if(type == 'input') html = '<input' + attstr + ' type="text" value="' + data + '" />';

	// Checkbox
	else if(type == 'checkbox') html = '<input' + attstr + ' type="text" value="' + data + '" />';

	// Select list
	else if(type == 'select') {
		html = '<select' + attstr + '>';
		for(i = 0; i < data.length; i++) html += '<option>' + data[i] + '</option>';
		html += '</select>';
	}

	// Checklist
	else if(type == 'checklist') {
		html = '<div' + attstr + ' class="checklist">';
		for(i = 0; i < data.length; i++) html += '<input type="checkbox" /><span>' + data[i] + '</span><br />';
		html += '</div>';
	}

	// Textarea
	else if(type == 'textarea') {
		html = '<textarea' + attstr + '>' + data + '</textarea>';
	}

	// Unknown type
	else html = '<div' + attstr + '>' + app.msg( 'err-nosuchcomponent', type) + '</div>';

	return html;
};

/**
 * Connect an interface component to a data source
 */
App.prototype.componentConnect = function(key, element) {
	element = $(element)[0];
	var val = this.getData(key);
	var type = this.componentType(element);

	// Set the source for the element's value
	element.dataSource = key;

	// Set the input's value to the current data value
	this.componentSet(element, val, type);

	// When the value changes from the server, update the element
	console.info('Connecting component "' + element.id + '" to ' + key);
	var handler = function(event) {
		if($(element).parents().filter('body').length > 0) event.args.app.componentSet(element, event.args.val)
		else {
			console.info('Component "' + element.id + '" gone, removing event');
			$(document).off(element, null, handler);
		}
	};
	var event = "bgDataChange-" + key.replace('.','-');
	$(document).on(event, handler);

	// When the element value changes (if an input), update the local data structure and queue the change for the next sync request
	if(this.componentIsInput(type)) {
		var i = type == 'checklist' ? $('input',element) : $(element);
		i.change(function() {
			var app = window.app;
			var val = app.componentGet(element);
			var key = element.dataSource;
			app.setData(key, val);
		});
	}
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
if(!window.JSON) {
	window.JSON = {
		parse: function (sJSON) { return eval("(" + sJSON + ")"); },
		stringify: function (vContent) {
			if(vContent instanceof Object) {
				var sOutput = "";
				if(vContent.constructor === Array) {
					for(var nId = 0; nId < vContent.length; sOutput += this.stringify(vContent[nId]) + ",", nId++);
					return "[" + sOutput.substr(0, sOutput.length - 1) + "]";
				}
				if(vContent.toString !== Object.prototype.toString) { return "\"" + vContent.toString().replace(/"/g, "\\$&") + "\""; }
				for(var sProp in vContent) { sOutput += "\"" + sProp.replace(/"/g, "\\$&") + "\":" + this.stringify(vContent[sProp]) + ","; }
				return "{" + sOutput.substr(0, sOutput.length - 1) + "}";
			}
			return typeof vContent === "string" ? "\"" + vContent.replace(/"/g, "\\$&") + "\"" : String(vContent);
		}
	};
}

// Create a new instance of the application
window.app = new App();


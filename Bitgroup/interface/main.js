/**
 * Copyright (C) 2013 Aran Dunkley
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 * http://www.gnu.org/copyleft/gpl.html
 */
function App(){

	// Call the app's initialise function after the document is ready
	$(document).ready(function() { window.app.init.call(window.app) });

	// Regiester hash changes with our handler
	$(window).hashchange(function() { window.app.onLocationChange.call(window.app) });

};

// Hash change handler
App.prototype.onLocationChange = function() {
	alert('hash: ' + document.location.hash);
};

// All dependencies are loaded, initialise the application
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
};

// All group data is loaded, initialise the selected skin and render the current node and view
App.prototype.run = function() {
	rows = '';
	for( i in this.data ) rows += '<tr><th>' + i + ':</th><td>' + this.data[i] + '</td></tr>\n';
	$('body').html('<table>' + rows + '</table>');
};

// Create a new instance of the application
window.app = new App();

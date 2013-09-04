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

	// Regiester hash changes with our handler
	jQuery(window).hashchange(function() { this.app.onLocationChange.call(this.app) });
};

// Hash change handler
App.prototype.onLocationChange = function() {
	alert(document.location.hash + '\n' + this.group);
};

// Initialise the application
App.prototype.run = function() {
};


// Create a new instance of the application
window.app = new App();

// When the DOM is ready, run the application.
$(function(){
	window.app.run();
});

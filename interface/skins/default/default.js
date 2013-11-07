/**
 * Default skin based on http://www.organicdesign.co.nz
 */

// Add wrapper divs to the content area for adding corners and shadows
var page = $('#page');
page.html( '<div id="header"><div></div></div>'
	+ '<div id="page-wrapper"><div id="page-l"><div id="page-r"><div id="page-interior">'
	+ page.html()
	+ '</div></div></div></div>'
	+ '</div><div id="footer"><div></div></div>'
);

// Make the personal links into a menu bar
$("#personal ul").menu({position: {at: "left bottom"}});

// Surround tables in divs
$(document).on( "bgPageRendered", function(event) {
	$("#content table").wrap('<span class="table-wrapper"></span>');
});


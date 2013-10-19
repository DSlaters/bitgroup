function Properties() {

	// Add some i18n messages
	// TODO: extensions should be in their own dirs and have an i18n.js file for messages
	window.app.msgSet('en', 'title-properties', 'Properties for $1');

	// Add a test event
	$(document).on("bgHashChange", function(e) {
		e.args.foo = 'bizzybiz';
	});
}

Properties.prototype.render = function(app) {
	var input1 = app.componentRender('select',['foo', 'properties','bar','baz'], {multiple:1});
	var input2 = app.componentRender('checklist',['foo', 'properties','bar','baz']);
	var output = 'The value of <i>x.y.z</i> is &quot;<span id="otest"></span>&quot;';
	$('#content').html('<table><tr><td valign=top><h3>Select list test</h3>'
		+ input1 + '</td><td valign=top><h3>Checklist test</h3>'
		+ input2 + '</td><td valign=top><h3>Output test</h3>'
		+ output + '</td></tr></table>'
	);
	app.componentConnect('settings.extensions', $('#content select'));
	app.componentConnect('settings.extensions', $('#content .checklist'));
	app.componentConnect('x.y.z', $('#content #otest'));
};

window.app.views.push( new Properties() );



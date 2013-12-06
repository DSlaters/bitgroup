/**
 * This extension adds a new interface component called "checklist" which is a list if checkboxes that work like a multi-select
 */

// Render our component
$(document).on( "bgComponentRender", function(event) {
	if(event.args.type == 'checklist') {
		event.args.html = '<div' + event.args.attstr + '>';
		for(i = 0; i < event.args.data.length; i++)
			event.args.html += '<input type="checkbox" /><span>' + event.args.data[i] + '</span><br />';
		event.args.html += '</div>';
	}
});

// Get the value of an instance of our component
$(document).on( "bgComponentGetValue", function(event) {
	if(event.args.type == 'checklist') {
		event.args.val = [];
		$('input',event.args.element).each(function() {
			if($(this).is(':checked')) event.args.val.push($(this).next().text());
		});
	}
});

// Set the value of an instance of our component
$(document).on( "bgComponentSetValue", function(event) {
	if(event.args.type == 'checklist') {
		if(typeof event.args.val != 'object') event.args.val = [event.args.val];
		$('input',event.args.element).each(function() {
			this.checked = event.args.val.indexOf($(this).next().text()) >= 0;
		});
	}
});

// Return true if checking whether a component is an input and its an instance of ours
$(document).on( "bgComponentIsInput", function(event) {
	if(event.args.type == 'checklist') event.args.input = true;
});

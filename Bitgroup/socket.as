import flash.external.ExternalInterface;

class App {

	static var app:App;
	var sock:XMLSocket = new XMLSocket();
	var connected = false;
	var id;
	var idSent = false;
	var port = false;
	var ctr = 1;

	function App() {
		_root.createTextField('status', 0, 0, 0, 100, 20);
		_root.status.text = 'init';

		// Send null data to tell the JS we're ready
		ExternalInterface.call("window.app.swfData", "");
  
		// Socket connect
		this.sock.onConnect = function(status) {
			var app = _root.app;
			if(status) {
				app.connected = true;
				_root.status.text = 'connected';
			} else {
				app.connected = false;
				app.ctr = 1;
				_root.status.text = 'failed';
			}
		};
 
		// Socket close - reset periodic counter, and clear idSent to reidentify with server
		this.sock.onClose = function() {
			var app = _root.app;
			app.connected = false;
			_root.status.text = 'not connected';
			app.ctr = 1;
			app.idSent = false;
		};

		// When this socket receives data, send it to the JS
		this.sock.onData = function(json) {
			ExternalInterface.call("window.app.swfData", json);
		};
 
		// Receive the client ID and connection port from the JS
		ExternalInterface.addCallback("data", null, function(id, port) {
			var app = _root.app;
			app.id = id;
			app.port = port;
			app.sock.connect(null, port);
			app.ctr = 1;
		});
 
		// Called periodically (per frame)
		_root.onEnterFrame = function() {
			var app = _root.app;
			if(app.connected) {

				// If the ID hasn't been sent to the server on this connection yet do it now
				if(!app.idSent) {
					app.sock.send('<client-id>' + app.id + '</client-id>')
					app.idSent = true;
				}
			}
			else {
				
				// If the socket isn't connected, try and connect every few seconds
				if(app.port && ++app.ctr%50 == 1) app.sock.connect(null, app.port);
			}
		};
 	}

	static function main(mc) {
		_root.app = new App();
	}
}

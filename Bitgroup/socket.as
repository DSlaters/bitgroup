import flash.external.ExternalInterface;

class App {

	static var app:App;
	var sock:XMLSocket = new XMLSocket();
	var connected = false;
	var ctr = 1;	

	function App() {
		_root.createTextField("status",0,0,0,100,20);
		_root.status.text = 'init';
		_root.client = false;
    
		ExternalInterface.addCallback("test", null, function(msg) {
			_root.status.text = msg;
		});
  
		// Socket connect
		this.sock.onConnect = function(s) {
			var app = _root.app;
			if(s) {
				app.connected = true;
				ExternalInterface.call("window.test");
			} else {
				app.connected = false;
				app.ctr = 1;
				_root.status.text = 'failed';
			}
		};
 
		// Socket data
		this.sock.onData = function(data) {
		};
 
		// Socket close
		this.sock.onClose = function() {
			var app = _root.app;
			app.connected = false;
			_root.status.text = 'not connected';
			app.ctr = 1;
		};
 
		// Called periodically (per frame)
		_root.onEnterFrame = function() {
			var app = _root.app;
			//_root.status.text = 'test: ' + _root.client;
			if(app.connected == false && ++app.ctr%50 == 1) app.sock.connect(null, 8080);
		};
 	}

	static function main(mc) {
		_root.app = new App();
	}
}

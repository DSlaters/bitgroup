class App {

	static var app:App;
	var sock:XMLSocket = new XMLSocket();
	var connected = false;
	var ctr = 1;		

	function App() {
		_root.createTextField("status",0,0,0,100,20);
		_root.status.text = 'init';
  
		// Socket connect
		this.sock.onConnect = function(s) {
			var app = _root.app;
			if(s) {
				app.connected = true;
				_root.status.text = 'connected';
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
			if(app.connected == false && ++app.ctr%50 == 1) {
				var x = app.sock.connect(null, 8080);
				_root.status.text = app.connected = 'connecting ' + (x ? '(1)' : '(0)');
			}
		};
 	}

	static function main(mc) {
		_root.app = new App();
	}
}

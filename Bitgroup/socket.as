class App {

	static var app : App;

	function App() {
		var sock = new XMLSocket();
		_root.createTextField("status",0,0,0,100,20);
		_root.status.text = "Hello world!!!";
	}

	static function main(mc) {
		app = new App();
	}
}

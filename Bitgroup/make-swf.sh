#!/bin/bash
if [ ! -f "./mtasc" ]; then
	wget http://www.mtasc.org/zip/mtasc-1.12-linux.tgz
	tar -zxf mtasc*.tgz
fi

if [ -f ./interface/socket.swf ]; then
	rm ./interface/socket.swf
fi

echo "Compiling socket.swf..."
./mtasc -swf ./interface/socket.swf -main -header 100:20:20 socket.as

if [ -f ./interface/socket.swf ]; then
	echo "Done."
	else
	echo "Error: socket.swf not created."
fi

// http://www.organicdesign.co.nz/peerd - nodal p2p wiki daemon{{C}}{{Category:Peerd}}
// Source: http://www.organicdesign.co.nz/peerd/files/C - the C language version for *ix,OSX,NT platforms
// This article and all its includes are licenced under http://www.gnu.org/copyleft/lesser.html
// Compiled in Win32 by peerd.c/win32-makefile to http://www.organicdesign.co.nz/wiki/images/a/a2/Peerd.msi
// Compiled in Linux and OSX by rp to peerd.deb and peerd.dmg

// Globals
int this = 0,parent,grandpa,port = 80;
char *peer = "default";
char *file = (char*)0;

// Reserved nodes used by nodal reduction process (tmp)
#define nodeTRUE   1  // [[[[nodeTRUE]]]]
#define nodeNEXT   1  // [[[[nodeNEXT]]]]
#define nodePREV   2  // [[[[nodePREV]]]]
#define nodeCODE   3  // [[[[nodeCODE]]]] is a [[[[association|pseudo node-value]]]] to determine is the nodes non-nodal-data is a function-ref
#define nodePARENT 4  // [[[[nodePARENT]]]] updated by [[[[nodal reduction]]]], the node for which thsi is the [[[[focus]]]]
#define nodeTRIE   5  // [[[[nodeTRIE]]]] use a different root for trie/hash so it can't interfere with serialisation of nodal-root
#define nodeFIRST  6  // [[[[nodeFIRST]]]]
#define nodeLAST   7  // [[[[nodeLAST]]]]
#define nodeMAKE   8  // [[[[nodeMAKE]]]]
#define nodeINIT   9  // [[[[nodeINIT]]]]
#define nodeMAIN   10 // [[[[nodeMAIN]]]]
#define nodeEXIT   11 // [[[[nodeEXIT]]]]


#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <stdarg.h>
#include <time.h>
#include <regex.h>
#include "util.h"           // [[[[util.c]]]]: General utils, file,log,string etc

// List & Node Space
#include "listSpace.h"      // [[[[listSpace.c]]]]: listSpace and some C-specific extras: hash, trie, linked-list
#include "nodeSpace.h"      // [[[[nodeSpace.c]]]]: NodeSpace function declarations and initialisation
#include "serialise.h"      // [[[[serialise.c]]]]: Nodal-to-text and visa-versa

// Interface related
#include "SDL.h"
#include "SDL_image.h"
#include "SDL_ttf.h"
//#include "SDL_opengl.h"     // OpenGL example [[[[http://www.libsdl.org/cgi/docwiki.cgi/OpenGL_20Full_20Example|here]]]]
#include "interface.h"      // [[[[interface.c]]]]: Layer model, video, audio, input, OpenGL

// Peer daemon setup
#if __WIN32__
#include "servicate.h"      // [[[[servicate.c]]]]
#elif __APPLE__
#include "launchd.h"        // [[[[launchd.c]]]]
#elif __unix__
#include "daemonise.h"      // [[[[daemonise.c]]]]
#endif

// [[[[Communications]]]] related
#if __WIN32__
#include <winsock.h>
#else
#include <sys/socket.h>     // see [[[[http://www.opengroup.org/onlinepubs/009695399/functions/select.html|select()]]]]
#include <sys/select.h>
#include <netinet/in.h>
#include <sys/time.h>       // for select() related stuff
#include <fcntl.h>          // O_RDWR, O_NONBLOCK, F_GETFL, F_SETFL
#include <netdb.h>          // for [[[[http://www.opengroup.org/onlinepubs/009695399/basedefs/netdb.h.html|hostent struct]]]]
#endif
#include "io.h"             // [[[[io.c]]]]: Main server and stream setup and functions

int main(int argc, char **argv) {

	logAdd("");             // Blank line in log to separate peerd sessions
	peerdInit();            // Set up as a daemon or service
	listInit();             // Initialise list-space and hash/trie functions
	nodeInit();             // Set up initial nodal structure for reduction loop
	args(argc,argv);        // Handle command-line args and globals like peer and port
	ifInit();               // Initialise interface aspects (video, audio, input, OpenGL)
	ioInit();               // Set up listening socket on specified port

	// Main [[[[nodal reduction]]]] loop
	// - maintains [[[[this]]]], [[[[parent]]]] and [[[[grandpa]]]] globals
	logAdd("Handing program execution over to nodal reduction...");
	while(1) nodeReduce();

	}


// http://www.organicdesign.co.nz/peerd - p2p daemon{{C}}{{Category:Peerd}}

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <stdarg.h>
#include <time.h>
#include <regex.h>

int peerdInit() {

	// Fork so parent can exit and return control to what invoked it
	pid_t pid = fork();
	if (pid > 0) exit(EXIT_SUCCESS);
	if (pid < 0) {
		//logAdd("daemonise: First fork() failed!");
		exit(EXIT_FAILURE);
		}

	// Become a new session leader with no controlling term
	if (setsid() < 0) {
		//logAdd("daemonise: setsid() failed!");
		exit(EXIT_FAILURE);
		}

	// Fork again to be a non-session-leader which can't gain a controlling term
	pid = fork();
	if (pid > 0) exit(EXIT_SUCCESS);
	if (pid < 0) {
		//logAdd("daemonise: second fork() failed!");
		exit(EXIT_FAILURE);
		}

	//errno = 0;
	// Should be /home/lc(peer)
	chdir("/home/peerd");

	// Don't inherit any file perms mask
	umask(0);

	//close(STDIN_FILENO);
	//close(STDOUT_FILENO);
	//close(STDERR_FILENO);
	printf("\nfunction");
	//return errno;
	return 0;
	}

int main(int argc, char **argv) {
	peerdInit();  
	printf("\nmain"); 
}

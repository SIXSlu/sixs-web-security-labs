#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

/* Ops helper: the console "seal" check prints the sealed quarterly
 * file. The seal is root-only; this helper is the only reader. */
int main(void) {
    char buf[512];
    ssize_t n;
    int fd = open("/opt/dockops/flag_console.txt", O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 1;
    }
    n = read(fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        buf[n] = '\0';
        fputs(buf, stdout);
        fputc('\n', stdout);
    }
    close(fd);
    return 0;
}
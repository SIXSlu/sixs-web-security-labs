#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

/* Counter seal self-check: the desk tool prints the sealed boarding-pass
 * master so counter staff can confirm the seal material is in place.
 * The seal is root-only; this setuid helper is the only reader. Reading
 * the seal file directly is not possible for the kiosk account, so the
 * final flag is only recoverable by *executing* this helper. */
int main(void) {
    char buf[512];
    ssize_t n;
    int fd = open("/opt/faredesk/flag_seal.txt", O_RDONLY);
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
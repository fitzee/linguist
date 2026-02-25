#include <stdio.h>
#include <stdint.h>

void m2_stderr_write(const char *msg) {
    fputs(msg, stderr);
}

void m2_stdout_write(const char *msg) {
    fputs(msg, stdout);
}

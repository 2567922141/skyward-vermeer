#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
int main(void) {
    void *h = dlopen("/odm/lib64/libtouchreport.so", RTLD_NOW | RTLD_GLOBAL);
    if (!h) { printf("dlopen: %s\n", dlerror()); return 1; }
    void (*f)(void) = (void (*)(void))dlsym(h, "thp_daemon_main");
    if (!f) { printf("dlsym: %s\n", dlerror()); return 2; }
    printf("starting thp daemon\n"); fflush(stdout);
    f();
    return 0;
}

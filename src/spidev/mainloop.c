#include <stdlib.h>
#include <sys/epoll.h>

#include "mainloop.h"

#define MAXEVENTS 16

struct mainloop_t {
    int running;
    int efd;
    struct epoll_event events[MAXEVENTS];
};

int mainloop_init(struct mainloop_t *mainloop) {
    mainloop = calloc(1, sizeof(struct mainloop_t));
    if (mainloop == NULL) {
        perror("calloc");
        return 1;
    }

    mainloop->efd = epoll_create1(EPOLL_CLOEXEC);

    return 0;
}

void mainloop_delete(struct mainloop_t *mainloop) {
    free(mainloop);
}

void mainloop_run(struct mainloop_t *mainloop) {

    int nfds,n;

    if (!mainloop || mainloop->running) {
        return;
    }

    mainloop->running = 1;

    while (mainloop->running) {
        nfds = epoll_wait(mainloop->efd, mainloop->events, MAXEVENTS, -1);
        for (n = 0; n < nfds; ++n) {
            if (mainloop->events[n].events & EPOLLIN) {
                // Read from the file descriptor
            }
        }
    }
}

void mainloop_stop(struct mainloop_t *mainloop) {
    if (!mainloop) {
        return;
    }

    mainloop->running = 0;
}

void mainloop_add_fd(struct mainloop_t *mainloop, int fd, void (*callback)(int, int, void *), void *data) {
    if (!mainloop) {
        return;
    }

    
}
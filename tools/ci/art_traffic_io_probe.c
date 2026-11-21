/* Linux qualification observer for the launched Godot process only.
 * Count libc archive I/O without ptrace, changing bytes, or intercepting owner data.
 * Enable only with the harness-generated isolated ART_TRAFFIC_IO_RECEIPT path.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <fcntl.h>
#include <unistd.h>
#undef fread_unlocked
#undef fwrite_unlocked

static _Atomic unsigned char tracked[65536];
static _Atomic uint64_t opens, reads, writes, read_bytes, written_bytes;

static void observe(FILE *file, const char *path) {
    if (!file) return;
    const int fd = fileno(file);
    if (fd < 0 || fd >= 65536) return;
    const int archive = path && strstr(path, "/art-traffic/") != NULL;
    atomic_store(&tracked[fd], archive);
    if (archive) atomic_fetch_add(&opens, 1);
}

FILE *fopen(const char *path, const char *mode) {
    FILE *(*next)(const char *, const char *) = dlsym(RTLD_NEXT, "fopen");
    FILE *file = next(path, mode);
    observe(file, path);
    return file;
}

FILE *fopen64(const char *path, const char *mode) {
    FILE *(*next)(const char *, const char *) = dlsym(RTLD_NEXT, "fopen64");
    FILE *file = next(path, mode);
    observe(file, path);
    return file;
}

static int watched(FILE *file) {
    const int fd = fileno(file);
    return fd >= 0 && fd < 65536 && atomic_load(&tracked[fd]);
}

#define OBSERVE_IO(NAME, COUNTER, BYTES) \
size_t NAME(void *data, size_t size, size_t count, FILE *file) { \
    size_t (*next)(void *, size_t, size_t, FILE *) = dlsym(RTLD_NEXT, #NAME); \
    const size_t completed = next(data, size, count, file); \
    if (watched(file)) { atomic_fetch_add(&COUNTER, 1); atomic_fetch_add(&BYTES, completed * size); } \
    return completed; \
}
OBSERVE_IO(fread, reads, read_bytes)
OBSERVE_IO(fread_unlocked, reads, read_bytes)

#define OBSERVE_WRITE(NAME) \
size_t NAME(const void *data, size_t size, size_t count, FILE *file) { \
    size_t (*next)(const void *, size_t, size_t, FILE *) = dlsym(RTLD_NEXT, #NAME); \
    const size_t completed = next(data, size, count, file); \
    if (watched(file)) { atomic_fetch_add(&writes, 1); atomic_fetch_add(&written_bytes, completed * size); } \
    return completed; \
}
OBSERVE_WRITE(fwrite)
OBSERVE_WRITE(fwrite_unlocked)

int fclose(FILE *file) {
    int (*next)(FILE *) = dlsym(RTLD_NEXT, "fclose");
    const int fd = fileno(file);
    if (fd >= 0 && fd < 65536) atomic_store(&tracked[fd], 0);
    return next(file);
}

__attribute__((destructor)) static void receipt(void) {
    const char *path = getenv("ART_TRAFFIC_IO_RECEIPT");
    if (!path || !*path) return;
    char buffer[512];
    const int count = snprintf(buffer, sizeof(buffer),
        "{\"opens\":%llu,\"read_calls\":%llu,\"write_calls\":%llu,\"read_bytes\":%llu,\"written_bytes\":%llu}\n",
        (unsigned long long)atomic_load(&opens), (unsigned long long)atomic_load(&reads),
        (unsigned long long)atomic_load(&writes), (unsigned long long)atomic_load(&read_bytes),
        (unsigned long long)atomic_load(&written_bytes));
    const int fd = syscall(SYS_openat, AT_FDCWD, path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd >= 0) { syscall(SYS_write, fd, buffer, count); syscall(SYS_close, fd); }
}

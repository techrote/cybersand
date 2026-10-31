/*
 * CyberSand #309 Linux driver-call diagnostic. NONQUALIFYING evidence.
 * No driver options, parameters, GL state, waits or forced draws are added.
 * Compile externally (root owns execution):
 *   cc -std=gnu11 -O2 -fPIC -shared -Wall -Wextra -Wl,-Bsymbolic-functions \
 *      -o gl_startup_trace.so gl_startup_trace.c -ldl -pthread
 *
 * Set CYBERSAND_GL_TRACE_DIR to an existing, dedicated output directory.
 * Ordinary imported GL/GLX symbols: LD_PRELOAD=/absolute/helper.so
 * Pinned Godot GLAD uses explicit dlsym(libGL handle, glXGetProcAddressARB),
 * which can bypass LD_PRELOAD. For that loader use INSTEAD:
 *   LD_AUDIT=/absolute/helper.so
 * The glibc audit hook substitutes only the named GL/GLX function pointers;
 * it never wraps dlsym, changes loader flags or changes RTLD_NEXT semantics.
 * Do not set LD_PRELOAD and LD_AUDIT to this helper simultaneously.
 *
 * Wall time is CLOCK_MONOTONIC; CPU is current-thread CPU only. End records
 * measure the real driver call and exclude logging/source-dump time. These
 * timings do not account for CPU consumed by unwrapped driver worker threads.
 * No symbolized call-stack attribution is supplied by this helper alone.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <link.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef unsigned char GLubyte;
typedef char GLchar;
typedef void (*GLProc)(void);
typedef GLProc (*GetProc)(const GLubyte *);

#define TRACE_LIMIT 10000UL
#define SLOW_NS UINT64_C(10000000)
#define EARLY_DRAW_LIMIT 64UL
#define MAX_DUMPS 512UL
#define MAX_SOURCE_BYTES (UINT64_C(8) * 1024 * 1024)
#define MAX_TOTAL_SOURCE_BYTES (UINT64_C(64) * 1024 * 1024)
#define GL_COMPILE_STATUS 0x8B81U
#define GL_LINK_STATUS 0x8B82U

static pthread_once_t init_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t output_lock = PTHREAD_MUTEX_INITIALIZER;
static int directory_fd = -1;
static int events_fd = -1;
static _Atomic unsigned long attempted_events;
static _Atomic unsigned long dropped_events;
static _Atomic unsigned long call_sequence;
static _Atomic unsigned long draw_sequence;
static _Atomic unsigned long dump_count;
static _Atomic unsigned long dump_skips;
static _Atomic uint64_t dump_bytes;
static __thread unsigned int in_instrumentation;
static __thread GLuint current_program;

static _Atomic uintptr_t real_glXGetProcAddress;
static _Atomic uintptr_t real_glXGetProcAddressARB;
static _Atomic uintptr_t real_glShaderSource;
static _Atomic uintptr_t real_glCompileShader;
static _Atomic uintptr_t real_glAttachShader;
static _Atomic uintptr_t real_glLinkProgram;
static _Atomic uintptr_t real_glUseProgram;
static _Atomic uintptr_t real_glDrawArrays;
static _Atomic uintptr_t real_glDrawElements;
static _Atomic uintptr_t real_glDrawArraysInstanced;
static _Atomic uintptr_t real_glDrawElementsInstanced;
static _Atomic uintptr_t real_glGetShaderiv;
static _Atomic uintptr_t real_glGetProgramiv;

GLProc glXGetProcAddress(const GLubyte *name);
GLProc glXGetProcAddressARB(const GLubyte *name);
void glShaderSource(GLuint shader, GLsizei count, const GLchar *const *strings, const GLint *lengths);
void glCompileShader(GLuint shader);
void glAttachShader(GLuint program, GLuint shader);
void glLinkProgram(GLuint program);
void glUseProgram(GLuint program);
void glDrawArrays(GLenum mode, GLint first, GLsizei count);
void glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices);
void glDrawArraysInstanced(GLenum mode, GLint first, GLsizei count, GLsizei instances);
void glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instances);
void glGetShaderiv(GLuint shader, GLenum pname, GLint *params);
void glGetProgramiv(GLuint program, GLenum pname, GLint *params);

static uint64_t ns(clockid_t clock) {
    struct timespec value = {0, 0};
    if (clock_gettime(clock, &value) != 0) return 0;
    return (uint64_t)value.tv_sec * UINT64_C(1000000000) + (uint64_t)value.tv_nsec;
}

static bool write_all(int fd, const void *buffer, size_t length) {
    const char *cursor = (const char *)buffer;
    while (length != 0) {
        ssize_t count = write(fd, cursor, length);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return false;
        cursor += (size_t)count;
        length -= (size_t)count;
    }
    return true;
}

static void initialize(void) {
    const char *directory = getenv("CYBERSAND_GL_TRACE_DIR");
    if (directory == NULL || directory[0] == '\0') return;
    directory_fd = open(directory, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (directory_fd < 0) return;
    char filename[96];
    (void)snprintf(filename, sizeof filename, "gl-startup.%ld.jsonl", (long)getpid());
    events_fd = openat(directory_fd, filename,
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    /* Exclusive names prevent accidentally appending to another process/run. */
    if (events_fd < 0) {
        close(directory_fd);
        directory_fd = -1;
    }
}

static bool active(void) {
    pthread_once(&init_once, initialize);
    return events_fd >= 0 && in_instrumentation == 0;
}

/* Fixed/constructed ASCII arguments only. No arbitrary shader/source text is
 * ever interpolated into JSON. No output mutex is held during a driver call. */
static void event(const char *format, ...) {
    if (!active()) return;
    unsigned long sequence = atomic_fetch_add(&attempted_events, 1) + 1;
    if (sequence > TRACE_LIMIT) {
        atomic_fetch_add(&dropped_events, 1);
        return;
    }
    int saved_errno = errno;
    in_instrumentation++;
    char line[2048];
    int head = snprintf(line, sizeof line,
        "{\"event_index\":%lu,\"pid\":%ld,\"tid\":%ld,\"wall_ns\":%" PRIu64
        ",\"thread_cpu_ns\":%" PRIu64 ",",
        sequence, (long)getpid(), (long)syscall(SYS_gettid),
        ns(CLOCK_MONOTONIC), ns(CLOCK_THREAD_CPUTIME_ID));
    if (head >= 0 && (size_t)head < sizeof line - 3) {
        va_list args;
        va_start(args, format);
        int body = vsnprintf(line + head, sizeof line - (size_t)head - 3, format, args);
        va_end(args);
        if (body >= 0 && (size_t)body < sizeof line - (size_t)head - 3) {
            size_t used = (size_t)head + (size_t)body;
            line[used++] = '}';
            line[used++] = '\n';
            pthread_mutex_lock(&output_lock);
            (void)write_all(events_fd, line, used);
            pthread_mutex_unlock(&output_lock);
        } else {
            atomic_fetch_add(&dropped_events, 1);
        }
    }
    in_instrumentation--;
    errno = saved_errno;
}

__attribute__((constructor)) static void start_trace(void) {
    event("\"event\":\"header\",\"schema\":\"cybersand-gl-startup-v1\","
          "\"scope\":\"NONQUALIFYING driver-call instrumentation\","
          "\"clock\":\"CLOCK_MONOTONIC\",\"cpu_clock\":\"CLOCK_THREAD_CPUTIME_ID\","
          "\"max_events\":%lu,\"slow_threshold_ns\":%" PRIu64 ","
          "\"early_draw_begin_limit\":%lu,\"max_source_dumps\":%lu,"
          "\"max_total_source_bytes\":%" PRIu64,
          TRACE_LIMIT, SLOW_NS, EARLY_DRAW_LIMIT, MAX_DUMPS, MAX_TOTAL_SOURCE_BYTES);
}

__attribute__((destructor)) static void finish_trace(void) {
    /* One terminal record is allowed beyond the 10k ordinary-event cap. */
    if (events_fd < 0) return;
    char line[512];
    int length = snprintf(line, sizeof line,
        "{\"event\":\"footer\",\"pid\":%ld,\"attempted_events\":%lu,"
        "\"dropped_events\":%lu,\"source_dump_attempts\":%lu,"
        "\"source_dump_skips\":%lu,\"source_bytes_reserved\":%" PRIu64 ","
        "\"draw_calls_observed\":%lu}\n",
        (long)getpid(), atomic_load(&attempted_events), atomic_load(&dropped_events),
        atomic_load(&dump_count), atomic_load(&dump_skips), atomic_load(&dump_bytes),
        atomic_load(&draw_sequence));
    if (length > 0 && (size_t)length < sizeof line) {
        pthread_mutex_lock(&output_lock);
        (void)write_all(events_fd, line, (size_t)length);
        pthread_mutex_unlock(&output_lock);
    }
    /* Do not close descriptors while a late driver destructor could still emit.
     * Process exit reclaims these; no worker synchronization is introduced. */
}

static void *required(_Atomic uintptr_t *slot, const char *name, void *wrapper) {
    uintptr_t value = atomic_load(slot);
    if (value != 0) return (void *)value;
    void *address = dlsym(RTLD_NEXT, name);
    value = atomic_load(slot); /* LD_AUDIT may have installed it during dlsym. */
    if (value != 0) return (void *)value;
    if (address == wrapper) address = NULL;
    if (address == NULL && strncmp(name, "glXGetProcAddress", 17) != 0) {
        uintptr_t resolver = atomic_load(&real_glXGetProcAddressARB);
        if (!resolver) resolver = atomic_load(&real_glXGetProcAddress);
        if (resolver) address = (void *)((GetProc)resolver)((const GLubyte *)name);
    }
    if (address != NULL && address != wrapper) {
        uintptr_t empty = 0;
        atomic_compare_exchange_strong(slot, &empty, (uintptr_t)address);
        return (void *)atomic_load(slot);
    }
    event("\"event\":\"instrumentation_error\",\"reason\":\"original_symbol_unresolved\",\"call\":\"%s\"", name);
    /* A diagnostic cannot invent a GL success or silently omit a driver call. */
    _exit(126);
}

/* If a provider returns a different real function pointer for a name that was
 * already wrapped, return the NEW REAL pointer unwrapped. Never redirect it to
 * a prior provider, and never replace the destination of existing wrappers. */
static void *install(_Atomic uintptr_t *slot, void *address, void *wrapper, const char *name) {
    if (address == NULL || address == wrapper) return address;
    uintptr_t empty = 0;
    if (atomic_compare_exchange_strong(slot, &empty, (uintptr_t)address)
            || empty == (uintptr_t)address) return wrapper;
    event("\"event\":\"instrumentation_bypass\",\"reason\":\"provider_pointer_changed\",\"call\":\"%s\"", name);
    return address;
}

static void *map_symbol(const char *name, void *address) {
    if (name == NULL || address == NULL) return address;
#define HOOK(symbol) if (strcmp(name, #symbol) == 0) return install(&real_##symbol, address, (void *)symbol, #symbol)
    HOOK(glXGetProcAddress);
    HOOK(glXGetProcAddressARB);
    HOOK(glShaderSource);
    HOOK(glCompileShader);
    HOOK(glAttachShader);
    HOOK(glLinkProgram);
    HOOK(glUseProgram);
    HOOK(glDrawArrays);
    HOOK(glDrawElements);
    HOOK(glDrawArraysInstanced);
    HOOK(glDrawElementsInstanced);
    HOOK(glGetShaderiv);
    HOOK(glGetProgramiv);
#undef HOOK
    return address;
}

GLProc glXGetProcAddress(const GLubyte *name) {
    GetProc original = (GetProc)required(&real_glXGetProcAddress, "glXGetProcAddress", (void *)glXGetProcAddress);
    GLProc address = original(name);
    return (GLProc)map_symbol((const char *)name, (void *)address);
}
GLProc glXGetProcAddressARB(const GLubyte *name) {
    GetProc original = (GetProc)required(&real_glXGetProcAddressARB, "glXGetProcAddressARB", (void *)glXGetProcAddressARB);
    GLProc address = original(name);
    return (GLProc)map_symbol((const char *)name, (void *)address);
}

/* glibc ELF audit route: explicit dlsym(handle, name) retains its original
 * provider lookup. Only that exact resulting GL pointer is wrapped. */
unsigned int la_version(unsigned int version) {
    return version >= LAV_CURRENT ? LAV_CURRENT : version;
}
unsigned int la_objopen(struct link_map *map, Lmid_t namespace_id, uintptr_t *cookie) {
    (void)map; (void)namespace_id; (void)cookie;
    return LA_FLG_BINDTO | LA_FLG_BINDFROM;
}
uintptr_t la_symbind64(Elf64_Sym *symbol, unsigned int index,
        uintptr_t *ref_cookie, uintptr_t *def_cookie, unsigned int *flags, const char *name) {
    (void)index; (void)ref_cookie; (void)def_cookie; (void)flags;
    return (uintptr_t)map_symbol(name, (void *)(uintptr_t)symbol->st_value);
}

typedef struct {
    unsigned long id;
    uint64_t started_wall;
    uint64_t started_cpu;
    const char *name;
    GLuint shader;
    GLuint program;
    GLenum parameter;
    GLsizei count;
    GLsizei instances;
} Call;

static Call begin_call(const char *name, GLuint shader, GLuint program, GLenum parameter,
        GLsizei count, GLsizei instances, bool emit_begin) {
    Call call = {.id = atomic_fetch_add(&call_sequence, 1) + 1,
        .name = name, .shader = shader, .program = program, .parameter = parameter,
        .count = count, .instances = instances};
    if (emit_begin) event("\"event\":\"begin\",\"call\":\"%s\",\"call_id\":%lu,"
        "\"shader\":%u,\"program\":%u,\"parameter\":%u,\"count\":%d,\"instances\":%d",
        name, call.id, shader, program, parameter, count, instances);
    call.started_wall = ns(CLOCK_MONOTONIC);
    call.started_cpu = ns(CLOCK_THREAD_CPUTIME_ID);
    return call;
}

static void end_call(Call call, uint64_t ended_wall, uint64_t ended_cpu, bool always, int status) {
    uint64_t elapsed_wall = ended_wall >= call.started_wall ? ended_wall - call.started_wall : 0;
    uint64_t elapsed_cpu = ended_cpu >= call.started_cpu ? ended_cpu - call.started_cpu : 0;
    if (always || elapsed_wall >= SLOW_NS) event(
        "\"event\":\"end\",\"call\":\"%s\",\"call_id\":%lu,"
        "\"shader\":%u,\"program\":%u,\"parameter\":%u,\"count\":%d,\"instances\":%d,"
        "\"driver_started_wall_ns\":%" PRIu64 ",\"driver_ended_wall_ns\":%" PRIu64 ","
        "\"driver_wall_ns\":%" PRIu64 ",\"driver_thread_cpu_ns\":%" PRIu64 ",\"status\":%d",
        call.name, call.id, call.shader, call.program, call.parameter, call.count, call.instances,
        call.started_wall, ended_wall, elapsed_wall, elapsed_cpu, status);
}

static bool reserve_source(uint64_t bytes) {
    uint64_t used = atomic_load(&dump_bytes);
    while (bytes <= MAX_TOTAL_SOURCE_BYTES && used <= MAX_TOTAL_SOURCE_BYTES - bytes) {
        if (atomic_compare_exchange_weak(&dump_bytes, &used, used + bytes)) return true;
    }
    return false;
}

static void dump_source(GLuint shader, GLsizei count, const GLchar *const *strings, const GLint *lengths) {
    if (!active()) return;
    unsigned long sequence = atomic_fetch_add(&dump_count, 1) + 1;
    uint64_t total = 0;
    bool valid = count >= 0 && count <= 4096 && (count == 0 || strings != NULL);
    if (valid) for (GLsizei i = 0; i < count; i++) {
        if (strings[i] == NULL) { valid = false; break; }
        size_t length = lengths != NULL && lengths[i] >= 0 ? (size_t)lengths[i] : strlen(strings[i]);
        if (length > MAX_SOURCE_BYTES || total > MAX_SOURCE_BYTES - length) { valid = false; break; }
        total += length;
    }
    if (!valid || sequence > MAX_DUMPS || !reserve_source(total)) {
        atomic_fetch_add(&dump_skips, 1);
        event("\"event\":\"shader_source\",\"shader\":%u,\"source_sequence\":%lu,"
              "\"parts\":%d,\"dumped\":false,\"reason\":\"invalid_or_bounded_source_dump\"",
              shader, sequence, count);
        return;
    }
    char filename[128];
    (void)snprintf(filename, sizeof filename, "shader.%ld.%u.%lu.glsl", (long)getpid(), shader, sequence);
    int fd = openat(directory_fd, filename, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    bool complete = fd >= 0;
    if (complete) {
        for (GLsizei i = 0; i < count; i++) {
            size_t length = lengths != NULL && lengths[i] >= 0 ? (size_t)lengths[i] : strlen(strings[i]);
            if (!write_all(fd, strings[i], length)) { complete = false; break; }
        }
        if (close(fd) != 0) complete = false;
    }
    if (!complete) atomic_fetch_add(&dump_skips, 1);
    /* Exact concatenation, no inserted separators/newlines and no truncation.
     * On failure a partial file remains explicitly marked incomplete. */
    event("\"event\":\"shader_source\",\"shader\":%u,\"source_sequence\":%lu,"
          "\"parts\":%d,\"bytes\":%" PRIu64 ",\"dumped\":%s,\"file\":\"%s\"",
          shader, sequence, count, total, complete ? "true" : "false", filename);
}

#define ORIGINAL(symbol, type) type original = (type)required(&real_##symbol, #symbol, (void *)symbol)
#define CAPTURE_END(call, always, status) do { \
    uint64_t end_wall = ns(CLOCK_MONOTONIC); \
    uint64_t end_cpu = ns(CLOCK_THREAD_CPUTIME_ID); \
    int end_errno = errno; \
    end_call((call), end_wall, end_cpu, (always), (status)); \
    errno = end_errno; \
} while (0)

void glShaderSource(GLuint shader, GLsizei count, const GLchar *const *strings, const GLint *lengths) {
    typedef void (*Fn)(GLuint, GLsizei, const GLchar *const *, const GLint *);
    ORIGINAL(glShaderSource, Fn);
    if (!active()) { original(shader, count, strings, lengths); return; }
    int prior_errno = errno;
    dump_source(shader, count, strings, lengths);
    Call call = begin_call("glShaderSource", shader, 0, 0, count, 0, true);
    errno = prior_errno;
    original(shader, count, strings, lengths);
    CAPTURE_END(call, true, INT_MIN);
}
void glCompileShader(GLuint shader) {
    typedef void (*Fn)(GLuint); ORIGINAL(glCompileShader, Fn);
    if (!active()) { original(shader); return; }
    Call call = begin_call("glCompileShader", shader, 0, 0, 0, 0, true);
    original(shader);
    CAPTURE_END(call, true, INT_MIN);
}
void glAttachShader(GLuint program, GLuint shader) {
    typedef void (*Fn)(GLuint, GLuint); ORIGINAL(glAttachShader, Fn);
    if (!active()) { original(program, shader); return; }
    Call call = begin_call("glAttachShader", shader, program, 0, 0, 0, true);
    original(program, shader);
    CAPTURE_END(call, true, INT_MIN);
}
void glLinkProgram(GLuint program) {
    typedef void (*Fn)(GLuint); ORIGINAL(glLinkProgram, Fn);
    if (!active()) { original(program); return; }
    Call call = begin_call("glLinkProgram", 0, program, 0, 0, 0, true);
    original(program);
    CAPTURE_END(call, true, INT_MIN);
}
void glUseProgram(GLuint program) {
    typedef void (*Fn)(GLuint); ORIGINAL(glUseProgram, Fn);
    if (!active()) { original(program); current_program = program; return; }
    bool changed = current_program != program;
    Call call = begin_call("glUseProgram", 0, program, 0, 0, 0, false);
    original(program);
    current_program = program;
    CAPTURE_END(call, changed, INT_MIN);
}
void glGetShaderiv(GLuint shader, GLenum pname, GLint *params) {
    typedef void (*Fn)(GLuint, GLenum, GLint *); ORIGINAL(glGetShaderiv, Fn);
    if (!active() || pname != GL_COMPILE_STATUS) { original(shader, pname, params); return; }
    Call call = begin_call("glGetShaderiv", shader, 0, pname, 0, 0, true);
    original(shader, pname, params);
    CAPTURE_END(call, true, params != NULL ? *params : INT_MIN);
}
void glGetProgramiv(GLuint program, GLenum pname, GLint *params) {
    typedef void (*Fn)(GLuint, GLenum, GLint *); ORIGINAL(glGetProgramiv, Fn);
    if (!active() || pname != GL_LINK_STATUS) { original(program, pname, params); return; }
    Call call = begin_call("glGetProgramiv", 0, program, pname, 0, 0, true);
    original(program, pname, params);
    CAPTURE_END(call, true, params != NULL ? *params : INT_MIN);
}
void glDrawArrays(GLenum mode, GLint first, GLsizei count) {
    typedef void (*Fn)(GLenum, GLint, GLsizei); ORIGINAL(glDrawArrays, Fn);
    if (!active()) { original(mode, first, count); return; }
    bool early = atomic_fetch_add(&draw_sequence, 1) < EARLY_DRAW_LIMIT;
    Call call = begin_call("glDrawArrays", 0, current_program, mode, count, 1, early);
    original(mode, first, count);
    CAPTURE_END(call, early, INT_MIN);
}
void glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices) {
    typedef void (*Fn)(GLenum, GLsizei, GLenum, const void *); ORIGINAL(glDrawElements, Fn);
    if (!active()) { original(mode, count, type, indices); return; }
    bool early = atomic_fetch_add(&draw_sequence, 1) < EARLY_DRAW_LIMIT;
    Call call = begin_call("glDrawElements", 0, current_program, mode, count, 1, early);
    original(mode, count, type, indices);
    CAPTURE_END(call, early, INT_MIN);
}
void glDrawArraysInstanced(GLenum mode, GLint first, GLsizei count, GLsizei instances) {
    typedef void (*Fn)(GLenum, GLint, GLsizei, GLsizei); ORIGINAL(glDrawArraysInstanced, Fn);
    if (!active()) { original(mode, first, count, instances); return; }
    bool early = atomic_fetch_add(&draw_sequence, 1) < EARLY_DRAW_LIMIT;
    Call call = begin_call("glDrawArraysInstanced", 0, current_program, mode, count, instances, early);
    original(mode, first, count, instances);
    CAPTURE_END(call, early, INT_MIN);
}
void glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void *indices, GLsizei instances) {
    typedef void (*Fn)(GLenum, GLsizei, GLenum, const void *, GLsizei); ORIGINAL(glDrawElementsInstanced, Fn);
    if (!active()) { original(mode, count, type, indices, instances); return; }
    bool early = atomic_fetch_add(&draw_sequence, 1) < EARLY_DRAW_LIMIT;
    Call call = begin_call("glDrawElementsInstanced", 0, current_program, mode, count, instances, early);
    original(mode, count, type, indices, instances);
    CAPTURE_END(call, early, INT_MIN);
}

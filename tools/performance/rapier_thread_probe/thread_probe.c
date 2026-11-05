/* Windows diagnostic only. No simulation, renderer or production binding calls.
 * PackedInt64Array: schema, thread, qpc_lo, qpc_hi, qpc_frequency,
 * kernel_100ns, user_100ns, thread_cycles, cpu_error, cycles_error. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "gdextension_interface.h"

typedef union { uint64_t align; unsigned char bytes[32]; } Storage;
static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithUtf8Chars string_name_new;
static GDExtensionInterfaceClassdbRegisterExtensionClass4 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionPtrConstructor array_new, string_new;
static GDExtensionPtrDestructor array_destroy, name_destroy, string_destroy;
static GDExtensionPtrBuiltInMethod array_resize;
static GDExtensionInterfacePackedInt64ArrayOperatorIndex array_index;
static GDExtensionVariantFromTypeConstructorFunc array_to_variant;
static Storage class_name;
static LARGE_INTEGER frequency;

static uint64_t filetime_value(FILETIME v) {
    return ((uint64_t)v.dwHighDateTime << 32) | v.dwLowDateTime;
}

static void sample_array(void *out) {
    int64_t count = 10, resize_result = 0;
    const void *args[] = { &count };
    array_new(out, NULL);
    array_resize(out, args, &resize_result, 1);
    int64_t *v = array_index(out, 0);
    FILETIME created = {0}, exited = {0}, kernel = {0}, user = {0};
    LARGE_INTEGER low = {0}, high = {0};
    ULONG64 cycles = 0;
    DWORD cpu_error = 0, cycles_error = 0;
    DWORD thread_id = GetCurrentThreadId();
    /* Allocation is complete before measuring the calling thread. */
    QueryPerformanceCounter(&low);
    if (!GetThreadTimes(GetCurrentThread(), &created, &exited, &kernel, &user))
        cpu_error = GetLastError();
    if (!QueryThreadCycleTime(GetCurrentThread(), &cycles))
        cycles_error = GetLastError();
    QueryPerformanceCounter(&high);
    v[0] = 1; v[1] = thread_id;
    v[2] = low.QuadPart; v[3] = high.QuadPart; v[4] = frequency.QuadPart;
    v[5] = (int64_t)filetime_value(kernel); v[6] = (int64_t)filetime_value(user);
    v[7] = (int64_t)cycles; v[8] = cpu_error; v[9] = cycles_error;
}

static void sample_call(void *userdata, GDExtensionClassInstancePtr instance,
        const GDExtensionConstVariantPtr *args, GDExtensionInt count,
        GDExtensionVariantPtr result, GDExtensionCallError *error) {
    (void)userdata; (void)instance; (void)args;
    if (count != 0) {
        error->error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        error->argument = 0; error->expected = 0; return;
    }
    Storage out;
    sample_array(&out);
    array_to_variant(result, &out);
    array_destroy(&out);
    error->error = GDEXTENSION_CALL_OK;
}

static void sample_ptrcall(void *userdata, GDExtensionClassInstancePtr instance,
        const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    (void)userdata; (void)instance; (void)args;
    sample_array(result);
}

static void free_instance(void *userdata, GDExtensionClassInstancePtr instance) {
    (void)userdata; (void)instance;
}

static void initialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    Storage parent_name, method_name, empty_name, empty_string;
    string_name_new(&class_name, "CyberRapierThreadProbe");
    string_name_new(&parent_name, "RefCounted");
    string_name_new(&method_name, "sample");
    string_name_new(&empty_name, "");
    string_new(&empty_string, NULL);
    GDExtensionClassCreationInfo4 info;
    memset(&info, 0, sizeof(info));
    info.is_abstract = 1; info.is_exposed = 1;
    info.free_instance_func = free_instance;
    register_class(library, &class_name, &parent_name, &info);
    GDExtensionPropertyInfo ret;
    memset(&ret, 0, sizeof(ret));
    ret.type = GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY;
    ret.name = &empty_name; ret.class_name = &empty_name;
    ret.hint_string = &empty_string;
    GDExtensionClassMethodInfo method;
    memset(&method, 0, sizeof(method));
    method.name = &method_name; method.call_func = sample_call;
    method.ptrcall_func = sample_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_STATIC;
    method.has_return_value = 1; method.return_value_info = &ret;
    register_method(library, &class_name, &method);
    string_destroy(&empty_string);
    name_destroy(&empty_name); name_destroy(&method_name); name_destroy(&parent_name);
}

static void deinitialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    unregister_class(library, &class_name);
    name_destroy(&class_name);
}

__declspec(dllexport) GDExtensionBool rapier_thread_probe_init(
        GDExtensionInterfaceGetProcAddress get, GDExtensionClassLibraryPtr lib,
        GDExtensionInitialization *init) {
    library = lib;
#define LOAD(v, type, name) v = (type)get(name); if (!v) return 0
    LOAD(string_name_new, GDExtensionInterfaceStringNameNewWithUtf8Chars, "string_name_new_with_utf8_chars");
    LOAD(register_class, GDExtensionInterfaceClassdbRegisterExtensionClass4, "classdb_register_extension_class4");
    LOAD(register_method, GDExtensionInterfaceClassdbRegisterExtensionClassMethod, "classdb_register_extension_class_method");
    LOAD(unregister_class, GDExtensionInterfaceClassdbUnregisterExtensionClass, "classdb_unregister_extension_class");
    GDExtensionInterfaceVariantGetPtrConstructor constructor;
    GDExtensionInterfaceVariantGetPtrDestructor destructor;
    GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin;
    GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
    LOAD(constructor, GDExtensionInterfaceVariantGetPtrConstructor, "variant_get_ptr_constructor");
    LOAD(destructor, GDExtensionInterfaceVariantGetPtrDestructor, "variant_get_ptr_destructor");
    LOAD(builtin, GDExtensionInterfaceVariantGetPtrBuiltinMethod, "variant_get_ptr_builtin_method");
    LOAD(from_type, GDExtensionInterfaceGetVariantFromTypeConstructor, "get_variant_from_type_constructor");
    LOAD(array_index, GDExtensionInterfacePackedInt64ArrayOperatorIndex, "packed_int64_array_operator_index");
#undef LOAD
    array_new = constructor(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY, 0);
    string_new = constructor(GDEXTENSION_VARIANT_TYPE_STRING, 0);
    array_destroy = destructor(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    name_destroy = destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    string_destroy = destructor(GDEXTENSION_VARIANT_TYPE_STRING);
    array_to_variant = from_type(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);
    Storage resize_name;
    string_name_new(&resize_name, "resize");
    array_resize = builtin(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY, &resize_name, 848867239);
    name_destroy(&resize_name);
    if (!array_new || !array_destroy || !name_destroy || !array_to_variant || !array_resize) return 0;
    if (!QueryPerformanceFrequency(&frequency)) return 0;
    init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    init->initialize = initialize; init->deinitialize = deinitialize; init->userdata = NULL;
    return 1;
}

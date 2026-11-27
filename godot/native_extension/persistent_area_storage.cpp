#include "persistent_area_storage.hpp"

#include <godot_cpp/classes/hashing_context.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <filesystem>
#include <mutex>
#include <vector>
#include <cerrno>
#include <cstring>
#include <chrono>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#elif !defined(__EMSCRIPTEN__)
#include <dirent.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

namespace godot {
namespace {
constexpr int64_t file_limit = 64LL * 1024 * 1024;
constexpr int64_t profile_limit = 512LL * 1024 * 1024;
constexpr int64_t entry_limit = 64;

struct PhaseTimer {
    int64_t& elapsed;
    std::chrono::steady_clock::time_point started = std::chrono::steady_clock::now();
    ~PhaseTimer() {
        elapsed += std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - started).count();
    }
};

Dictionary failure(const String& error, bool published = false) {
    Dictionary result;
    result["ok"] = false;
    result["error"] = error;
    result["published"] = published;
    return result;
}
Dictionary success() { Dictionary result; result["ok"] = true; return result; }
String sha256(const PackedByteArray& bytes) {
    Ref<HashingContext> hash;
    hash.instantiate();
    hash->start(HashingContext::HASH_SHA256);
    if (!bytes.is_empty()) hash->update(bytes);
    return hash->finish().hex_encode();
}
bool valid_name(const String& name) {
    if (name.is_empty() || name.length() > 128 || name == "." || name == ".." ||
        name == "profile.lock" || name.ends_with(".")) return false;
    for (int64_t i = 0; i < name.length(); ++i) {
        const auto c = name[i];
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.'))
            return false;
    }
    // Windows reserved device names are refused on both platforms.
    const auto stem = name.get_basename();
    if (stem == "con" || stem == "prn" || stem == "aux" || stem == "nul") return false;
    if (stem.length() == 4 && (stem.begins_with("com") || stem.begins_with("lpt")) &&
        stem[3] >= '1' && stem[3] <= '9') return false;
    return true;
}
bool valid_digest(const String& value) {
    if (value.is_empty()) return true;
    if (value.length() != 64) return false;
    for (int64_t i = 0; i < value.length(); ++i)
        if (!((value[i] >= '0' && value[i] <= '9') || (value[i] >= 'a' && value[i] <= 'f'))) return false;
    return true;
}
#if defined(_WIN32)
String os_error(const char* operation) {
    return String(operation) + " (Windows error " + String::num_uint64(GetLastError()) + ")";
}
std::wstring native_path(const String& path) {
    const String p = path.replace("\\", "/");
    const String extended = p.begins_with("//") ? String("\\\\?\\UNC\\") + p.substr(2).replace("/", "\\")
        : String("\\\\?\\") + p.replace("/", "\\");
    const auto utf16 = extended.utf16();
    return {utf16.ptr(), utf16.ptr() + utf16.length()};
}
bool regular_handle(HANDLE handle, uint64_t& size) {
    BY_HANDLE_FILE_INFORMATION info{};
    if (!GetFileInformationByHandle(handle, &info)) return false;
    if (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DEVICE))
        return false;
    if (info.nNumberOfLinks != 1) return false;
    size = (uint64_t(info.nFileSizeHigh) << 32) | info.nFileSizeLow;
    return true;
}
#elif !defined(__EMSCRIPTEN__)
String os_error(const char* operation) { return String(operation) + ": " + std::strerror(errno); }
#endif
} // namespace

struct CyberPersistentAreaStorage::Impl {
    std::mutex mutex;
    String root;
#if defined(_WIN32)
    HANDLE lock = INVALID_HANDLE_VALUE;
    HANDLE directory = INVALID_HANDLE_VALUE;
#elif !defined(__EMSCRIPTEN__)
    int lock = -1;
    int directory = -1;
#endif
    bool acquired = false;
    // Guarded by this storage owner's mutex, including the telemetry snapshot.
    // No global counters can mix this profile with another application's work.
    int64_t read_requests = 0, read_open_attempts = 0, read_system_calls = 0, read_bytes = 0;
    int64_t checkpoint_read_requests = 0, checkpoint_read_bytes = 0;
    int64_t write_requests = 0, write_create_attempts = 0, write_system_calls = 0, write_bytes = 0;
    int64_t checkpoint_write_bytes = 0, file_flush_calls = 0, directory_flush_calls = 0;
    int64_t publication_requests = 0, publication_calls = 0, removal_requests = 0, enumeration_requests = 0;
    int64_t read_us = 0, write_us = 0, publication_us = 0, flush_us = 0, hash_us = 0, enumeration_us = 0;

    String hash(const PackedByteArray& bytes) {
        PhaseTimer timer{hash_us};
        return sha256(bytes);
    }

    void read_count(const String& name, int64_t bytes) {
        read_bytes += bytes;
        if (name.begins_with("area-") && name.ends_with(".cypa")) checkpoint_read_bytes += bytes;
    }

    void write_count(const String& name, int64_t bytes) {
        write_bytes += bytes;
        if (name.begins_with("area-") && name.ends_with(".cypa")) checkpoint_write_bytes += bytes;
    }

    String directory_identity() {
#if !defined(_WIN32) && !defined(__EMSCRIPTEN__)
        struct stat held{}, named{};
        const auto path = root.utf8();
        if (::fstat(directory, &held) != 0 || ::lstat(path.get_data(), &named) != 0 ||
            !S_ISDIR(named.st_mode) || held.st_dev != named.st_dev || held.st_ino != named.st_ino)
            return "Persistent profile directory moved or became unavailable; prior files retained";
#endif
        return {};
    }

    String sync_file(const String& name) {
        PhaseTimer timer{flush_us};
#if defined(_WIN32)
        const auto path = native_path(root.path_join(name));
        HANDLE file = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
                                 FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
        if (file == INVALID_HANDLE_VALUE) return os_error("Cannot open persistent file for flush");
        uint64_t length = 0;
        bool okay = regular_handle(file, length);
        if (okay) { ++file_flush_calls; okay = FlushFileBuffers(file); }
        const auto error = okay ? String() : os_error("Cannot flush existing persistent file");
        CloseHandle(file);
        return error;
#elif !defined(__EMSCRIPTEN__)
        const auto utf8 = name.utf8();
        const int file = ::openat(directory, utf8.get_data(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
        if (file == -1) return os_error("Cannot open persistent file for flush");
        ++file_flush_calls;
        const auto error = ::fsync(file) == 0 ? String() : os_error("Cannot flush existing persistent file");
        ::close(file);
        return error;
#else
        return "Persistent areas require the desktop native runtime";
#endif
    }

    void close() {
#if defined(_WIN32)
        if (lock != INVALID_HANDLE_VALUE) CloseHandle(lock);
        if (directory != INVALID_HANDLE_VALUE) CloseHandle(directory);
        lock = directory = INVALID_HANDLE_VALUE;
#elif !defined(__EMSCRIPTEN__)
        if (lock != -1) ::close(lock);
        if (directory != -1) ::close(directory);
        lock = directory = -1;
#endif
        acquired = false;
        root = String();
    }

    String sync_directory() {
#if defined(_WIN32)
        // Windows has no general directory-fsync equivalent admitted here.
        // Files use FlushFileBuffers, replacement uses WRITE_THROUGH. This is
        // process-crash/I/O qualification, not a hardware power-loss promise.
        return {};
#elif !defined(__EMSCRIPTEN__)
        PhaseTimer timer{flush_us};
        ++directory_flush_calls;
        if (::fsync(directory) != 0) return os_error("Cannot sync persistent profile directory");
#endif
        return {};
    }

    Dictionary read(const String& name, int64_t maximum_bytes) {
        PhaseTimer timer{read_us};
        ++read_requests;
        if (name.begins_with("area-") && name.ends_with(".cypa")) ++checkpoint_read_requests;
        if (!acquired) return failure("Persistent profile is not locked");
        if (const auto error = directory_identity(); !error.is_empty()) return failure(error);
        if (!valid_name(name) || maximum_bytes < 0 || maximum_bytes > file_limit)
            return failure("Persistent file name or read capacity is invalid");
        PackedByteArray bytes;
#if defined(_WIN32)
        const auto path = native_path(root.path_join(name));
        ++read_open_attempts;
        HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                                 FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
        if (file == INVALID_HANDLE_VALUE) {
            if (GetLastError() == ERROR_FILE_NOT_FOUND) { auto r = success(); r["exists"] = false; return r; }
            return failure(os_error("Cannot open persistent file"));
        }
        uint64_t length = 0;
        if (!regular_handle(file, length) || length > uint64_t(maximum_bytes)) {
            CloseHandle(file);
            return failure("Persistent file is not a bounded, unaliased regular file");
        }
        bytes.resize(int64_t(length));
        DWORD count = 0;
        BOOL read_ok = true;
        if (length != 0) { ++read_system_calls; read_ok = ReadFile(file, bytes.ptrw(), DWORD(length), &count, nullptr); }
        read_count(name,count);
        const auto error = read_ok && count == length ? String() : os_error("Cannot read complete persistent file");
        CloseHandle(file);
        if (!error.is_empty()) return failure(error);
#elif !defined(__EMSCRIPTEN__)
        const auto utf8 = name.utf8();
        ++read_open_attempts;
        const int file = ::openat(directory, utf8.get_data(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
        if (file == -1) {
            if (errno == ENOENT) { auto r = success(); r["exists"] = false; return r; }
            return failure(os_error("Cannot open persistent file"));
        }
        struct stat info{};
        if (::fstat(file, &info) != 0 || !S_ISREG(info.st_mode) || info.st_nlink != 1 ||
            info.st_size < 0 || info.st_size > maximum_bytes) {
            ::close(file);
            return failure("Persistent file is not a bounded, unaliased regular file");
        }
        bytes.resize(info.st_size);
        int64_t offset = 0;
        while (offset < bytes.size()) {
            ++read_system_calls;
            const auto count = ::read(file, bytes.ptrw() + offset, size_t(bytes.size() - offset));
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) { const auto error = os_error("Cannot read complete persistent file"); ::close(file); return failure(error); }
            offset += count;
            read_count(name,count);
        }
        uint8_t extra = 0;
        ++read_system_calls;
        const auto tail = ::read(file, &extra, 1);
        if (tail > 0) read_count(name,tail);
        ::close(file);
        if (tail != 0) return failure("Persistent file changed during read");
#else
        return failure("Persistent areas require the desktop native runtime");
#endif
        auto result = success();
        result["exists"] = true;
        result["bytes"] = bytes;
        result["sha256"] = hash(bytes);
        return result;
    }

    Dictionary inventory() {
        PhaseTimer timer{enumeration_us};
        ++enumeration_requests;
        if (!acquired) return failure("Persistent profile is not locked");
        if (const auto error = directory_identity(); !error.is_empty()) return failure(error);
        Array entries;
        int64_t total = 0;
#if defined(_WIN32)
        WIN32_FIND_DATAW found{};
        const auto pattern = native_path(root.path_join("*"));
        HANDLE search = FindFirstFileW(pattern.c_str(), &found);
        if (search == INVALID_HANDLE_VALUE) return failure(os_error("Cannot enumerate persistent profile"));
        do {
            const String name(found.cFileName);
            if (name == "." || name == ".." || name == "profile.lock") continue;
            const uint64_t size = (uint64_t(found.nFileSizeHigh) << 32) | found.nFileSizeLow;
            if (!valid_name(name) || (found.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DEVICE)) ||
                size > uint64_t(file_limit) || entries.size() >= entry_limit || total > profile_limit - int64_t(size)) {
                FindClose(search);
                return failure("Persistent profile exceeds its file/byte bounds or contains unsafe entries");
            }
            Dictionary item; item["name"] = name; item["bytes"] = int64_t(size); entries.push_back(item); total += int64_t(size);
        } while (FindNextFileW(search, &found));
        const auto enumeration_error = GetLastError();
        FindClose(search);
        if (enumeration_error != ERROR_NO_MORE_FILES) return failure("Persistent profile enumeration failed");
#elif !defined(__EMSCRIPTEN__)
        // openat gives a fresh stream position; dup would share the directory
        // offset and silently miss entries on a repeated inventory.
        const int scan = ::openat(directory, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (scan == -1) return failure(os_error("Cannot enumerate persistent profile"));
        DIR* listing = ::fdopendir(scan);
        if (!listing) { ::close(scan); return failure(os_error("Cannot enumerate persistent profile")); }
        errno = 0;
        while (auto* entry = ::readdir(listing)) {
            const String name = String::utf8(entry->d_name);
            if (name == "." || name == ".." || name == "profile.lock") continue;
            struct stat info{};
            if (!valid_name(name) || ::fstatat(directory, entry->d_name, &info, AT_SYMLINK_NOFOLLOW) != 0 ||
                !S_ISREG(info.st_mode) || info.st_nlink != 1 || info.st_size < 0 || info.st_size > file_limit ||
                entries.size() >= entry_limit || total > profile_limit - info.st_size) {
                ::closedir(listing);
                return failure("Persistent profile exceeds its file/byte bounds or contains unsafe entries");
            }
            Dictionary item; item["name"] = name; item["bytes"] = int64_t(info.st_size); entries.push_back(item); total += info.st_size;
            errno = 0;
        }
        const auto enumeration_error = errno;
        ::closedir(listing);
        if (enumeration_error != 0) return failure("Persistent profile enumeration failed");
#else
        return failure("Persistent areas require the desktop native runtime");
#endif
        auto result = success(); result["files"] = entries; result["bytes"] = total;
        return result;
    }
};

CyberPersistentAreaStorage::CyberPersistentAreaStorage() : impl_(std::make_unique<Impl>()) {}
CyberPersistentAreaStorage::~CyberPersistentAreaStorage() { impl_->close(); }

void CyberPersistentAreaStorage::_bind_methods() {
    ClassDB::bind_method(D_METHOD("acquire", "profile_directory"), &CyberPersistentAreaStorage::acquire);
    ClassDB::bind_method(D_METHOD("close_profile"), &CyberPersistentAreaStorage::close_profile);
    ClassDB::bind_method(D_METHOD("read_file", "name", "maximum_bytes"), &CyberPersistentAreaStorage::read_file);
    ClassDB::bind_method(D_METHOD("write_new", "name", "bytes"), &CyberPersistentAreaStorage::write_new);
    ClassDB::bind_method(D_METHOD("publish", "stage", "target", "expected_target_sha256", "expected_stage_sha256"), &CyberPersistentAreaStorage::publish);
    ClassDB::bind_method(D_METHOD("remove_file", "name"), &CyberPersistentAreaStorage::remove_file);
    ClassDB::bind_method(D_METHOD("list_files"), &CyberPersistentAreaStorage::list_files);
    ClassDB::bind_method(D_METHOD("telemetry"), &CyberPersistentAreaStorage::telemetry);
}

Dictionary CyberPersistentAreaStorage::acquire(const String& profile_directory) {
    std::lock_guard guard(impl_->mutex);
    if (impl_->acquired) return failure("Persistent profile is already locked by this owner");
    if (profile_directory.is_empty() || profile_directory.length() > 32000 || !profile_directory.is_absolute_path())
        return failure("Persistent profile requires a bounded absolute directory");
    for (int64_t i = 0; i < profile_directory.length(); ++i)
        if (profile_directory[i] == 0) return failure("Persistent profile path contains NUL");
#if defined(__EMSCRIPTEN__)
    return failure("Persistent areas require the desktop native runtime");
#else
    const auto root = profile_directory.simplify_path();
    std::error_code error;
#if defined(_WIN32)
    const auto path = native_path(root);
    std::filesystem::create_directories(std::filesystem::path(path), error);
#else
    const auto utf8 = root.utf8();
    std::filesystem::create_directories(std::filesystem::path(utf8.get_data()), error);
#endif
    if (error) return failure(String("Cannot create persistent profile: ") + error.message().c_str());
    impl_->root = root;
#if defined(_WIN32)
    const auto attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES || !(attributes & FILE_ATTRIBUTE_DIRECTORY) || (attributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
        impl_->close(); return failure("Persistent profile must be a directory without a reparse point");
    }
    // Deny directory deletion/rename while this owner publishes into it.
    impl_->directory = CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE,
        nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    const auto lock_path = native_path(root.path_join("profile.lock"));
    impl_->lock = CreateFileW(lock_path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_ALWAYS,
        FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    uint64_t lock_size = 0;
    if (impl_->directory == INVALID_HANDLE_VALUE || impl_->lock == INVALID_HANDLE_VALUE || !regular_handle(impl_->lock, lock_size)) {
        const auto why = os_error("Persistent profile is unavailable or owned by another process"); impl_->close(); return failure(why);
    }
#else
    impl_->directory = ::open(utf8.get_data(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (impl_->directory == -1) { const auto why = os_error("Cannot open persistent profile directory"); impl_->close(); return failure(why); }
    impl_->lock = ::openat(impl_->directory, "profile.lock", O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0600);
    struct stat lock_info{};
    if (impl_->lock == -1 || ::fstat(impl_->lock, &lock_info) != 0 || !S_ISREG(lock_info.st_mode) || lock_info.st_nlink != 1 ||
        ::flock(impl_->lock, LOCK_EX | LOCK_NB) != 0) {
        const auto why = os_error("Persistent profile is unavailable or owned by another process"); impl_->close(); return failure(why);
    }
#endif
    impl_->acquired = true;
    auto result = impl_->inventory();
    if (!bool(result["ok"])) { impl_->close(); return result; }
    result["directory"] = root;
    result["durability"] = "exclusive-process-lock; flushed-files; atomic-manifest-replacement; process-crash-qualified";
    return result;
#endif
}

void CyberPersistentAreaStorage::close_profile() { std::lock_guard guard(impl_->mutex); impl_->close(); }
Dictionary CyberPersistentAreaStorage::read_file(const String& name, int64_t maximum_bytes) {
    std::lock_guard guard(impl_->mutex); return impl_->read(name, maximum_bytes);
}
Dictionary CyberPersistentAreaStorage::list_files() { std::lock_guard guard(impl_->mutex); return impl_->inventory(); }

Dictionary CyberPersistentAreaStorage::telemetry() {
    std::lock_guard guard(impl_->mutex);
    Dictionary result;
    result["schema"] = 1;
    result["storage_owner_id"] = int64_t(get_instance_id());
    result["profile_directory"] = impl_->root;
    result["acquired"] = impl_->acquired;
    result["scope"] = "application filesystem calls including kernel-cache hits and integrity readback; not physical device I/O";
    result["timing_scope"] = "inclusive phases; read/write/publication/hash/flush durations can overlap and must not be summed";
#define CYPA_COUNTER(field) result[#field] = impl_->field
    CYPA_COUNTER(read_requests); CYPA_COUNTER(read_open_attempts); CYPA_COUNTER(read_system_calls); CYPA_COUNTER(read_bytes);
    CYPA_COUNTER(checkpoint_read_requests); CYPA_COUNTER(checkpoint_read_bytes);
    CYPA_COUNTER(write_requests); CYPA_COUNTER(write_create_attempts); CYPA_COUNTER(write_system_calls); CYPA_COUNTER(write_bytes);
    CYPA_COUNTER(checkpoint_write_bytes); CYPA_COUNTER(file_flush_calls); CYPA_COUNTER(directory_flush_calls);
    CYPA_COUNTER(publication_requests); CYPA_COUNTER(publication_calls); CYPA_COUNTER(removal_requests); CYPA_COUNTER(enumeration_requests);
    CYPA_COUNTER(read_us); CYPA_COUNTER(write_us); CYPA_COUNTER(publication_us); CYPA_COUNTER(flush_us);
    CYPA_COUNTER(hash_us); CYPA_COUNTER(enumeration_us);
#undef CYPA_COUNTER
    return result;
}

Dictionary CyberPersistentAreaStorage::write_new(const String& name, const PackedByteArray& bytes) {
    std::lock_guard guard(impl_->mutex);
    PhaseTimer timer{impl_->write_us};
    ++impl_->write_requests;
    if (!impl_->acquired || !valid_name(name) || bytes.size() > file_limit)
        return failure("Immutable persistent write has invalid lock, name or capacity");
    const auto existing = impl_->read(name, file_limit);
    if (!bool(existing["ok"])) return existing;
    if (bool(existing["exists"])) {
        const PackedByteArray previous = existing["bytes"];
        if (previous != bytes) return failure("Immutable persistent file already has different bytes");
        if (const auto error = impl_->sync_file(name); !error.is_empty()) return failure(error);
        if (const auto error = impl_->sync_directory(); !error.is_empty()) return failure(error);
        auto result = success(); result["sha256"] = impl_->hash(bytes); result["idempotent"] = true; return result;
    }
    const auto inventory = impl_->inventory();
    if (!bool(inventory["ok"])) return inventory;
    if (Array(inventory["files"]).size() >= entry_limit || int64_t(inventory["bytes"]) > profile_limit - bytes.size())
        return failure("Persistent profile capacity exhausted; prior committed state retained");
    String error;
#if defined(_WIN32)
    const auto path = native_path(impl_->root.path_join(name));
    ++impl_->write_create_attempts;
    HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file == INVALID_HANDLE_VALUE) return failure(os_error("Cannot create immutable persistent file"));
    DWORD written = 0;
    if (!bytes.is_empty()) {
        ++impl_->write_system_calls;
        const bool okay = WriteFile(file, bytes.ptr(), DWORD(bytes.size()), &written, nullptr);
        impl_->write_count(name,written);
        if (!okay || written != bytes.size()) error = os_error("Cannot write and flush complete persistent file");
    }
    if (error.is_empty()) {
        PhaseTimer flush_timer{impl_->flush_us};
        ++impl_->file_flush_calls;
        if (!FlushFileBuffers(file)) error = os_error("Cannot write and flush complete persistent file");
    }
    if (!CloseHandle(file) && error.is_empty()) error = os_error("Cannot close persistent file");
    if (!error.is_empty()) { DeleteFileW(path.c_str()); return failure(error); }
#elif !defined(__EMSCRIPTEN__)
    const auto utf8 = name.utf8();
    ++impl_->write_create_attempts;
    const int file = ::openat(impl_->directory, utf8.get_data(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (file == -1) return failure(os_error("Cannot create immutable persistent file"));
    int64_t offset = 0;
    while (offset < bytes.size()) {
        ++impl_->write_system_calls;
        const auto count = ::write(file, bytes.ptr() + offset, size_t(bytes.size() - offset));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) { error = os_error("Cannot write complete persistent file"); break; }
        offset += count;
        impl_->write_count(name,count);
    }
    if (error.is_empty()) {
        PhaseTimer flush_timer{impl_->flush_us};
        ++impl_->file_flush_calls;
        if (::fsync(file) != 0) error = os_error("Cannot flush persistent file");
    }
    if (::close(file) != 0 && error.is_empty()) error = os_error("Cannot close persistent file");
    if (!error.is_empty()) { ::unlinkat(impl_->directory, utf8.get_data(), 0); return failure(error); }
#else
    return failure("Persistent areas require the desktop native runtime");
#endif
    error = impl_->sync_directory();
    if (!error.is_empty()) return failure(error);
    auto readback = impl_->read(name, file_limit);
    if (!bool(readback["ok"]) || !bool(readback["exists"]) || PackedByteArray(readback["bytes"]) != bytes)
        return failure("Immutable persistent readback does not match captured bytes");
    auto result = success(); result["sha256"] = readback["sha256"]; result["idempotent"] = false;
    return result;
}

Dictionary CyberPersistentAreaStorage::publish(const String& stage, const String& target, const String& expected_target_sha256, const String& expected_stage_sha256) {
    std::lock_guard guard(impl_->mutex);
    PhaseTimer timer{impl_->publication_us};
    ++impl_->publication_requests;
    if (!impl_->acquired || !valid_name(stage) || !valid_name(target) || stage == target || !valid_digest(expected_target_sha256) ||
        expected_stage_sha256.is_empty() || !valid_digest(expected_stage_sha256))
        return failure("Persistent publication has invalid lock, names or expected identity");
    const auto source = impl_->read(stage, file_limit);
    const auto prior = impl_->read(target, file_limit);
    if (!bool(source["ok"]) || !bool(source.get("exists", false))) return failure("Persistent staged publication is unavailable");
    if (String(source["sha256"]) != expected_stage_sha256) return failure("Persistent staged publication identity changed after prepare");
    if (!bool(prior["ok"])) return prior;
    const String actual = bool(prior["exists"]) ? String(prior["sha256"]) : String();
    if (actual != expected_target_sha256) return failure("Persistent publication rejected a stale target identity");
#if defined(_WIN32)
    const auto source_path = native_path(impl_->root.path_join(stage));
    const auto target_path = native_path(impl_->root.path_join(target));
    ++impl_->publication_calls;
    if (!MoveFileExW(source_path.c_str(), target_path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        return failure(os_error("Cannot atomically publish persistent manifest"));
#elif !defined(__EMSCRIPTEN__)
    const auto source_name = stage.utf8();
    const auto target_name = target.utf8();
    ++impl_->publication_calls;
    if (::renameat(impl_->directory, source_name.get_data(), impl_->directory, target_name.get_data()) != 0)
        return failure(os_error("Cannot atomically publish persistent manifest"));
#else
    return failure("Persistent areas require the desktop native runtime");
#endif
    const auto error = impl_->sync_directory();
    if (!error.is_empty()) return failure(error, true); // Caller must quarantine/re-read; never retry as a fresh save.
    auto result = success(); result["published"] = true; result["sha256"] = source["sha256"];
    return result;
}

Dictionary CyberPersistentAreaStorage::remove_file(const String& name) {
    std::lock_guard guard(impl_->mutex);
    ++impl_->removal_requests;
    if (!impl_->acquired || !valid_name(name)) return failure("Persistent removal has invalid lock or name");
    const auto file = impl_->read(name, file_limit);
    if (!bool(file["ok"])) return file;
    if (!bool(file["exists"])) return success();
#if defined(_WIN32)
    const auto path = native_path(impl_->root.path_join(name));
    if (!DeleteFileW(path.c_str())) return failure(os_error("Cannot remove retired persistent file"));
#elif !defined(__EMSCRIPTEN__)
    const auto utf8 = name.utf8();
    if (::unlinkat(impl_->directory, utf8.get_data(), 0) != 0) return failure(os_error("Cannot remove retired persistent file"));
#else
    return failure("Persistent areas require the desktop native runtime");
#endif
    const auto error = impl_->sync_directory();
    return error.is_empty() ? success() : failure(error);
}
} // namespace godot

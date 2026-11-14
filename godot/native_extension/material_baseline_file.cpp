#include "material_baseline_file.hpp"

#include <string>

#if defined(_WIN32)
// Keep Windows macros out of the native World/bridge headers.
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <sys/stat.h>
#endif

namespace godot::material_baseline_file {
namespace {

String normalize(const String& input, String& path) {
    if (input.is_empty() || input.length() > 32760)
        return "Material baseline replacement requires bounded absolute file paths";
    for (int64_t index = 0; index < input.length(); ++index)
        if (input[index] == 0)
            return "Material baseline replacement refuses embedded NUL in a file path";
#if defined(_WIN32)
    path = input.replace("\\", "/");
    // Accept ordinary drive/UNC paths and their equivalent extended forms.
    // Device namespaces and alternate data streams are not saved-start files.
    if (path.begins_with("//?/UNC/")) path = "//" + path.substr(8);
    else if (path.begins_with("//?/")) path = path.substr(4);
    const bool drive = path.length() >= 3 &&
        ((path[0] >= U'A' && path[0] <= U'Z') || (path[0] >= U'a' && path[0] <= U'z')) &&
        path[1] == U':' && path[2] == U'/';
    const bool unc = path.begins_with("//") && !path.begins_with("//./") &&
        !path.begins_with("//?/");
    if ((!drive && !unc) || path.find(":", drive ? 2 : 0) != -1)
        return "Material baseline replacement requires absolute drive or UNC file paths";
    if (unc) {
        const auto server_end = path.find("/", 2);
        const auto share_end = server_end == -1 ? -1 : path.find("/", server_end + 1);
        if (server_end <= 2 || share_end <= server_end + 1 || share_end == path.length() - 1)
            return "Material baseline replacement requires a file beneath a UNC share";
    }
#else
    if (input[0] != U'/')
        return "Material baseline replacement requires absolute file paths";
    path = input;
#endif
    if (path.ends_with("/")) return "Material baseline replacement requires file paths";
    path = path.simplify_path();
    if (path.get_file().is_empty()) return "Material baseline replacement requires file names";
#if defined(_WIN32)
    if (path.get_file().ends_with(".") || path.get_file().ends_with(" "))
        return "Material baseline replacement refuses ambiguous Windows file names";
#endif
    return {};
}

#if defined(_WIN32)
std::wstring extended_path(const String& path) {
    const String prefixed = path.begins_with("//")
        ? String("\\\\?\\UNC\\") + path.substr(2).replace("/", "\\")
        : String("\\\\?\\") + path.replace("/", "\\");
    const auto utf16 = prefixed.utf16();
    return {utf16.ptr(), utf16.ptr() + utf16.length()};
}

String windows_error(const char* operation, DWORD code) {
    return String(operation) + " (Windows error " + String::num_uint64(code) + ")";
}

String file_identity(const std::wstring& path, bool required,
                     BY_HANDLE_FILE_INFORMATION& identity, bool& exists) {
    exists = false;
    const DWORD attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) {
        const DWORD error = GetLastError();
        if (!required && error == ERROR_FILE_NOT_FOUND) return {};
        return windows_error("Cannot inspect material baseline replacement file", error);
    }
    if ((attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DEVICE)) != 0)
        return "Material baseline replacement requires regular files without reparse points";
    const HANDLE handle = CreateFileW(path.c_str(), 0,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (handle == INVALID_HANDLE_VALUE)
        return windows_error("Cannot inspect material baseline replacement identity", GetLastError());
    const BOOL obtained = GetFileInformationByHandle(handle, &identity);
    const DWORD error = obtained ? ERROR_SUCCESS : GetLastError();
    CloseHandle(handle);
    if (!obtained) return windows_error("Cannot inspect material baseline replacement identity", error);
    if ((identity.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DEVICE)) != 0)
        return "Material baseline replacement requires regular files without reparse points";
    exists = true;
    return {};
}
#endif

} // namespace

String replace(const String& temporary, const String& target) {
    String source_path, target_path;
    if (const auto error = normalize(temporary, source_path); !error.is_empty()) return error;
    if (const auto error = normalize(target, target_path); !error.is_empty()) return error;
    if (source_path.get_base_dir() != target_path.get_base_dir())
        return "Material baseline replacement requires the same directory";
#if defined(_WIN32)
    if (source_path.nocasecmp_to(target_path) == 0)
#else
    if (source_path == target_path)
#endif
        return "Material baseline staging and target must be different files";

#if defined(_WIN32)
    const auto source_native = extended_path(source_path);
    const auto target_native = extended_path(target_path);
    if (source_native.size() >= 32767 || target_native.size() >= 32767)
        return "Material baseline replacement path exceeds the Windows UTF-16 capacity";
    BY_HANDLE_FILE_INFORMATION source_identity{}, target_identity{};
    bool source_exists = false, target_exists = false;
    if (const auto error = file_identity(source_native, true, source_identity, source_exists); !error.is_empty())
        return error;
    if (const auto error = file_identity(target_native, false, target_identity, target_exists); !error.is_empty())
        return error;
    if (target_exists && source_identity.dwVolumeSerialNumber == target_identity.dwVolumeSerialNumber &&
        source_identity.nFileIndexHigh == target_identity.nFileIndexHigh &&
        source_identity.nFileIndexLow == target_identity.nFileIndexLow)
        return "Material baseline staging and target must be different file identities";
    // One same-volume replacement. In particular, do not use Godot 4.7's
    // remove(destination) + MoveFileW path, or COPY_ALLOWED's copy/delete path.
    // WRITE_THROUGH is not a general power-loss durability guarantee.
    if (!MoveFileExW(source_native.c_str(), target_native.c_str(),
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        return windows_error("Atomic material baseline replacement failed", GetLastError());
#else
    const auto source_native = source_path.utf8();
    const auto target_native = target_path.utf8();
    struct stat source_identity{}, target_identity{};
    if (lstat(source_native.get_data(), &source_identity) != 0)
        return String("Cannot inspect material baseline staging file: ") + std::strerror(errno);
    if (!S_ISREG(source_identity.st_mode))
        return "Material baseline staging must be a regular file without a symlink";
    if (lstat(target_native.get_data(), &target_identity) == 0) {
        if (!S_ISREG(target_identity.st_mode))
            return "Material baseline target must be a regular file without a symlink";
        if (source_identity.st_dev == target_identity.st_dev && source_identity.st_ino == target_identity.st_ino)
            return "Material baseline staging and target must be different file identities";
    } else if (errno != ENOENT) {
        return String("Cannot inspect material baseline target file: ") + std::strerror(errno);
    }
    // POSIX rename atomically replaces the destination name on the same volume.
    // The staged file was flushed and closed by the writer before this call.
    if (::rename(source_native.get_data(), target_native.get_data()) != 0)
        return String("Atomic material baseline replacement failed: ") + std::strerror(errno);
#endif
    return {};
}

} // namespace godot::material_baseline_file

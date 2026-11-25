# Windows runtime dependency review

**Disposition: PASS for the finite direct import inventory of the qualified Windows evaluator.** All inspected direct dependencies are accounted for by the immutable package, documented Windows modules, or named Windows API-set contracts. The review does not establish physical Windows11/NVIDIA acceptance.

## Exact payload and evidence

Application source is `5f0722ae231d955a98a83b0fbb9a0e7517ef2d8a`, tree `51ff1e6a0949dff3b2b17cdca7a40d4943b05f78`. The principal ZIP is `objectshard-workbench-evaluator.zip`, 93,388,322 bytes, SHA-256 `1c5dd8ac305ab81996767841dfb0bbcf1db319c9a368c31f104df8e2579ec387`. The original qualification run is [45530425519](https://github.com/techrote/cybersand/actions/runs/45530425519); independent archive and Windows owner witnesses ran in [45537943367](https://github.com/techrote/cybersand/actions/runs/45537943367).

The byte-preserved [delivery audit summary](independent-hosted/delivery-audit-summary.json) records the full direct import tables and their original hashes. The [Windows owner summary](independent-hosted/windows-owner/summary.json) retains the actual System32 file sizes, SHA-256 values and AMD64/PE32+ readbacks. This review joined the same finite 26 names across both records. Those actual OS observations came from WindowsServer2022 build20348. They are separate from Windows11 owner acceptance.

| Inspected image | SHA-256 |
|---|---|
| `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll` | `cfd75fcdcc252ab8b6b42fba1e0c78182517db6142b89a261a5b881eaff047c4` |
| `godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll` | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| `vcruntime140.dll` | `d5e4d9a3e835fa679450145d6a7d94e36573a509317111904d9b3712c30d9066` |
| `Godot_v4.7-stable_win64.exe` | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| `Godot_v4.7-stable_win64_console.exe` | `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c` |

## Redistributable closure

Rapier directly imports `VCRUNTIME140.dll`. The package contains that redistributable at `vcruntime140.dll`, SHA-256 `d5e4d9a3e835fa679450145d6a7d94e36573a509317111904d9b3712c30d9066`; the independent ZIP audit joins its bytes to the declared payload. The native candidate DLL imports Kernel32 and UCRT contracts. No unaccounted MSVCP, VCRUNTIME, concrt, libgcc, libstdc++ or libwinpthread family dependency was accepted merely because a hosted runner might have it installed.

The UCRT is an operating-system component on Windows10/later and WindowsServer2016/later. Microsoft's [UCRT deployment documentation](https://learn.microsoft.com/en-us/cpp/windows/universal-crt-deployment?view=msvc-170) also explains its API-set forwarding and Windows10/11 system-copy resolution. `VCRUNTIME140.dll` remains a distinct packaged compiler-support dependency.

## Finite Windows module classification

The accompanying [machine-readable review](windows-runtime-dependency-review.json) contains all 26 module-to-source mappings and actual hosted byte identities. Specialist B independently opened the primary Requirements fields for [21 common modules](windows-common-import-primary-references.json); Specialist A completed the five remaining classifications below and joined the full finite set to the actual import tables.

| Module | Classification and primary basis |
|---|---|
| bcryptprimitives.dll | [ProcessPrng Requirements](https://learn.microsoft.com/en-us/windows/win32/seccng/processprng) names the DLL; Microsoft's [Windows cryptographic module documentation](https://learn.microsoft.com/en-us/windows/security/security-foundations/certification/fips-140-validation) explicitly includes it in Windows11 and WindowsServer2022. This is no claim of application FIPS qualification. |
| kernel32.dll | [GetModuleHandleW Requirements](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-getmodulehandlew) identifies the core Windows DLL. |
| msvcrt.dll | Microsoft distinguishes the [legacy Windows CRT](https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/using-the-microsoft-c-runtime-with-user-mode-drivers-and-apps) from numbered VisualC++ redistributables. Its [platform explanation](https://devblogs.microsoft.com/oldnewthing/20140411-00/?p=1273) identifies it as an OS DLL and cautions applications against relying on private behavior. This review preserves the approved pinned Godot image. |
| ntdll.dll | The [Windows native API reference](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntqueryinformationprocess) identifies the OS module and cautions that internal interfaces can change. This review makes no general private-ABI promise. |
| wsock32.dll | Microsoft's [Winsock compatibility documentation](https://learn.microsoft.com/en-us/windows/win32/winsock/windows-sockets-compatibility-issues-2) identifies the legacy Winsock1.1 interface; the [architecture documentation](https://learn.microsoft.com/en-us/windows/win32/winsock/windows-sockets-2-architecture-2) classifies the stack interface and compatibility shims as OS components. |

DbgHelp needs precise wording: Microsoft documents an inbox DLL, while optional debugging-tool copies supply additional Symbol/Source Server facilities. The ImmGetContext example's older minimum-client note qualifies East Asian language support; the module classification does not promise that every input-language feature is installed. Both qualifications are retained in the 21-module source record.

## API sets and acceptance boundary

The import tables contain 19 distinct named API-set contracts. Microsoft's [API-set documentation](https://learn.microsoft.com/en-us/windows/win32/apiindex/windows-apisets) explains that these names identify loader contracts rather than mandatory adjacent files. [WaitOnAddress Requirements](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress) explicitly identifies the observed synchronization contract. The exact recorded set is retained in JSON; this review admits no arbitrary additional contract names.

The source-matched Windows native/Workbench, shipped CMD, pristine extracted package and fresh-process owner witnesses all executed successfully. Direct PE inspection and actual execution support the portable evaluator's dependency closure. They do not exhaustively enumerate delay loads, dynamically selected plugins, all exported symbols, graphics-driver capabilities or every OS image configuration. The final physical Windows11/NVIDIA launch and responsiveness check remains an owner acceptance requirement.

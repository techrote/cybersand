@echo off
rem Builds the forwarding d3dcompiler_47.dll trace proxy. Run from a VS x64 Developer Command Prompt.
rem Place the DLL beside a scratch copy of the Godot executable, never the System32 compiler or a shared install.
cd /d %~dp0
cl /nologo /O2 /LD proxy.c /Fe:d3dcompiler_47.dll /link /DEF:proxy.def

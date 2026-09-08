@echo off
setlocal
cd /d "%~dp0"
if defined PYTHON (
    "%PYTHON%" preview.py --open %*
) else if exist ".local\python\Scripts\python.exe" (
    ".local\python\Scripts\python.exe" preview.py --open %*
) else (
    python preview.py --open %*
)

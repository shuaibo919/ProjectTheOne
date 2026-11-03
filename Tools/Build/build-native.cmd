@echo off
rem Build the native GDExtension. Extra args are forwarded to Build-Native.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Native.ps1" %*
exit /b %ERRORLEVEL%

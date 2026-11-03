@echo off
rem Build the native GDExtension.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Native.ps1" %*
exit /b %ERRORLEVEL%

@echo off
rem Load the built GDExtension in a headless engine run.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-Extension.ps1" %*
exit /b %ERRORLEVEL%

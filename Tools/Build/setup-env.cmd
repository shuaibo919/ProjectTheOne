@echo off
rem Create or refresh the project-local uv environment.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Env.ps1" %*
exit /b %ERRORLEVEL%

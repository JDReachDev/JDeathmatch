@echo off
rem Double-click to build and publish/update JDeathmatch on the Workshop.
rem Extra arguments are passed to publish.ps1 (e.g. publish.bat -BuildOnly).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish.ps1" %*
pause

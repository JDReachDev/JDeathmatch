@echo off
rem Double-click to preview workshop_description.txt as it will look on the Workshop.
rem Use "preview_description.bat -Collection" for the example collection.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0preview_description.ps1" %*

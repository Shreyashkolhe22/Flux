@echo off
rem Starts the Flux tray app with no console window.
cd /d "%~dp0"
start "" /min "%~dp0node_modules\.bin\electron.cmd" .

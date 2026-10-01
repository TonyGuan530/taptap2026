@echo off
rem Launch the local review site (http://localhost:8787)
cd /d "%~dp0"
start "" http://localhost:8787
node server\server.js

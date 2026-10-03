@echo off
REM TapTap2026 lite pipeline (OS-level fallback, no AI needed)
REM Covers: Miro sync / itch publish self-heal / Miro re-post
REM AI parts (demo dev / ChatGPT review) still handled by ZCode cron
cd /d D:\GIT\taptap2026

echo [%date% %time%] === lite pipeline start === >> data\lite-pipeline.log

REM 1. Miro sync
node tools\miro-fetch.mjs >> data\lite-pipeline.log 2>&1

REM 2. itch publish health check (demo-07 = last known good; auto re-push on FAIL)
node tools\publish-qa.mjs demo-07 >> data\lite-pipeline.log 2>&1
if errorlevel 1 (
  echo [%date% %time%] QA FAIL - auto re-push demo-07 >> data\lite-pipeline.log
  powershell -File tools\push-itch.ps1 -Version demo-07 >> data\lite-pipeline.log 2>&1
  node tools\publish-qa.mjs demo-07 >> data\lite-pipeline.log 2>&1
)

REM 3. Miro re-post (dedup via log file, safe to repeat)
node tools\miro-post-shots.mjs >> data\lite-pipeline.log 2>&1

echo [%date% %time%] === lite pipeline end === >> data\lite-pipeline.log

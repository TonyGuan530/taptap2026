@echo off
REM TapTap2026 lite pipeline (OS-level fallback, no AI needed)
REM Covers: Miro sync / itch publish self-heal / Miro re-post
REM Health check target = latest completed demo from public/demos.json (dynamic, no hardcoded demo id)
REM AI parts (demo dev / ChatGPT review) still handled by ZCode cron
cd /d D:\GIT\taptap2026

echo [%date% %time%] === lite pipeline start === >> data\lite-pipeline.log

REM 0. resolve latest completed demo version from demos.json
for /f "delims=" %%v in ('node -e "const d=require('./public/demos.json');const s=d.slots.filter(x=>x.buildId);console.log(s.length?s[s.length-1].buildId:'demo-07')"') do set LATEST=%%v
echo [%date% %time%] latest completed build: %LATEST% >> data\lite-pipeline.log

REM 1. Miro sync
node tools\miro-fetch.mjs >> data\lite-pipeline.log 2>&1

REM 2. itch publish health check on LATEST (auto re-push on FAIL, throttled to 1/10min)
node tools\publish-qa.mjs %LATEST% >> data\lite-pipeline.log 2>&1
if errorlevel 1 (
  node -e "const f='data/last-repush.txt';const fs=require('fs');const now=Date.now();const last=fs.existsSync(f)?Number(fs.readFileSync(f,'utf8')):0;if(now-last<600000){process.exit(1)}fs.writeFileSync(f,String(now))"
  if errorlevel 1 (
    echo [%date% %time%] QA FAIL - re-push throttled (10min window^) >> data\lite-pipeline.log
    exit /b 0
  )
  echo [%date% %time%] QA FAIL - auto re-push %LATEST% >> data\lite-pipeline.log
  powershell -File tools\push-itch.ps1 -Version %LATEST% >> data\lite-pipeline.log 2>&1
  node tools\publish-qa.mjs %LATEST% >> data\lite-pipeline.log 2>&1
)

REM 3. Miro re-post (dedup via log file, safe to repeat)
node tools\miro-post-shots.mjs >> data\lite-pipeline.log 2>&1

echo [%date% %time%] === lite pipeline end === >> data\lite-pipeline.log

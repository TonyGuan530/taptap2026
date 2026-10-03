@echo off
REM TapTap2026 轻量流水线（OS 级定时兜底，无需 AI 在线）
REM 覆盖：Miro 同步 / itch 发布健康自愈 / Miro 重贴
REM AI 部分（开发 demo / ChatGPT 评审）仍由 ZCode 定时任务负责
cd /d D:\GIT\taptap2026

echo [%date% %time%] === TapTap 轻量流水线开始 === >> data\lite-pipeline.log

REM 1. Miro 同步
node tools\miro-fetch.mjs >> data\lite-pipeline.log 2>&1

REM 2. itch 发布健康检查（demo-07 为最近完好版本；FAIL 自动重推一次）
node tools\publish-qa.mjs demo-07 >> data\lite-pipeline.log 2>&1
if errorlevel 1 (
  echo [%date% %time%] QA FAIL → 自动重推 demo-07 >> data\lite-pipeline.log
  powershell -File tools\push-itch.ps1 -Version demo-07 >> data\lite-pipeline.log 2>&1
  node tools\publish-qa.mjs demo-07 >> data\lite-pipeline.log 2>&1
)

REM 3. Miro 重贴（有内置去重日志，不会重复）
node tools\miro-post-shots.mjs >> data\lite-pipeline.log 2>&1

echo [%date% %time%] === 轻量流水线结束 === >> data\lite-pipeline.log

@echo off
REM Run this from the backend directory or double-click the script.
cd /d %~dp0
if not exist .venv (
  python -m venv .venv
  .venv\Scripts\pip install --upgrade pip
  .venv\Scripts\pip install -r requirements.txt
)
.venv\Scripts\python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
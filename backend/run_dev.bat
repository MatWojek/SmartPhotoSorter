@echo off
setlocal enabledelayedexpansion
cd /d %~dp0

rem Activate venv if exists
if exist .venv\Scripts\activate.bat call .venv\Scripts\activate.bat

rem Ensure uvicorn is available (install if missing)
for /f %%i in ('python -c "import importlib.util; print(1 if importlib.util.find_spec("uvicorn") else 0)"') do set HASUVICORN=%%i
if not "%HASUVICORN%"=="1" (
  python -m pip install "uvicorn[standard]==0.38.0"
)

rem Configure port (default 8000 if not set)
if "%PORT%"=="" (
  set PORT=8000
)

rem Try to free the port if a previous dev server is still running
set PID=
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":%PORT%" ^| findstr "LISTENING"') do (
  set PID=%%p
)

if defined PID (
  echo Stopping process on port %PORT% with PID %PID%
  taskkill /PID %PID% /F >nul 2>&1
  timeout /T 1 >nul 2>&1
)

rem Start FastAPI with autoreload
python -m uvicorn app.main:app --reload 
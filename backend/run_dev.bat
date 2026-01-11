@echo off
setlocal enabledelayedexpansion
cd /d %~dp0

rem Activate venv if exists
if exist .venv\Scripts\activate.bat call .venv\Scripts\activate.bat

rem Ensure uvicorn is available (install if missing)
for /f %%i in ('python -c "import importlib.util; print(1 if importlib.util.find_spec(''uvicorn'') else 0)"') do set HASUVICORN=%%i
if not "%HASUVICORN%"=="1" (
  python -m pip install "uvicorn[standard]==0.38.0"
)

rem Start FastAPI with autoreload
python -m uvicorn app.main:app --reload
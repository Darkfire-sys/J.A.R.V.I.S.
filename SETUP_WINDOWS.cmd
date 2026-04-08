@echo off
setlocal

set "ROOT=%~dp0"

echo ==========================================
echo J.A.R.V.I.S Windows Setup
echo ==========================================
echo.

where python >nul 2>nul
if errorlevel 1 (
  echo Python was not found.
  echo Install Python 3.11 or newer, then run this setup again.
  echo https://www.python.org/downloads/windows/
  echo.
  goto :missing
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found.
  echo Install Flutter with Windows desktop support, then run this setup again.
  echo https://docs.flutter.dev/get-started/install/windows/desktop
  echo.
  goto :missing
)

where ollama >nul 2>nul
if errorlevel 1 (
  echo Ollama was not found.
  echo Install Ollama, then run this setup again.
  echo https://ollama.com/download/windows
  echo.
  goto :missing
)

echo Installing Python dependencies...
python -m pip install -r "%ROOT%requirements.txt"
if errorlevel 1 goto :failed

echo.
echo Installing Flutter packages...
pushd "%ROOT%jarvis_flutter"
flutter pub get
if errorlevel 1 (
  popd
  goto :failed
)
popd

echo.
echo Checking Ollama model...
ollama list | findstr /I "gemma3:12b" >nul
if errorlevel 1 (
  echo Model gemma3:12b not found locally.
  echo Pulling gemma3:12b now. This can take a while...
  ollama pull gemma3:12b
  if errorlevel 1 goto :failed
) else (
  echo gemma3:12b is already installed.
)

echo.
echo Setup complete.
echo Double-click RUN_JARVIS_WINDOWS.cmd to launch J.A.R.V.I.S.
echo.
pause
exit /b 0

:missing
echo Setup stopped because one or more required tools are missing.
echo.
pause
exit /b 1

:failed
echo.
echo Setup failed. Review the messages above, fix the problem, and try again.
echo.
pause
exit /b 1

J.A.R.V.I.S

J.A.R.V.I.S is a Windows desktop assistant built with:
- a Flutter desktop client
- a local Python backend
- Ollama for local AI inference

WHAT THIS REPO INCLUDES

- Chat threads and local memory
- Protocol Mode routines
- App launch and close controls
- Drag-and-drop file attachments
- Screenshot attachment support
- Tray mode and a global hotkey
- Local Ollama-backed AI responses

REPO LAYOUT

repo-root/
  backend_server.py
  jarvis.py
  executor.py
  commands.json
  requirements.txt
  tools/
  workspace/
  SETUP_WINDOWS.cmd
  RUN_JARVIS_WINDOWS.cmd
  jarvis_flutter/
  README.txt

SYSTEM REQUIREMENTS

- Windows 10 or Windows 11
- Python 3.11 or newer
- Flutter with Windows desktop enabled
- Ollama installed locally
- The Ollama model used by this project: gemma3:12b

QUICKEST SETUP

1. Install Python.
2. Install Flutter.
3. Install Ollama.
4. Double-click SETUP_WINDOWS.cmd.
5. After setup finishes, double-click RUN_JARVIS_WINDOWS.cmd.

WHAT SETUP_WINDOWS.cmd DOES

- checks whether Python, Flutter, and Ollama are installed
- installs Python dependencies from requirements.txt
- runs flutter pub get inside jarvis_flutter
- checks for the gemma3:12b Ollama model
- pulls gemma3:12b if it is missing

IF SOMETHING IS MISSING

The setup script will tell the user what is missing and where to install it.

MANUAL SETUP

If setup is being done manually, use these commands from the repo root:

1. Install Python packages:
   pip install -r requirements.txt

2. Pull the Ollama model:
   ollama pull gemma3:12b

3. Install Flutter packages:
   cd jarvis_flutter
   flutter pub get

4. Run the app:
   flutter run -d windows

KNOWN LIMITATIONS

- This project is Windows-focused.
- Some app-control targets are machine-specific and may need to be changed on another PC.
- Known machine-specific app integrations include Opera GX, YouTube Music Desktop App, Codex, and Overwolf.
- The app can still run without those integrations, but commands for missing apps will fail until their paths are adjusted.

ARCHITECTURE

- jarvis_flutter/: Flutter desktop client
- backend_server.py: local HTTP backend bridge
- jarvis.py: prompt logic, memory behavior, and Ollama calls
- tools/: local desktop actions
- workspace/: local app state


# GitHub Publishing Checklist

Use this before uploading J.A.R.V.I.S to GitHub.

## 1. Confirm The Repo Layout

Before publishing, make sure the repo root contains:

- `jarvis_flutter/`
- `backend_server.py`
- `jarvis.py`
- `executor.py`
- `commands.json`
- `tools/`
- `workspace/`
- `requirements.txt`

## 2. Remove Personal Data

These should stay untracked:

- `workspace/chat-history.json`
- `workspace/jarvis-memory.json`
- `workspace/jarvis-settings.json`
- `workspace/whatsapp_contacts.json`
- `workspace/screenshots/`
- `workspace/backend_debug.log`

## 3. Keep The Shareable Defaults

These are generally safe to keep if you want people to see how the app is set up:

- `workspace/PROTOCOLS.md`
- `workspace/jarvis-protocols.json` if you want to share your protocol examples

## 4. Call Out The Prerequisites

In the repo README, tell users they must install:

- Python 3.11+
- Flutter
- Ollama
- the Ollama model `gemma3:12b`

Also point users to:

- `SETUP_WINDOWS.cmd`
- `RUN_JARVIS_WINDOWS.cmd`

## 5. Mention The Known Machine-Specific Parts

Warn users that some app-launch targets are hardcoded or machine-specific, especially:

- Opera GX
- YouTube Music Desktop App
- Codex
- Overwolf

## 6. Test The Fresh Clone Flow

Before sharing the repo, verify this exact flow on a clean machine or a second Windows user account:

```powershell
pip install -r requirements.txt
ollama pull gemma3:12b
cd jarvis_flutter
flutter pub get
flutter run -d windows
```

If that works, the GitHub instructions are in good shape.

## 7. Push The Repo

From `D:\Jarvis`:

```powershell
git init
git add .
git commit -m "Initial J.A.R.V.I.S release"
```

Then connect the folder to a GitHub repo and push.

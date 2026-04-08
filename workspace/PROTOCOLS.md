# Protocol Guide

`J.A.R.V.I.S` loads protocol definitions from:

`D:\Jarvis\workspace\jarvis-protocols.json`

## How To Add A New Protocol

1. Open `D:\Jarvis\workspace\jarvis-protocols.json`.
2. Inside the top-level `"protocols"` array, copy one existing protocol object.
3. Change these fields:
   - `"id"`: unique internal id, like `"protocol_stream"`
   - `"name"`: visible protocol name, like `"Protocol Stream"`
   - `"description"`: short summary
   - `"aliases"`: phrases you want `J.A.R.V.I.S` to recognize
   - `"steps"`: the actions to run, in order
4. Save the file.
5. Restart `J.A.R.V.I.S`, or relaunch the desktop app, and the new protocol will be available.

## Step Format

Each step must look like one of these:

```json
{ "type": "launchApp", "appId": "youtube_music" }
{ "type": "closeApp", "appId": "valorant" }
```

`"type"` can be:

- `launchApp`
- `closeApp`

## Built-In App IDs

Right now you can use these app ids in protocols without changing code:

- `overwolf_launcher`
- `valorant`
- `opera_gx`
- `youtube_music`
- `vs_code`
- `codex`

## Example Protocol

```json
{
  "id": "protocol_stream",
  "name": "Protocol Stream",
  "description": "Opens OBS, Opera GX, and YouTube Music.",
  "aliases": [
    "protocol stream",
    "activate protocol stream",
    "start protocol stream"
  ],
  "steps": [
    { "type": "launchApp", "appId": "opera_gx" },
    { "type": "launchApp", "appId": "youtube_music" }
  ]
}
```

## Important Rule

If you want a protocol to control a brand-new app that is not in the built-in app id list above, the JSON file alone is not enough.

You will also need to add that app to the hardcoded desktop app registry in:

`D:\Jarvis\jarvis_flutter\lib\main.dart`

Look for `_buildDesktopApps()`.

For a new app there, add:

- its `id`
- its visible `name`
- spoken `aliases`
- one or more executable paths in `executableCandidates`
- its Windows process names in `processNames`
- optional `commandCandidates` if it can be launched from a shell command

## Protocol Mode Triggers

Protocol Mode can currently be activated by phrases like:

- `activate protocol mode`
- `engage protocol mode`
- `protocol mode`
- `start protocol mode`
- `activate prtcl mode`
- `engage prtcl mode`
- `prtcl mode`
- `prtclmd`

Activation is silent and starts a fresh thread.

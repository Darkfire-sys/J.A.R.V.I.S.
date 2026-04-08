import difflib
import json
import os
import re
import shutil
import subprocess
import webbrowser
import winreg
from functools import lru_cache
from pathlib import Path
from urllib.parse import quote

SEARCH_PATHS = [
    r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs",
    os.path.expandvars(r"%APPDATA%\Microsoft\Windows\Start Menu\Programs"),
    os.path.expandvars(r"%USERPROFILE%\Desktop"),
    os.path.expandvars(r"%PUBLIC%\Desktop"),
]

UNINSTALL_PATHS = [
    r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
]

APP_ALIASES = {
    "calculator": "calculator",
    "calc": "calculator",
    "command prompt": "terminal",
    "terminal": "terminal",
    "cmd": "terminal",
    "chrome": "google chrome",
    "googlechrome": "google chrome",
    "edge": "microsoft edge",
    "opera": "opera gx stable",
    "operagx": "opera gx stable",
    "opera gx": "opera gx stable",
    "whatsapp messenger": "whatsapp",
    "vs code": "microsoft visual studio code user",
    "visual studio code": "microsoft visual studio code user",
    "vscode": "microsoft visual studio code user",
    "code": "microsoft visual studio code user",
}

DIRECT_EXECUTABLES = {
    "calculator": "calc.exe",
    "notepad": "notepad.exe",
    "terminal": "wt.exe",
}


def normalize_app_name(app_name):
    compact = re.sub(r"[^a-z0-9]+", " ", (app_name or "").lower()).strip()
    return re.sub(r"\s+", " ", compact)


def resolve_alias(app_name):
    normalized = normalize_app_name(app_name)
    return APP_ALIASES.get(normalized, normalized)


def display_name_from_path(path):
    name = os.path.splitext(os.path.basename(path))[0]
    return name.replace(" - Shortcut", "").strip()


def score_candidate(target, candidate_name):
    target_compact = target.replace(" ", "")
    candidate_compact = candidate_name.replace(" ", "")

    if candidate_name == target:
        return 1.0
    if target in candidate_name:
        return 0.985
    if candidate_name in target:
        return 0.955
    if target_compact and target_compact in candidate_compact:
        return 0.94

    return difflib.SequenceMatcher(None, target, candidate_name).ratio()


def launch_target(path):
    if path.lower().endswith((".lnk", ".url")):
        os.startfile(path)
    else:
        subprocess.Popen([path])


@lru_cache(maxsize=1)
def discover_shortcut_candidates():
    candidates = []

    for base in SEARCH_PATHS:
        if not os.path.exists(base):
            continue

        for root, _, files in os.walk(base):
            for file_name in files:
                lowered = file_name.lower()
                if lowered.endswith((".lnk", ".url", ".exe")):
                    full_path = os.path.join(root, file_name)
                    normalized_file = normalize_app_name(
                        display_name_from_path(full_path)
                    )
                    candidates.append(
                        {
                            "name": normalized_file,
                            "display_name": display_name_from_path(full_path),
                            "kind": "shortcut",
                            "target": full_path,
                        }
                    )

    return candidates


def _iter_registry_root(root, subkey):
    try:
        with winreg.OpenKey(root, subkey) as key:
            count, _, _ = winreg.QueryInfoKey(key)
            for index in range(count):
                yield key, winreg.EnumKey(key, index)
    except OSError:
        return


@lru_cache(maxsize=1)
def discover_registry_app_paths():
    results = []
    registry_roots = [
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"),
        (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"),
    ]

    for root, subkey in registry_roots:
        for key, entry_name in _iter_registry_root(root, subkey):
            try:
                with winreg.OpenKey(key, entry_name) as app_key:
                    executable_path, _ = winreg.QueryValueEx(app_key, None)
                    if not executable_path:
                        continue

                    results.append(
                        {
                            "name": normalize_app_name(os.path.splitext(entry_name)[0]),
                            "display_name": os.path.splitext(entry_name)[0],
                            "kind": "path",
                            "target": executable_path,
                        }
                    )
                    results.append(
                        {
                            "name": normalize_app_name(
                                os.path.splitext(os.path.basename(executable_path))[0]
                            ),
                            "display_name": os.path.splitext(os.path.basename(executable_path))[0],
                            "kind": "path",
                            "target": executable_path,
                        }
                    )
            except OSError:
                continue

    return results


@lru_cache(maxsize=1)
def discover_installed_programs():
    results = []
    registry_roots = [
        (winreg.HKEY_LOCAL_MACHINE, path) for path in UNINSTALL_PATHS
    ] + [
        (winreg.HKEY_CURRENT_USER, path) for path in UNINSTALL_PATHS
    ]

    for root, subkey in registry_roots:
        for key, entry_name in _iter_registry_root(root, subkey):
            try:
                with winreg.OpenKey(key, entry_name) as app_key:
                    display_name, _ = winreg.QueryValueEx(app_key, "DisplayName")
            except OSError:
                continue

            normalized = normalize_app_name(display_name)
            if not normalized:
                continue

            results.append(
                {
                    "name": normalized,
                    "display_name": display_name,
                    "kind": "installed",
                    "target": display_name,
                }
            )

    return results


@lru_cache(maxsize=1)
def discover_start_apps():
    command = [
        "powershell",
        "-NoProfile",
        "-Command",
        "Get-StartApps | Select-Object Name,AppID | ConvertTo-Json -Depth 3",
    ]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=8,
            check=True,
        )
    except (subprocess.SubprocessError, FileNotFoundError):
        return []

    raw_output = result.stdout.strip()
    if not raw_output:
        return []

    try:
        payload = json.loads(raw_output)
    except json.JSONDecodeError:
        return []

    if isinstance(payload, dict):
        payload = [payload]

    results = []
    for item in payload:
        if not isinstance(item, dict):
            continue

        name = item.get("Name") or item.get("name") or ""
        app_id = item.get("AppID") or item.get("appID") or item.get("AppId") or ""
        normalized = normalize_app_name(name)
        if not normalized or not app_id:
            continue

        results.append(
            {
                "name": normalized,
                "display_name": name,
                "kind": "apps_folder",
                "target": app_id,
            }
        )

    return results


@lru_cache(maxsize=1)
def discover_all_app_candidates():
    return (
        discover_start_apps()
        + discover_shortcut_candidates()
        + discover_registry_app_paths()
        + discover_installed_programs()
    )


def find_best_candidate(app_name):
    target = resolve_alias(app_name)
    best_score = 0
    best_candidate = None

    for candidate in discover_all_app_candidates():
        score = score_candidate(target, candidate["name"])
        if score > best_score:
            best_score = score
            best_candidate = candidate

    if best_candidate and best_score >= 0.72:
        return best_candidate
    return None


def _launch_apps_folder(app_id):
    subprocess.Popen(["explorer.exe", f"shell:AppsFolder\\{app_id}"])


def open_app(app_name):
    requested_name = (app_name or "").strip()
    if not requested_name:
        return "Please tell me which app to open."

    candidate = find_best_candidate(requested_name)
    if candidate:
        try:
            if candidate["kind"] == "apps_folder":
                _launch_apps_folder(candidate["target"])
            else:
                launch_target(candidate["target"])
            return f"Opened {candidate['display_name']}"
        except Exception as exc:
            return f"Could not open {requested_name}: {exc}"

    resolved_name = resolve_alias(requested_name)
    executable = DIRECT_EXECUTABLES.get(resolved_name)
    if executable:
        try:
            subprocess.Popen([executable])
            return f"Opened {requested_name}"
        except Exception as exc:
            return f"Could not open {requested_name}: {exc}"

    path_lookup = shutil.which(resolved_name) or shutil.which(f"{resolved_name}.exe")
    if path_lookup:
        try:
            subprocess.Popen([path_lookup])
            return f"Opened {requested_name}"
        except Exception as exc:
            return f"Could not open {requested_name}: {exc}"

    try:
        subprocess.Popen(resolved_name, shell=True)
        return f"Trying to open {requested_name}"
    except Exception as exc:
        return f"Could not open {requested_name}: {exc}"


def _workspace_candidates():
    here = Path(__file__).resolve().parent.parent
    yield here / "workspace"
    yield Path.cwd() / "workspace"
    if getattr(__import__("sys"), "_MEIPASS", None):
        yield Path(__import__("sys")._MEIPASS) / "workspace"


def _contacts_file():
    for workspace_dir in _workspace_candidates():
        path = workspace_dir / "whatsapp_contacts.json"
        if path.exists():
            return path
    return next(_workspace_candidates()) / "whatsapp_contacts.json"


def _resolve_whatsapp_target(target):
    raw_target = (target or "").strip()
    digits = re.sub(r"\D", "", raw_target)
    if digits:
        return digits, None

    contacts_path = _contacts_file()
    if contacts_path.exists():
        try:
            contacts = json.loads(contacts_path.read_text(encoding="utf-8"))
            if isinstance(contacts, dict):
                normalized_target = normalize_app_name(raw_target)
                for name, number in contacts.items():
                    if normalize_app_name(name) == normalized_target:
                        resolved_number = re.sub(r"\D", "", str(number))
                        if resolved_number:
                            return resolved_number, None
        except Exception:
            pass

    return None, contacts_path


def send_whatsapp_message(target, message):
    text = (message or "").strip()
    if not text:
        return "Please include the WhatsApp message text."

    resolved_number, contacts_path = _resolve_whatsapp_target(target)
    if not resolved_number:
        if contacts_path:
            contacts_path.parent.mkdir(parents=True, exist_ok=True)
            if not contacts_path.exists():
                contacts_path.write_text(
                    json.dumps(
                        {
                            "Mom": "+919999999999",
                            "Best Friend": "+919888888888",
                        },
                        indent=2,
                    ),
                    encoding="utf-8",
                )
            return (
                "I could not resolve that WhatsApp contact. "
                f"Add the name and phone number to {contacts_path} or use a full phone number with country code."
            )
        return "I could not resolve that WhatsApp contact."

    encoded_text = quote(text)
    url = f"https://wa.me/{resolved_number}?text={encoded_text}"
    try:
        webbrowser.open(url)
        return (
            f"Opened WhatsApp chat for {target}. "
            "The message is prefilled and ready to send."
        )
    except Exception as exc:
        return f"Could not prepare the WhatsApp message: {exc}"

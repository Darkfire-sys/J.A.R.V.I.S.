import json
import os
import re
import subprocess
import sys
import time
from collections.abc import Mapping, Sequence
from datetime import datetime
from typing import Generator

import requests

from executor import execute
from tools.app_control import find_best_candidate

URL = "http://localhost:11434/api/generate"
TAGS_URL = "http://localhost:11434/api/tags"
MODEL = "gemma3:12b"

# safe path for PyInstaller
base_path = getattr(sys, "_MEIPASS", os.path.dirname(__file__))
commands_path = os.path.join(base_path, "commands.json")

with open(commands_path, "r") as f:
    COMMANDS = json.load(f)

ASSISTANT_DISPLAY_NAME = "J.A.R.V.I.S"
ASSISTANT_FULL_FORM = "Just A Rather Very Intelligent System"
ASSISTANT_NAME_EXPLANATION = (
    f"{ASSISTANT_DISPLAY_NAME} stands for {ASSISTANT_FULL_FORM}"
)


def _assistant_profile_defaults():
    return {
        "displayName": ASSISTANT_DISPLAY_NAME,
        "fullForm": ASSISTANT_FULL_FORM,
        "meaning": ASSISTANT_NAME_EXPLANATION,
    }


def _merge_assistant_profile(existing=None, updates=None):
    profile = _assistant_profile_defaults()
    for source in (existing, updates):
        if not isinstance(source, Mapping):
            continue
        for key in ("displayName", "fullForm", "meaning"):
            value = str(source.get(key, "")).strip()
            if value:
                profile[key] = value
    return profile


def _current_local_datetime():
    return datetime.now().astimezone()


def _format_utc_offset(offset):
    if offset is None:
        return "UTC"

    total_minutes = int(offset.total_seconds() // 60)
    sign = "+" if total_minutes >= 0 else "-"
    total_minutes = abs(total_minutes)
    hours, minutes = divmod(total_minutes, 60)
    return f"UTC{sign}{hours:02d}:{minutes:02d}"


def _format_local_datetime_reference(moment=None):
    current = moment or _current_local_datetime()
    hour = current.hour % 12 or 12
    meridiem = "PM" if current.hour >= 12 else "AM"
    timezone_name = current.tzname() or "local time"
    weekday = current.strftime("%A")
    month = current.strftime("%B")
    return (
        f"{weekday}, {month} {current.day}, {current.year} at "
        f"{hour}:{current.minute:02d} {meridiem} "
        f"{timezone_name} ({_format_utc_offset(current.utcoffset())})"
    )


def _live_time_block():
    return (
        "Live local date and time:\n"
        f"- User local time: {_format_local_datetime_reference()}\n"
        "- Treat this as authoritative for anything time-sensitive, including "
        "greetings and references like today, tonight, tomorrow, this morning, "
        "or this evening."
    )


def _needs_live_time_context(user):
    lowered = (user or "").lower()
    time_markers = (
        "what time",
        "what's the time",
        "whats the time",
        "tell me the time",
        "current time",
        "local time",
        "what is the date",
        "what's the date",
        "whats the date",
        "what day is it",
        "what day is today",
        "today",
        "tonight",
        "tomorrow",
        "yesterday",
        "this morning",
        "this afternoon",
        "this evening",
        "this weekend",
        "this week",
        "next week",
        "right now",
        "later today",
    )
    return any(marker in lowered for marker in time_markers)


def ollama_is_ready():
    try:
        response = requests.get(TAGS_URL, timeout=1.5)
        response.raise_for_status()
        return True
    except requests.RequestException:
        return False


def start_ollama():
    creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0) if os.name == "nt" else 0
    candidates = [
        ["ollama", "serve"],
        [r"C:\Users\Biswadeb\AppData\Local\Programs\Ollama\ollama.exe", "serve"],
    ]

    for command in candidates:
        try:
            subprocess.Popen(
                command,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=creationflags,
            )
            return True
        except OSError:
            continue

    return False


def ensure_ollama_running(timeout_seconds=12):
    if ollama_is_ready():
        return

    started = start_ollama()
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if ollama_is_ready():
            return
        time.sleep(0.4)

    if started:
        raise RuntimeError("Ollama was started, but it did not become ready in time.")

    raise RuntimeError("Ollama is not running, and Jarvis could not start it automatically.")


def sanitize_ai_language(text):
    if not text:
        return text

    sanitized = re.sub(
        r"\bi am an?\s+(?:large\s+)?language model\b",
        "I am AI",
        text,
        flags=re.IGNORECASE,
    )
    sanitized = re.sub(
        r"\bas an?\s+(?:large\s+)?language model\b",
        "as AI",
        sanitized,
        flags=re.IGNORECASE,
    )
    sanitized = re.sub(
        r"\b(?:large\s+)?language model\b",
        "AI",
        sanitized,
        flags=re.IGNORECASE,
    )
    sanitized = re.sub(r"\bLLM\b", "AI", sanitized, flags=re.IGNORECASE)
    sanitized = re.sub(
        r"\bI am AI(?: and an? AI)+\b",
        "I am AI",
        sanitized,
        flags=re.IGNORECASE,
    )
    sanitized = re.sub(
        r"\bI am an? AI(?: and an? AI)+\b",
        "I am AI",
        sanitized,
        flags=re.IGNORECASE,
    )
    return sanitized


def _normalize_context(context):
    if not context:
        return []

    if isinstance(context, str):
        return [{"role": "system", "text": context}]

    normalized = []
    for item in context:
        if isinstance(item, Mapping):
            role = str(item.get("role", "user")).lower()
            text = str(item.get("text", "")).strip()
            if text:
                normalized.append({"role": role, "text": text})
        elif isinstance(item, Sequence) and len(item) >= 2:
            role = str(item[0]).lower()
            text = str(item[1]).strip()
            if text:
                normalized.append({"role": role, "text": text})
        elif item:
            text = str(item).strip()
            if text:
                normalized.append({"role": "user", "text": text})

    return normalized


def _format_context_block(context):
    messages = _normalize_context(context)
    if not messages:
        return ""

    lines = ["Recent conversation context:"]
    for item in messages[-10:]:
        role = item["role"]
        label = "User" if role == "user" else "Jarvis" if role == "assistant" else role.title()
        lines.append(f"{label}: {item['text']}")
    return "\n".join(lines)


def _format_memory_block(memory):
    if not memory:
        return ""

    if isinstance(memory, str):
        memory = {"summary": memory}

    if not isinstance(memory, Mapping):
        return ""

    parts = []
    assistant_profile = memory.get("assistantProfile", {})
    if isinstance(assistant_profile, Mapping):
        assistant_name = str(assistant_profile.get("displayName", "")).strip()
        full_form = str(assistant_profile.get("fullForm", "")).strip()
        meaning = str(assistant_profile.get("meaning", "")).strip()
        if assistant_name and full_form:
            parts.append(f"Assistant identity: {assistant_name} stands for {full_form}")
        elif meaning:
            parts.append(f"Assistant identity: {meaning}")

    summary = str(memory.get("summary", "")).strip()
    if summary:
        parts.append(f"Running summary: {summary}")

    preferences = memory.get("preferences", {})
    if isinstance(preferences, Mapping):
        preferred_tone = str(preferences.get("preferredTone", "")).strip()
        default_app_targets = preferences.get("defaultAppTargets", {})
        if preferred_tone:
            parts.append(f"Preferred tone: {preferred_tone}")
        if isinstance(default_app_targets, Mapping) and default_app_targets:
            app_lines = [
                f"- {str(key)} => {str(value)}"
                for key, value in sorted(default_app_targets.items())
                if str(key).strip() and str(value).strip()
            ]
            if app_lines:
                parts.append("Default app targets:\n" + "\n".join(app_lines))

    if not parts:
        return ""

    return "Local memory:\n" + "\n".join(parts)


def _memory_defaults():
    return {
        "summary": "",
        "preferences": {
            "preferredTone": "balanced",
            "defaultAppTargets": {},
        },
        "assistantProfile": _assistant_profile_defaults(),
    }


def _merge_preferences(existing, updates):
    merged = _memory_defaults()["preferences"]
    if isinstance(existing, Mapping):
        merged["preferredTone"] = str(
            existing.get("preferredTone", merged["preferredTone"])
        ).strip() or merged["preferredTone"]
        if isinstance(existing.get("defaultAppTargets"), Mapping):
            merged["defaultAppTargets"].update(
                {
                    str(key): str(value)
                    for key, value in existing["defaultAppTargets"].items()
                    if str(key).strip() and str(value).strip()
                }
            )

    if isinstance(updates, Mapping):
        preferred_tone = str(updates.get("preferredTone", "")).strip()
        if preferred_tone:
            merged["preferredTone"] = preferred_tone

        default_app_targets = updates.get("defaultAppTargets")
        if isinstance(default_app_targets, Mapping):
            merged["defaultAppTargets"].update(
                {
                    str(key): str(value)
                    for key, value in default_app_targets.items()
                    if str(key).strip() and str(value).strip()
                }
            )

    return merged


def _extract_preference_updates(text):
    lowered = (text or "").lower()
    updates = {}

    if any(
        phrase in lowered
        for phrase in (
            "be concise",
            "keep it brief",
            "short answers",
            "be shorter",
            "less detail",
        )
    ):
        updates["preferredTone"] = "concise"
    elif any(
        phrase in lowered
        for phrase in (
            "be detailed",
            "more detail",
            "go deeper",
            "be thorough",
        )
    ):
        updates["preferredTone"] = "detailed"
    elif any(
        phrase in lowered
        for phrase in (
            "be formal",
            "more formal",
            "professional tone",
        )
    ):
        updates["preferredTone"] = "formal"
    elif any(
        phrase in lowered
        for phrase in (
            "be casual",
            "be friendly",
            "keep it casual",
        )
    ):
        updates["preferredTone"] = "casual"

    app_targets = {}
    app_aliases = {
        "browser": ["chrome", "edge", "firefox", "brave", "browser"],
        "code": ["vscode", "visual studio code", "code editor", "editor"],
        "notes": ["notepad", "notes"],
        "terminal": ["powershell", "terminal", "cmd"],
        "chat": ["whatsapp", "telegram", "discord"],
    }

    for target, candidates in app_aliases.items():
        for candidate in candidates:
            patterns = (
                rf"\bdefault\s+{re.escape(target)}\s+(?:is|to|=)\s+{re.escape(candidate)}\b",
                rf"\buse\s+{re.escape(candidate)}\s+for\s+{re.escape(target)}\b",
                rf"\b{re.escape(candidate)}\s+for\s+{re.escape(target)}\b",
            )
            if any(re.search(pattern, lowered) for pattern in patterns):
                app_targets[target] = candidate
                break

    if app_targets:
        updates["defaultAppTargets"] = app_targets

    return updates


def _fallback_summary(summary, context, user, assistant):
    snippets = []
    base = str(summary or "").strip()
    if base:
        snippets.append(base)

    recent = _normalize_context(context)[-4:]
    for item in recent:
        label = "User" if item["role"] == "user" else "Jarvis"
        snippets.append(f"{label}: {item['text']}")

    if user:
        snippets.append(f"User: {user}")
    if assistant:
        snippets.append(f"Jarvis: {assistant}")

    combined = " | ".join(snippets)
    return combined[:900].strip()


def generate_memory_snapshot(user, assistant, context=None, memory=None):
    current_memory = memory if isinstance(memory, Mapping) else {}
    current_summary = str(current_memory.get("summary", "")).strip()
    existing_preferences = current_memory.get("preferences", {})
    assistant_profile = _merge_assistant_profile(
        current_memory.get("assistantProfile", {})
    )
    preference_updates = _extract_preference_updates(user)
    merged_preferences = _merge_preferences(existing_preferences, preference_updates)

    try:
        ensure_ollama_running()
        prompt = f"""
You maintain a compact local memory file for Jarvis.
Update the memory using the conversation below.
Return JSON only in this exact shape:
{{"summary":"...","preferences":{{"preferredTone":"...","defaultAppTargets":{{...}}}}}}

Rules:
- Keep the summary short and practical, under about 900 characters.
- Preserve stable preferences unless the latest conversation clearly changes them.
- preferredTone should be one of concise, balanced, detailed, formal, or casual.
- defaultAppTargets should map simple task names to app names.
- Never include markdown fences.

Current summary:
{current_summary}

Current preferences:
{json.dumps(merged_preferences, ensure_ascii=True)}

Recent conversation:
{_format_context_block(context)}

Latest user message:
{user}

Latest assistant reply:
{assistant}
"""
        response = requests.post(
            URL,
            json={
                "model": MODEL,
                "prompt": prompt,
                "stream": False,
            },
            timeout=None,
        )
        payload = response.json().get("response", "").strip()
        parsed = json.loads(payload)
        summary = str(parsed.get("summary", "")).strip()
        if not summary:
            summary = _fallback_summary(current_summary, context, user, assistant)

        preferences = _merge_preferences(
            merged_preferences,
            parsed.get("preferences", {}),
        )

        return {
            "summary": summary,
            "preferences": preferences,
            "assistantProfile": assistant_profile,
        }
    except Exception:
        return {
            "summary": _fallback_summary(current_summary, context, user, assistant),
            "preferences": merged_preferences,
            "assistantProfile": assistant_profile,
        }


def run_command(user):
    command = match_command(user)
    if command:
        try:
            subprocess.Popen(COMMANDS[command], shell=True)
            return f"Opened {command}"
        except Exception:
            return "Failed to execute command"
    return None


def match_command(user):
    lowered = re.sub(r"\s+", " ", (user or "").lower()).strip()
    if not lowered:
        return None

    for cmd in sorted(COMMANDS, key=len, reverse=True):
        normalized = re.sub(r"\s+", " ", cmd.lower()).strip()
        pattern = rf"(?<!\w){re.escape(normalized)}(?!\w)"
        if re.search(pattern, lowered):
            return cmd

    return None


def ensure_sir(text):
    if not text:
        return text

    stripped = sanitize_ai_language(text.strip())
    if "sir" in stripped.lower():
        return stripped

    return f"Sir, {stripped}"


def extract_file_path(user):
    quoted_match = re.search(
        r'["\']([^"\']+\.(?:txt|md|html|csv|json|py))["\']',
        user,
        re.IGNORECASE,
    )
    if quoted_match:
        return quoted_match.group(1).strip()

    plain_match = re.search(
        r"\b([\w\s\-/\\]+\.(?:txt|md|html|csv|json|py))\b",
        user,
        re.IGNORECASE,
    )
    if plain_match:
        return plain_match.group(1).strip()

    return None


def looks_like_document_request(user):
    lowered = user.lower()
    file_path = extract_file_path(user)
    create_words = ("create", "make", "write", "generate", "draft", "prepare")
    doc_words = ("document", "file", "report", "letter", "essay", "notes", "text", "code", "script")
    return bool(
        file_path
        and any(word in lowered for word in create_words)
        and any(word in lowered for word in doc_words)
    )


def extract_open_app_name(user):
    match = re.match(r"\s*(?:open|launch|start)\s+(.+?)\s*$", user, re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return None


def looks_like_conversational_message(user):
    lowered = (user or "").strip().lower()
    if not lowered:
        return False

    conversational_phrases = (
        "whats up",
        "what's up",
        "what is up",
        "sup",
        "hello",
        "hi",
        "hey",
        "yo",
        "how are you",
        "how's it going",
        "hows it going",
        "good morning",
        "good afternoon",
        "good evening",
        "good night",
    )
    if lowered in conversational_phrases:
        return True

    conversational_starts = (
        "what ",
        "what's ",
        "whats ",
        "what is ",
        "why ",
        "when ",
        "where ",
        "who ",
        "how ",
        "can ",
        "could ",
        "would ",
        "should ",
        "do ",
        "does ",
        "did ",
        "is ",
        "are ",
        "am ",
        "will ",
        "tell ",
        "explain ",
    )
    return lowered.startswith(conversational_starts)


def is_greeting_message(user):
    compact = re.sub(r"[^a-z0-9]+", " ", (user or "").lower()).strip()
    if not compact:
        return False

    exact_prompts = {
        "hello",
        "hello jarvis",
        "hello sir",
        "hi",
        "hi jarvis",
        "hi sir",
        "hey",
        "hey jarvis",
        "hey sir",
        "yo",
        "yo jarvis",
        "good morning",
        "good morning jarvis",
        "good morning sir",
        "good afternoon",
        "good afternoon jarvis",
        "good afternoon sir",
        "good evening",
        "good evening jarvis",
        "good evening sir",
        "good night",
        "good night jarvis",
        "good night sir",
    }
    if compact in exact_prompts:
        return True

    return bool(
        re.fullmatch(
            r"(hello|hi|hey|yo)(?:\s+(?:there|jarvis|sir))?",
            compact,
        )
    )


def build_greeting_reply():
    return "Hello, sir. J.A.R.V.I.S is online and ready."


def extract_bare_app_name(user):
    requested = (user or "").strip()
    if not requested or len(requested.split()) > 4:
        return None

    if extract_open_app_name(user):
        return None

    if looks_like_conversational_message(user):
        return None

    return requested if find_best_candidate(requested) else None


def extract_whatsapp_request(user):
    match = re.match(
        r"\s*(?:send\s+)?whatsapp(?:\s+message)?\s+(?:to\s+)?(.+?)\s+(?:saying|message|text|that)\s+(.+?)\s*$",
        user,
        re.IGNORECASE,
    )
    if match:
        return match.group(1).strip(), match.group(2).strip()

    compact_match = re.match(
        r"\s*whatsapp\s+(.+?)\s*[:,-]\s*(.+?)\s*$",
        user,
        re.IGNORECASE,
    )
    if compact_match:
        return compact_match.group(1).strip(), compact_match.group(2).strip()

    return None


def is_creator_question(user):
    lowered = user.lower()
    prompts = (
        "who made you",
        "who created you",
        "who built you",
        "who developed you",
        "who is your creator",
        "who is your maker",
    )
    return any(prompt in lowered for prompt in prompts)


def is_name_meaning_question(user):
    lowered = (user or "").lower()
    compact = re.sub(r"[^a-z0-9]+", " ", lowered)
    prompts = (
        "what does your name mean",
        "what does your name stand for",
        "what does jarvis mean",
        "what does jarvis stand for",
        "what is the full form of jarvis",
        "what is jarvis full form",
        "jarvis full form",
        "full form of jarvis",
        "what does j a r v i s stand for",
        "what is the full form of j a r v i s",
        "j a r v i s full form",
        "full form of j a r v i s",
    )
    return any(prompt in lowered or prompt in compact for prompt in prompts)


def build_name_meaning_reply():
    return (
        f"Sir, {ASSISTANT_DISPLAY_NAME} stands for "
        f"{ASSISTANT_FULL_FORM}."
    )


def is_casual_check_in(user):
    compact = re.sub(r"[^a-z0-9]+", " ", (user or "").lower()).strip()
    prompts = (
        "whats up",
        "whats up jarvis",
        "what s up",
        "what s up jarvis",
        "what is up",
        "what is up jarvis",
        "sup",
        "sup jarvis",
    )
    return compact in prompts


def build_casual_check_in_reply():
    return "Sir, all systems are steady and I am ready when you are."


def is_time_or_date_question(user):
    lowered = (user or "").lower()
    prompts = (
        "what time is it",
        "what's the time",
        "whats the time",
        "tell me the time",
        "current time",
        "time right now",
        "local time",
        "what is the date",
        "what's the date",
        "whats the date",
        "what day is it",
        "what day is today",
        "today's date",
        "todays date",
        "date today",
    )
    return any(prompt in lowered for prompt in prompts)


def build_time_or_date_reply():
    now = _current_local_datetime()
    hour = now.hour % 12 or 12
    meridiem = "PM" if now.hour >= 12 else "AM"
    timezone_name = now.tzname() or "local time"
    weekday = now.strftime("%A")
    month = now.strftime("%B")
    return (
        f"Sir, it is {hour}:{now.minute:02d} {meridiem} for you right now on "
        f"{weekday}, {month} {now.day}, {now.year} {timezone_name}."
    )


def is_capability_question(user):
    lowered = (user or "").lower()
    prompts = (
        "can you",
        "could you",
        "are you able",
        "are you capable",
        "what can you do",
        "what can jarvis do",
        "do you support",
        "can jarvis",
        "what are you able to do",
    )
    return any(prompt in lowered for prompt in prompts)


def build_capability_reply(user):
    lowered = (user or "").lower()

    if "whatsapp" in lowered:
        return (
            "Yes, sir. I can help with WhatsApp messages by opening a prefilled "
            "WhatsApp chat on your PC. I resolve the contact from a phone number "
            "or `workspace/whatsapp_contacts.json`, then open the chat with the "
            "message ready for you."
        )

    if any(word in lowered for word in ("open app", "launch", "start ", "open ")):
        return (
            "Yes, sir. I can open apps by matching your request against installed "
            "programs, shortcuts, and Windows app paths, then launching the best "
            "match on your PC."
        )

    if any(word in lowered for word in ("file", "document", "write", "create", "read")):
        return (
            "Yes, sir. I can create and read supported text and code files in the "
            "workspace by writing to or reading from local files."
        )

    if any(word in lowered for word in ("python", "code", "script", "run")):
        return (
            "Yes, sir. I can run Python locally by writing code to a temporary file "
            "and executing it on your machine."
        )

    return (
        "Yes, sir. I can handle supported desktop actions through local tools when "
        "the request matches something Jarvis can do."
    )


def call_llm(user, context=None, memory=None):
    ensure_ollama_running()
    context_block = _format_context_block(context)
    memory_block = _format_memory_block(memory)
    time_block = _live_time_block() if _needs_live_time_context(user) else ""
    prompt = f"""
You are Jarvis AI.
Always address the user as sir.
Never say the phrase "language model". If you need to describe yourself, say AI.
Use the provided memory and recent context to resolve follow-up requests and references.
If the user says "make that" or similar, inspect the recent context before asking for clarification.
Only mention the current date or time if the user explicitly asks for it or the
request genuinely depends on time-sensitive wording such as today or tomorrow.
If a time block is provided below, use it as authoritative context, but do not
repeat it in your reply unless it is relevant.

You can either:
1. Respond normally
2. Use a tool

TOOLS:
- create_file(path, content)
- read_file(path)
- open_app(app_name)
- send_whatsapp(target, message)
- run_python(code)

RULES:
- If the user asks to create, write, or generate a file:
    - You MUST use create_file
    - Only create text or code files such as .txt, .md, .html, .csv, .json, .py
    - If asked for PDF or DOCX, politely say those formats are not supported
    - Generate full detailed content
- If reading a file, use read_file
- If opening apps, use open_app
- If sending a WhatsApp message, use send_whatsapp
- If executing code, use run_python
- If the user asks whether you can do something and a local tool supports it,
  answer yes and briefly explain how Jarvis AI does it.
- Be honest about limits. For example, do not claim direct WhatsApp sending if
  the app only opens a prefilled chat.

{time_block}

{memory_block}

{context_block}

RESPONSE FORMAT (STRICT):

If using tool:
{{"action": "tool_name", "args": {{...}}}}

If normal reply:
{{"action": null, "response": "your message"}}

NO extra text outside JSON.

Current user message: {user}
"""

    response = requests.post(
        URL,
        json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
        },
        timeout=None,
    )

    return response.json().get("response", "")


def stream_llm_chat(user, context=None, memory=None) -> Generator[str, None, None]:
    ensure_ollama_running()
    context_block = _format_context_block(context)
    memory_block = _format_memory_block(memory)
    time_block = _live_time_block() if _needs_live_time_context(user) else ""
    prompt = f"""
You are Jarvis AI.
Always address the user as sir.
Never say the phrase "language model". If you need to describe yourself, say AI.
Be concise, direct, and helpful.
Do not use JSON.
Reply as normal natural language only.
Use the provided memory and recent context to resolve follow-up requests and references.
If the user says "make that" or similar, inspect the recent context before asking for clarification.
Only mention the current date or time if the user explicitly asks for it or the
request genuinely depends on time-sensitive wording such as today or tomorrow.
If a time block is provided below, use it as authoritative context, but do not
repeat it in your reply unless it is relevant.

If the user asks whether you can do something and a local tool supports it,
answer yes and briefly explain how Jarvis AI does it.
Be honest about limits. Do not claim direct WhatsApp sending if the app only
opens a prefilled chat.

{time_block}

{memory_block}

{context_block}

Current user message: {user}
"""

    with requests.post(
        URL,
        json={
            "model": MODEL,
            "prompt": prompt,
            "stream": True,
        },
        stream=True,
        timeout=None,
    ) as response:
        response.raise_for_status()
        response.encoding = "utf-8"
        for raw_line in response.iter_lines(chunk_size=1, decode_unicode=True):
            if not raw_line:
                continue

            data = json.loads(raw_line)
            chunk = data.get("response", "")
            if chunk:
                yield sanitize_ai_language(chunk)


def generate_document_content(user, path):
    ensure_ollama_running()
    prompt = f"""
You are writing content for a file.
Always write for the user respectfully as sir when relevant.

Target file: {path}

Write the full file content requested by the user.
Return only the raw content for the file.
Do not wrap it in JSON.
Do not explain anything.
Do not add markdown code fences unless the file itself requires them.

User request: {user}
"""

    response = requests.post(
        URL,
        json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
        },
        timeout=None,
    )

    return response.json().get("response", "").strip()


def parse_response(text):
    try:
        data = json.loads(text)

        action = data.get("action")
        args = data.get("args", {})
        response = data.get("response")

        return action, args, response
    except Exception:
        return None, None, None


def handle_fast_path(user):
    if is_greeting_message(user):
        return build_greeting_reply()

    if is_name_meaning_question(user):
        return build_name_meaning_reply()

    if is_casual_check_in(user):
        return build_casual_check_in_reply()

    if is_time_or_date_question(user):
        return build_time_or_date_reply()

    if is_creator_question(user):
        return "Sir, I was made by darkfire, to be used as a desktop assistant."

    if is_capability_question(user):
        return ensure_sir(build_capability_reply(user))

    action = run_command(user)
    if action:
        return ensure_sir(action)

    whatsapp_request = extract_whatsapp_request(user)
    if whatsapp_request:
        target, message = whatsapp_request
        return ensure_sir(
            execute("send_whatsapp", {"target": target, "message": message})
        )

    app_name = extract_open_app_name(user)
    if app_name:
        return ensure_sir(execute("open_app", {"app_name": app_name}))

    app_name = extract_bare_app_name(user)
    if app_name:
        return ensure_sir(execute("open_app", {"app_name": app_name}))

    if any(word in user.lower() for word in [".pdf", ".docx", "pdf", "docx"]):
        return (
            "Sir, PDF and DOCX generation have been removed. "
            "I can create text and code files like .txt, .md, .html, .csv, .json, and .py."
        )

    if looks_like_document_request(user):
        path = extract_file_path(user)
        if path:
            content = generate_document_content(user, path)
            if content:
                return ensure_sir(
                    execute("create_file", {"path": path, "content": content})
                )

    return None


def should_use_tool_flow(user):
    lowered = user.lower().strip()
    if not lowered:
        return False

    if match_command(user):
        return True

    if extract_open_app_name(user) or extract_whatsapp_request(user):
        return True

    if looks_like_document_request(user):
        return True

    tool_prefixes = (
        "open ",
        "launch ",
        "start ",
        "whatsapp ",
        "send whatsapp ",
        "read ",
        "create ",
        "write ",
        "generate ",
        "make ",
        "run ",
    )
    return lowered.startswith(tool_prefixes)


def chunk_text(text, chunk_size=18):
    if not text:
        return

    words = text.split()
    if not words:
        yield text
        return

    current = []
    current_length = 0

    for word in words:
        additional = len(word) + (1 if current else 0)
        if current and current_length + additional > chunk_size:
            yield " ".join(current) + " "
            current = [word]
            current_length = len(word)
            continue

        current.append(word)
        current_length += additional

    if current:
        yield " ".join(current)


def ask(user, context=None, memory=None, prompt_user=None):
    fast_path = handle_fast_path(user)
    if fast_path:
        return fast_path

    llm_output = call_llm(prompt_user or user, context=context, memory=memory)
    action, args, response = parse_response(llm_output)

    if action:
        result = execute(action, args)
        return ensure_sir(result)

    if response:
        return ensure_sir(response)

    return "Sir, I ran into an invalid response from the AI."


def stream_ask(user, context=None, memory=None, prompt_user=None) -> Generator[str, None, None]:
    fast_path = handle_fast_path(user)
    if fast_path:
        yield fast_path
        return

    if should_use_tool_flow(user):
        result = ask(user, context=context, memory=memory, prompt_user=prompt_user)
        for chunk in chunk_text(result):
            yield chunk
        return

    has_output = False
    try:
        for chunk in stream_llm_chat(prompt_user or user, context=context, memory=memory):
            has_output = True
            yield chunk
    except Exception:
        if not has_output:
            yield ask(user, context=context, memory=memory, prompt_user=prompt_user)
            return

    if not has_output:
        yield ask(user, context=context, memory=memory, prompt_user=prompt_user)


if __name__ == "__main__":
    while True:
        user = input("You: ")
        if user.lower() in ["exit", "quit"]:
            break

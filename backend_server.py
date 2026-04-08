import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading

from jarvis import (
    ASSISTANT_DISPLAY_NAME,
    ASSISTANT_FULL_FORM,
    ASSISTANT_NAME_EXPLANATION,
    ask,
    generate_memory_snapshot,
    stream_ask,
)


BACKEND_VERSION = "5"
WORKSPACE_DIR = Path(__file__).resolve().parent / "workspace"
MEMORY_PATH = WORKSPACE_DIR / "jarvis-memory.json"
TEXT_ATTACHMENT_EXTENSIONS = {".txt", ".md", ".html", ".csv", ".json", ".py"}


def default_memory_state():
    return {
        "summary": "",
        "preferences": {
            "preferredTone": "balanced",
            "defaultAppTargets": {},
        },
        "assistantProfile": {
            "displayName": ASSISTANT_DISPLAY_NAME,
            "fullForm": ASSISTANT_FULL_FORM,
            "meaning": ASSISTANT_NAME_EXPLANATION,
        },
    }


def merge_memory_state(*states):
    merged = default_memory_state()

    for state in states:
        if not isinstance(state, dict):
            continue

        summary = str(state.get("summary", "")).strip()
        if summary:
            merged["summary"] = summary

        preferences = state.get("preferences", {})
        if isinstance(preferences, dict):
            preferred_tone = str(preferences.get("preferredTone", "")).strip()
            if preferred_tone:
                merged["preferences"]["preferredTone"] = preferred_tone
            default_app_targets = preferences.get("defaultAppTargets", {})
            if isinstance(default_app_targets, dict):
                merged["preferences"]["defaultAppTargets"].update(
                    {
                        str(key): str(value)
                        for key, value in default_app_targets.items()
                        if str(key).strip() and str(value).strip()
                    }
                )

        assistant_profile = state.get("assistantProfile", {})
        if isinstance(assistant_profile, dict):
            for key in ("displayName", "fullForm", "meaning"):
                value = str(assistant_profile.get(key, "")).strip()
                if value:
                    merged["assistantProfile"][key] = value

    return merged


def load_memory_state():
    if not MEMORY_PATH.exists():
        return default_memory_state()

    try:
        decoded = json.loads(MEMORY_PATH.read_text(encoding="utf-8"))
        return merge_memory_state(decoded)
    except Exception:
        return default_memory_state()


def save_memory_state(state):
    MEMORY_PATH.parent.mkdir(parents=True, exist_ok=True)
    MEMORY_PATH.write_text(
        json.dumps(merge_memory_state(state), indent=2, ensure_ascii=True),
        encoding="utf-8",
    )


def normalize_context(context):
    if not context:
        return []

    normalized = []
    for item in context:
        if isinstance(item, dict):
            role = str(item.get("role", "user")).strip().lower()
            text = str(item.get("text", "")).strip()
            if text:
                normalized.append({"role": role, "text": text})
    return normalized


def schedule_memory_update(user_message, assistant_text, context, current_memory):
    def worker():
        try:
            next_state = generate_memory_snapshot(
                user_message,
                assistant_text,
                context=context,
                memory=current_memory,
            )
            save_memory_state(next_state)
        except Exception:
            pass

    threading.Thread(target=worker, daemon=True).start()


def normalize_message(message, attachments):
    base_message = message.strip() if message else ""

    if not attachments:
        return base_message

    attachment_blocks = []
    for attachment in attachments:
        path_value = str(attachment.get("path", "")).strip()
        if not path_value:
            continue

        file_path = Path(path_value)
        suffix = file_path.suffix.lower()
        block = [f"Attachment path: {file_path}"]

        if suffix in TEXT_ATTACHMENT_EXTENSIONS and file_path.exists():
            try:
                content = file_path.read_text(encoding="utf-8", errors="ignore")
                trimmed = content[:6000]
                block.append("Attachment content:")
                block.append(trimmed)
            except Exception:
                block.append("Attachment content could not be read.")
        else:
            block.append("Attachment is non-text or not directly readable. Use the file path for context.")

        attachment_blocks.append("\n".join(block))

    if not attachment_blocks:
        return base_message

    if not base_message:
        base_message = "Please review the attached context and help the user."

    return (
        f"{base_message}\n\n"
        "Additional attached context:\n"
        + "\n\n".join(attachment_blocks)
    )


class JarvisRequestHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self._send_json(
                200,
                {
                    "ok": True,
                    "version": BACKEND_VERSION,
                },
            )
            return

        self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        if self.path not in ("/ask", "/ask_stream"):
            self._send_json(404, {"error": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length).decode("utf-8") if content_length else "{}"

        try:
            payload = json.loads(raw_body)
            user_message = payload.get("message", "").strip()
            attachments = payload.get("attachments", [])
            context = normalize_context(payload.get("context", []))
            current_memory = merge_memory_state(
                load_memory_state(),
                payload.get("memory", {}),
            )

            if not user_message and not attachments:
                self._send_json(
                    400,
                    {"error": "A message or attachment is required."},
                )
                return

            full_message = normalize_message(user_message, attachments)

            if self.path == "/ask_stream":
                self.send_response(200)
                self.send_header("Content-Type", "application/x-ndjson; charset=utf-8")
                self.send_header("Cache-Control", "no-cache")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()

                assistant_chunks = []
                try:
                    for chunk in stream_ask(
                        user_message,
                        context=context,
                        memory=current_memory,
                        prompt_user=full_message,
                    ):
                        body = json.dumps({"type": "token", "content": chunk}) + "\n"
                        assistant_chunks.append(chunk)
                        self.wfile.write(body.encode("utf-8"))
                        self.wfile.flush()
                except Exception as exc:
                    body = json.dumps({"type": "error", "content": str(exc)}) + "\n"
                    self.wfile.write(body.encode("utf-8"))
                    self.wfile.flush()

                self.wfile.write(b'{"type":"done"}\n')
                self.wfile.flush()
                assistant_text = "".join(assistant_chunks).strip()
                if assistant_text:
                    schedule_memory_update(
                        user_message,
                        assistant_text,
                        context,
                        current_memory,
                    )
                return

            reply = ask(
                user_message,
                context=context,
                memory=current_memory,
                prompt_user=full_message,
            )
            self._send_json(200, {"reply": reply})
            if reply:
                schedule_memory_update(
                    user_message,
                    reply,
                    context,
                    current_memory,
                )
        except Exception as exc:
            self._send_json(500, {"error": str(exc)})

    def log_message(self, format, *args):
        return


def run_server(host="127.0.0.1", port=8767):
    if not MEMORY_PATH.exists():
        save_memory_state(default_memory_state())
    server = ThreadingHTTPServer((host, port), JarvisRequestHandler)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    run_server()

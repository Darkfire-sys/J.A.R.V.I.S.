import os

BASE_DIR = "workspace"


def create_file(path, content):
    full_path = os.path.join(BASE_DIR, path)
    parent_dir = os.path.dirname(full_path)
    if parent_dir:
        os.makedirs(parent_dir, exist_ok=True)

    ext = os.path.splitext(path)[1].lower()

    try:
        # ---------- TEXT FILES ----------
        if ext in [".txt", ".py", ".json", ".html", ".md", ".csv"]:
            with open(full_path, "w", encoding="utf-8") as f:
                f.write(content)
            return f"File created at {full_path}"

        # ---------- FALLBACK ----------
        else:
            return "Unsupported file type. Sir, I can currently create text and code files only."

    except Exception as e:
        return f"Error creating file: {e}"


def read_file(path):
    full_path = os.path.join(BASE_DIR, path)

    try:
        ext = os.path.splitext(path)[1].lower()

        if ext in [".txt", ".py", ".json", ".html", ".md", ".csv"]:
            with open(full_path, "r", encoding="utf-8") as f:
                return f.read()

        else:
            return "Unsupported file type. Sir, I can currently read text and code files only."

    except Exception as e:
        return f"Error reading file: {e}"

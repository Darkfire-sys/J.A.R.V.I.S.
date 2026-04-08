from tools.file_ops import create_file, read_file
from tools.app_control import open_app, send_whatsapp_message
from tools.code_runner import run_python

TOOLS = {
    "create_file": create_file,
    "read_file": read_file,
    "open_app": open_app,
    "send_whatsapp": send_whatsapp_message,
    "run_python": run_python
}

def execute(action, args):
    if action in TOOLS:
        return TOOLS[action](**args)
    return "Unknown action"

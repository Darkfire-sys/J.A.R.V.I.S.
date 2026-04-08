# tools/code_runner.py

import subprocess
import tempfile
import os


def run_python(code):
    temp_file = None

    try:
        # create temp file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".py", mode="w") as f:
            f.write(code)
            temp_file = f.name

        # run it
        result = subprocess.run(
            ["python", temp_file],
            capture_output=True,
            text=True,
            timeout=10
        )

        output = result.stdout + result.stderr

        return output if output else "[no output]"

    except Exception as e:
        return str(e)

    finally:
        if temp_file and os.path.exists(temp_file):
            os.remove(temp_file)
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


PINEVEX_ROOT = Path(
    r"C:\Users\Ryan Bridges\OneDrive\Documents\pinevex-renderer"
)

PINEVEX_PYTHON = PINEVEX_ROOT / ".venv" / "Scripts" / "python.exe"

HEALTH_URL = "http://127.0.0.1:8000/health"
PREVIEW_URL = "http://127.0.0.1:8000/preview.png"

DEFAULT_VIEWPORT = [1920, 1080]


def pinevex_is_running():
    try:
        with urllib.request.urlopen(HEALTH_URL, timeout=2) as response:
            data = json.loads(response.read().decode("utf-8"))
            return data.get("status") == "ok"
    except Exception:
        return False


def start_pinevex():
    if pinevex_is_running():
        return

    print("Pinevex is not running. Starting it...")

    if not PINEVEX_ROOT.exists():
        print("ERROR: Pinevex installation was not found:")
        print(PINEVEX_ROOT)
        sys.exit(1)

    if not PINEVEX_PYTHON.exists():
        print("ERROR: Pinevex virtual environment was not found:")
        print(PINEVEX_PYTHON)
        sys.exit(1)

    subprocess.Popen(
        [
            str(PINEVEX_PYTHON),
            "-m",
            "uvicorn",
            "api.index:app",
            "--host",
            "127.0.0.1",
            "--port",
            "8000",
        ],
        cwd=str(PINEVEX_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )

    for _ in range(30):
        time.sleep(0.5)

        if pinevex_is_running():
            print("Pinevex started successfully.")
            return

    print("ERROR: Pinevex failed to start.")
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python tools/pinevex/render.py <design.json>")
        print("")
        print("Example:")
        print("  python tools/pinevex/render.py ui-designs/Inventory.json")
        sys.exit(1)

    project_root = Path(__file__).resolve().parents[2]

    input_path = Path(sys.argv[1])

    if not input_path.is_absolute():
        input_path = project_root / input_path

    if not input_path.exists():
        print("ERROR: UI design not found:")
        print(input_path)
        sys.exit(1)

    try:
        with input_path.open("r", encoding="utf-8") as file:
            design = json.load(file)

    except json.JSONDecodeError as error:
        print("ERROR: Invalid JSON.")
        print(error)
        sys.exit(1)

    if "pinevex_object" in design:
        payload = design
    else:
        payload = {
            "pinevex_object": design,
            "viewport_size": DEFAULT_VIEWPORT,
            "transparent_background": False,
        }

    if "viewport_size" not in payload:
        payload["viewport_size"] = DEFAULT_VIEWPORT

    start_pinevex()

    request_data = json.dumps(payload).encode("utf-8")

    request = urllib.request.Request(
        PREVIEW_URL,
        data=request_data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            image_data = response.read()

    except urllib.error.URLError as error:
        print("ERROR: Pinevex render failed.")
        print(error)
        sys.exit(1)

    preview_directory = project_root / ".ui-previews"
    preview_directory.mkdir(parents=True, exist_ok=True)

    output_path = preview_directory / f"{input_path.stem}.png"

    with output_path.open("wb") as file:
        file.write(image_data)

    print("")
    print("Pinevex render successful.")
    print(f"Input:    {input_path}")
    print(f"Preview:  {output_path}")
    print(
        f"Viewport: {payload['viewport_size'][0]}x"
        f"{payload['viewport_size'][1]}"
    )
    print("")


if __name__ == "__main__":
    main()
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


PINEVEX_URL = "http://127.0.0.1:8000/preview.png"
DEFAULT_VIEWPORT = [1920, 1080]


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
        print(f"ERROR: UI design not found:")
        print(input_path)
        sys.exit(1)

    try:
        with input_path.open("r", encoding="utf-8") as file:
            design = json.load(file)
    except json.JSONDecodeError as error:
        print("ERROR: Invalid JSON.")
        print(error)
        sys.exit(1)

    # Support either:
    #
    # 1. A raw Pinevex UI object:
    #    {
    #       "type": "Frame",
    #       ...
    #    }
    #
    # or:
    #
    # 2. A complete Pinevex API request:
    #    {
    #       "pinevex_object": {...},
    #       "viewport_size": [...]
    #    }

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

    request_data = json.dumps(payload).encode("utf-8")

    request = urllib.request.Request(
        PINEVEX_URL,
        data=request_data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request) as response:
            image_data = response.read()

    except urllib.error.URLError as error:
        print("ERROR: Could not connect to Pinevex.")
        print("")
        print("Make sure the Pinevex server is running at:")
        print("http://127.0.0.1:8000")
        print("")
        print(error)
        sys.exit(1)

    preview_directory = project_root / ".ui-previews"
    preview_directory.mkdir(parents=True, exist_ok=True)

    output_path = preview_directory / f"{input_path.stem}.png"

    with output_path.open("wb") as file:
        file.write(image_data)

    print("")
    print("Pinevex render successful.")
    print(f"Input:   {input_path}")
    print(f"Preview: {output_path}")
    print(f"Viewport: {payload['viewport_size'][0]}x{payload['viewport_size'][1]}")
    print("")


if __name__ == "__main__":
    main()
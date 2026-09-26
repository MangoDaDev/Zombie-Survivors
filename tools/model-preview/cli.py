"""Blender entry point; also supports validation/export under ordinary Python 3.11+."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from schema import validate, ValidationError, LIMITATIONS, parse_json
from settings import validate_settings
from luau import parse_source, export_luau, canonical_definition
from reports import dump, sha


def load_input(path):
    if path == "-":
        sys.stdin.reconfigure(encoding="utf-8")
        if sys.stdin.isatty():
            print("Paste JSON, then Ctrl+Z followed by Enter (Windows), or pipe JSON to stdin.", flush=True)
        source = sys.stdin.read(8*1024*1024+1)
    else:
        if Path(path).stat().st_size > 8*1024*1024:
            raise ValidationError("input: maximum definition size is 8 MiB")
        source = Path(path).read_text(encoding="utf-8-sig")
    if len(source.encode("utf-8")) > 8*1024*1024:
        raise ValidationError("input: maximum definition size is 8 MiB")
    return validate(parse_source(source))


def tool_hash():
    files = sorted(list(ROOT.glob("*.py"))+list(ROOT.glob("*.ps1"))+list(ROOT.glob("*.cmd")))
    digest = hashlib.sha256()
    for file in files:
        digest.update(file.name.encode())
        digest.update(file.read_bytes())
    return digest.hexdigest()


def render(model, settings, output):
    import bpy
    from backend import make_scene, cameras, render_view
    from reports import report, contact_layout
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # Render in a sibling temporary directory. Invalid input or failed rendering must
    # not overwrite the previous useful preview or leave a partial result in its place.
    with tempfile.TemporaryDirectory(prefix=".model-preview-", dir=output.parent) as staging:
        stage = Path(staging)
        scene = make_scene(model, settings)
        views = cameras(model, settings)
        for name, camera in views.items():
            print("Rendering "+name, flush=True)
            render_view(scene, camera, stage/(name+".png"))
        report(model, settings, views, stage)
        dump(stage/"definition.json", canonical_definition(model))
        (stage/"construction.luau").write_text(export_luau(model), encoding="utf-8")
        contact_layout(model, views, stage)
        subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        str(ROOT/"compose-sheet.ps1"), "-Directory", str(stage)], check=True,
                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        hashes = {p.name: sha(p) for p in sorted(stage.iterdir())}
        dump(stage/"manifest.json", dict(toolVersion=1, toolSha256=tool_hash(), blenderVersion=bpy.app.version_string,
             blenderBuild=bpy.app.build_hash.decode(), platform=sys.platform, pythonVersion=sys.version.split()[0],
             settings=settings, files=hashes))
        # Only replace this invocation's named artifacts; never delete arbitrary files
        # from a user-supplied output directory. The manifest lists the current output.
        for artifact in sorted(stage.iterdir()):
            os.replace(artifact, output/artifact.name)
    print("Output: "+str(output), flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Render exact JSON model construction through headless Blender.")
    parser.add_argument("command", choices=("render", "validate", "export", "test"))
    parser.add_argument("input", nargs="?", default="-")
    parser.add_argument("--out", default=str(ROOT/"renders"/"preview"))
    parser.add_argument("--settings")
    parser.add_argument("--views", help="comma-separated front,back,left,right,top,bottom,perspective")
    parser.add_argument("--projection", choices=("orthographic", "perspective"))
    parser.add_argument("--resolution", help="WIDTHxHEIGHT")
    parser.add_argument("--transparent", action="store_true")
    parser.add_argument("--samples", type=int)
    parser.add_argument("--render-tests", action="store_true")
    args = parser.parse_args(argv)
    if args.command == "test":
        import unittest
        if args.render_tests:
            os.environ["MODEL_PREVIEW_RENDER_TESTS"] = "1"
        suite = unittest.defaultTestLoader.discover(str(ROOT/"tests"))
        result = unittest.TextTestRunner(verbosity=2, stream=sys.stdout).run(suite)
        if not result.wasSuccessful():
            raise RuntimeError("model-preview tests failed")
        return
    model = load_input(args.input)
    raw = parse_json(Path(args.settings).read_text(encoding="utf-8-sig")) if args.settings else {}
    if not isinstance(raw, dict):
        raise ValidationError("$settings: expected JSON object")
    if args.views is not None:
        raw["views"] = args.views.split(",") if args.views else []
    if args.projection:
        raw["projection"] = args.projection
    if args.resolution:
        if not re.fullmatch(r"[0-9]+x[0-9]+", args.resolution):
            raise ValidationError("--resolution: expected WIDTHxHEIGHT, for example 640x480")
        raw["resolution"] = list(map(int, args.resolution.split("x")))
    if args.transparent:
        raw["transparent"] = True
    if args.samples is not None:
        raw["samples"] = args.samples
    settings = validate_settings(raw)
    if args.command == "validate":
        print(f"Valid: {len(model['nodes'])} instances, {len(model['parts'])} Parts")
    elif args.command == "export":
        output = Path(args.out)
        output.mkdir(parents=True, exist_ok=True)
        dump(output/"definition.json", canonical_definition(model))
        (output/"construction.luau").write_text(export_luau(model), encoding="utf-8")
        print("Exported: "+str(output.resolve()))
    else:
        if os.name != "nt":
            raise ValidationError("render: this local tool uses Windows PowerShell/System.Drawing for its PNG contact sheet")
        render(model, settings, Path(args.out))
    for warning in LIMITATIONS:
        print("NOTE: "+warning)


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:]
    try:
        main(arguments)
    except (ValidationError, OSError, subprocess.CalledProcessError) as error:
        print("ERROR: "+str(error), file=sys.stderr, flush=True)
        # Raise for Blender --python-exit-code; SystemExit is swallowed by some builds.
        raise RuntimeError("model-preview command failed; see ERROR above") from None

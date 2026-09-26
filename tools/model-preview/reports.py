"""Separate complete property reports and a small, readable inspection contact sheet."""
import hashlib
import html
import json
import math
from pathlib import Path
from schema import LIMITATIONS, REPORT_ONLY, part_points, pivot
from transforms import bounds, bounds_corners, project, add, mul, sub


def dump(path, data):
    Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=True, sort_keys=True, allow_nan=False)+"\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def report(model, settings, cameras, output):
    lo, hi = bounds(part_points(model))
    def entry(n):
        return dict(name=n["name"], className=n["className"], id=n["id"], sourcePath=n["path"],
                    properties=n["properties"], effectivePivot=pivot(n, model), children=[entry(c) for c in n["children"]])
    data = dict(hierarchy=entry(model["root"]), worldBounds=dict(min=lo, max=hi, dimensions=sub(hi, lo)),
                units="studs", settings=settings, cameras=cameras, limitations=LIMITATIONS,
                reportOnlyProperties=REPORT_ONLY)
    dump(output/"properties.json", data)
    def tree(n):
        title = html.escape(n["name"]+" ("+n["className"]+")")
        rows = "".join(f"<tr><th>{html.escape(k)}</th><td><code>{html.escape(json.dumps(v, ensure_ascii=False))}</code></td></tr>" for k, v in sorted(n["properties"].items()))
        rows += f'<tr><th>Effective pivot</th><td><code>{html.escape(json.dumps(n["effectivePivot"]))}</code></td></tr>'
        identity = html.escape(n["sourcePath"]+" | ID: "+(n["id"] or "(none)"))
        return f'<details open><summary>{title}</summary><p>{identity}</p><table>{rows}</table>'+"".join(tree(c) for c in n["children"])+"</details>"
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Model properties</title>
<style>body{font:15px system-ui;max-width:1200px;margin:32px auto;padding:0 24px;color:#172332;background:#f5f7fa}
details{margin:16px 0 16px 20px;padding-left:12px;border-left:2px solid #acbbcc}summary{font-weight:700;cursor:pointer}
table{border-collapse:collapse;width:100%;background:white}th,td{padding:7px 12px;text-align:left;border:1px solid #d6dee8}th{width:220px}code{overflow-wrap:anywhere}p{color:#46566a}</style>'''
    document += "<h1>"+html.escape(model["root"]["name"])+" — properties</h1>"
    document += "<p>All normalized supported property values, including defaults. Coordinates and dimensions are in studs.</p>"
    document += "<ul>"+"".join("<li>"+html.escape(s)+"</li>" for s in LIMITATIONS)+"</ul>"
    document += "<p>World AABB dimensions: "+" × ".join(f"{v:.5g}" for v in sub(hi, lo))+" studs.</p>"
    document += tree(data["hierarchy"])+"</html>"
    (output/"properties.html").write_text(document, encoding="utf-8")


def contact_layout(model, cameras, output):
    lo, hi = bounds(part_points(model))
    corners = bounds_corners((lo, hi))
    dimensions = sub(hi, lo)
    model_pivot = pivot(model["root"], model)
    tile_w, tile_h = 480, 440
    columns = min(2 if len(cameras) <= 4 else 3, len(cameras))
    rows = math.ceil(len(cameras)/columns)
    footer_height = 170 if columns == 1 else 120
    layout = dict(width=columns*tile_w, height=100+rows*tile_h+footer_height, footerHeight=footer_height,
                  title=model["root"]["name"], dimensions="X / Y / Z: "+" / ".join(f"{d:.5g}" for d in dimensions)+" studs",
                  footer=["Dashed: world AABB | Magenta: pivot | RGB: local X/Y/Z | White bar: 1 stud at target depth",
                          "Pivot world position: ("+", ".join(f"{v:.5g}" for v in model_pivot[:3])+") studs. Off-frame markers are clipped.",
                          "Offline material/stud shading approximation. Complete hierarchy and values: properties.html"], panels=[])
    for index, (name, camera) in enumerate(cameras.items()):
        x, y = (index % columns)*tile_w, 100+(index//columns)*tile_h
        available_w, available_h = tile_w-24, tile_h-58
        ratio = min(available_w/camera["width"], available_h/camera["height"])
        width, height = camera["width"]*ratio, camera["height"]*ratio
        left, top = x+(tile_w-width)/2, y+34+(available_h-height)/2
        def pos(point):
            a, b = project(camera, point)
            return [left+a*ratio, top+b*ratio]
        lines = []
        for a in range(8):
            for b in range(a+1, 8):
                if (a ^ b) in (1, 2, 4):
                    lines.append(dict(a=pos(corners[a]), b=pos(corners[b]), color="#9AAABD", dashed=True))
        center = model_pivot[:3]
        axis_length = max(dimensions)*.16
        for i, color in enumerate(("#FF6464", "#67E08B", "#72ACFF")):
            axis = model_pivot[3+i::3]
            lines.append(dict(a=pos(center), b=pos(add(center, mul(axis, axis_length))), color=color, dashed=False))
        # Scale is calibrated at the look-at target plane, rather than claiming a
        # perspective image has a single world-to-pixel scale at every depth.
        a = project(camera, camera["target"])
        b = project(camera, add(camera["target"], camera["right"]))
        scale_length = min(width-24, math.dist(a, b)*ratio)
        visible_scale = scale_length/(math.dist(a, b)*ratio)
        layout["panels"].append(dict(name=name+" / "+camera["projection"], file=name+".png", x=x, y=y,
            left=left, top=top, width=width, height=height, lines=lines, pivot=pos(center),
            scaleLength=scale_length, scaleLabel=f"{visible_scale:.3g} stud"))
    dump(output/"contact-layout.json", layout)
    return layout

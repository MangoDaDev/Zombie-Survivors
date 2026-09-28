"""Author the house as deterministic construction records, then use preview.cmd to render.

This is a local authoring recipe, never a runtime generator or a Studio script.
All shapes are rectangular Plastic Parts with all six surfaces set to Studs.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COLORS = {
    "wall": [227, 215, 178], "trim": [248, 237, 208], "wood": [100, 69, 48],
    "roof": [51, 78, 91], "roofEdge": [37, 56, 68], "door": [46, 106, 96],
    "glass": [116, 175, 190], "stone": [123, 130, 124], "stoneLight": [167, 172, 159],
    "brick": [151, 74, 52], "brickLight": [177, 94, 66], "dark": [41, 40, 37],
    "grass": [103, 133, 64], "leaf": [65, 100, 48], "leafLight": [86, 122, 54],
    "soil": [86, 64, 43], "flower": [213, 141, 58], "flowerRed": [185, 74, 66],
    "gold": [203, 153, 67], "path": [195, 184, 153],
}
SURFACES = {face+"Surface": "Studs" for face in ("Top", "Bottom", "Front", "Back", "Left", "Right")}


def group(name, parent):
    node = {"class": "Model", "name": name, "children": []}
    parent["children"].append(node)
    return node


def block(parent, name, size, position, color, rotation=None, **properties):
    props = {"Size": size, "CFrame": {"position": position, "rotationDegrees": rotation or [0, 0, 0]},
             "Color": [v/255 for v in COLORS[color]], "Material": "Plastic", "Shape": "Block",
             "Anchored": True, **SURFACES, **properties}
    parent["children"].append({"class": "Part", "name": name, "properties": props})


house = {"class": "Model", "name": "Willow Cottage", "properties": {"WorldPivot": {"position": [0, 0, 0]}}, "children": []}
site = group("Garden and approach", house)
shell = group("House shell", house)
windows = group("Windows and shutters", house)
roof = group("Stepped gable roof", house)
porch = group("Covered front porch", house)
details = group("Doors and fittings", house)
interior = group("Ground floor furnishings", house)

block(site, "Lawn plinth", [30, .7, 29], [0, -.35, -.5], "grass")
block(shell, "Stone foundation", [19, 1, 15], [0, .5, 1], "stone")
block(shell, "Foundation cap", [19.5, .3, 15.5], [0, 1.15, 1], "stoneLight")
block(shell, "Ground floor", [17.4, .25, 13.4], [0, 1.42, 1], "wood")
block(shell, "Upper floor", [17.4, .35, 13.4], [0, 7.25, 1], "wood")


def facade(parent, name, axis, fixed, width, low, high, openings, color="wall", thickness=.6):
    """Cut actual openings by horizontal bands; do not hide solid walls behind glass."""
    heights = sorted({low, high, *[h for opening in openings for h in opening[2:] if low < h < high]})
    for band, (bottom, top) in enumerate(zip(heights, heights[1:])):
        cuts = sorted((max(-width/2, a), min(width/2, b)) for a, b, c, d in openings if c < (bottom+top)/2 < d and a < width/2 and b > -width/2)
        cursor = -width/2
        visible = []
        for a, b in cuts:
            if a > cursor: visible.append((cursor, a))
            cursor = max(cursor, b)
        if cursor < width/2: visible.append((cursor, width/2))
        for segment, (a, b) in enumerate(visible):
            size = [b-a, top-bottom, thickness] if axis == "x" else [thickness, top-bottom, b-a]
            pos = [(a+b)/2, (bottom+top)/2, fixed] if axis == "x" else [fixed, (bottom+top)/2, (a+b)/2+1]
            block(parent, f"{name} band {band+1} section {segment+1}", size, pos, color)


front_openings = [(-1.7, 1.7, 1.3, 6.6)]
front_openings += [(x-1.5, x+1.5, y-1.6, y+1.6) for x in (-5.5, 5.5) for y in (4.6, 10.25)]
facade(shell, "Front wall", "x", -6, 18, 1.3, 13.4, front_openings)
back_openings = [(x-1.5, x+1.5, y-1.6, y+1.6) for x in (-5, 5) for y in (4.6, 10.25)]
facade(shell, "Back wall", "x", 8, 18, 1.3, 13.4, back_openings)
side_openings = [(u-1.3, u+1.3, y-1.6, y+1.6) for u in (-3.5, 3.5) for y in (4.6, 10.25)]
for x, label in ((-8.7, "Left"), (8.7, "Right")):
    facade(shell, label+" wall", "z", x, 13.4, 1.3, 13.4, side_openings)


def window(name, axis, fixed, u, y, width=3, shutters=True, outward=-1):
    assembly = group(name, windows)
    def part(label, w, h, depth, du, dy, offset, col, **extra):
        size = [w, h, depth] if axis == "x" else [depth, h, w]
        pos = [u+du, y+dy, fixed+outward*offset] if axis == "x" else [fixed+outward*offset, y+dy, u+du]
        block(assembly, label, size, pos, col, **extra)
    part("Blue pane", width, 3.2, .12, 0, 0, 0, "glass", Transparency=.25, Reflectance=.1, CanCollide=False)
    for du in (-width/2, width/2): part("Side casing", .28, 3.6, .26, du, 0, .38, "trim")
    for dy in (-1.75, 1.75): part("Lintel and sill", width+.6, .3, .4, 0, dy, .42, "trim")
    part("Center mullion", .18, 3.2, .18, 0, 0, .38, "trim")
    part("Cross rail", width, .16, .18, 0, 0, .38, "trim")
    if shutters:
        for sign in (-1, 1):
            du = sign*(width/2+.62)
            part("Shutter panel", .65, 3.2, .18, du, 0, .35, "door")
            for dy in (-1.1, 1.1): part("Shutter strap", .7, .15, .14, du, dy, .48, "wood")
    return assembly


for x in (-5.5, 5.5):
    for y in (4.6, 10.25): window("Front window", "x", -6, x, y)
for x in (-5, 5):
    for y in (4.6, 10.25): window("Rear window", "x", 8, x, y, outward=1)
for x, sign, label in ((-8.7, -1, "West"), (8.7, 1, "East")):
    for z in (-2.5, 4.5):
        for y in (4.6, 10.25): window(label+" window", "z", x, z, y, 2.6, False, sign)

# Broad structural timber gives the facade readable divisions at gameplay scale.
for x in (-8.85, 8.85):
    for z in (-6.15, 8.15): block(shell, "Corner timber", [.38, 12.2, .38], [x, 7.35, z], "wood")
for y in (1.65, 7.3, 13.1):
    for z in (-6.36, 8.36): block(shell, "Front and rear belt course", [18.3, .35, .22], [0, y, z], "trim")
    for x in (-9.04, 9.04): block(shell, "Side belt course", [.22, .35, 14.3], [x, y, 1], "trim")
for z in (-6.35, 8.35): block(shell, "Central upper timber", [.32, 5.5, .24], [0, 10.2, z], "wood")

# Roof treads plus upright risers make a closed stepped skin, leaving the attic
# hollow. Small overlap at each joint deliberately prevents bright render cracks.
for side in (-1, 1):
    for step in range(10):
        x, y = side*(9.5-step), 13.75+step*.65
        block(roof, "Roof tread", [1.12, .32, 17], [x, y, 1], "roof")
        if step < 9:
            block(roof, "Roof riser", [.2, .76, 17], [side*(9-step), y+.325, 1], "roof")
        for z in (-7.58, 9.58):
            block(roof, "Stepped rake trim", [1.14, .4, .2], [x, y-.03, z], "roofEdge")
block(roof, "Ridge cap", [1, .42, 17.5], [0, 19.8, 1], "roofEdge")
for x in (-9.9, 9.9): block(roof, "Eave fascia", [.35, .6, 17.2], [x, 13.5, 1], "trim")
for z in (-6, 8):
    for step in range(9):
        facade(roof, "Stepped gable infill", "x", z, 18-step*2, 13.4+step*.65, 14.05+step*.65,
               [(-1.15, 1.15, 14.5, 17.7)], thickness=.55)
    block(roof, "Gable apex closure", [1.8, .55, .55], [0, 19.4, z], "wall")
    window("Attic window", "x", z, 0, 16.1, 2.3, False, -1 if z < 0 else 1)

chimney = group("Brick chimney", roof)
# A solid curb spans the three stair-roof levels crossed by the chimney. It
# closes the exposed junction and gives the shaft a readable masonry footing.
block(chimney, "Solid chimney roof curb", [2.6, 1.85, 2.7], [-5.1, 16.6, 5], "brick")
block(chimney, "Stone chimney flashing collar", [2.9, .28, 3], [-5.1, 17.56, 5], "stone")
for course in range(10):
    y = 14.0+course*.7
    block(chimney, "Brick chimney course", [2.0, .68, 2.1], [-5.1, y, 5], "brick" if course % 2 else "brickLight")
    # Alternating proud headers express masonry without tiny individual bricks.
    block(chimney, "Brick header", [.95, .28, .12], [-5.1+(.48 if course % 2 else -.48), y+.1, 3.9], "brickLight")
block(chimney, "Chimney crown", [2.6, .4, 2.7], [-5.1, 20.8, 5], "stone")
block(chimney, "Dark chimney throat", [1.8, .08, 1.9], [-5.1, 21.05, 5], "dark")
for x in (-6.15, -4.05): block(chimney, "Chimney rim side", [.35, .45, 2.5], [x, 21.15, 5], "brick")
for z in (3.95, 6.05): block(chimney, "Chimney rim end", [2.1, .45, .35], [-5.1, 21.15, z], "brick")

block(porch, "Porch footing", [15, .7, 4.8], [0, .35, -8.2], "stone")
for i in range(15): block(porch, "Deck board", [.97, .22, 4.8], [-7+i, .81, -8.2], "wood")
for index in range(3): block(porch, "Front step", [4.4, .25*(3-index), .9], [0, .125*(3-index), -10.8-index*.8], "stoneLight")
for x in (-7, 7):
    block(porch, "Porch post base", [.85, .55, .85], [x, 1.1, -10.15], "trim")
    block(porch, "Porch column", [.48, 5.6, .48], [x, 4, -10.15], "trim")
    block(porch, "Column capital", [.85, .25, .85], [x, 6.7, -10.15], "trim")
block(porch, "Porch front beam", [15.3, .45, .48], [0, 6.9, -10.15], "wood")
for step in range(5):
    block(porch, "Porch roof tread", [15.8, .28, 1.05], [0, 7.15+step*.23, -10.1+step*.95], "roof")
for x1, x2 in ((-7, -2.7), (2.7, 7)):
    for y in (1.2, 2.65): block(porch, "Porch horizontal railing", [x2-x1, .22, .25], [(x1+x2)/2, y, -10.15], "trim")
    for i in range(6): block(porch, "Porch baluster", [.18, 1.45, .18], [x1+(i+.5)*(x2-x1)/6, 1.92, -10.15], "trim")

block(details, "Recessed front door", [3.25, 5.2, .3], [0, 3.9, -6.05], "door")
for x in (-1.78, 1.78): block(details, "Door jamb", [.32, 5.55, .5], [x, 3.95, -6.4], "trim")
block(details, "Door lintel", [3.9, .32, .5], [0, 6.72, -6.4], "trim")
for x in (-.76, .76):
    for y in (2.7, 4.55): block(details, "Raised door panel", [1.2, 1.4, .12], [x, y, -6.26], "door")
block(details, "Door handle", [.16, .55, .17], [1.14, 3.8, -6.5], "gold")
block(details, "Welcome mat", [3, .08, 1.25], [0, .99, -7.2], "door")
# The .38-stud threshold bridges the deck top (.92) to the door bottom (1.3).
block(details, "Stone door threshold", [3.55, .38, .65], [0, 1.11, -6.6], "stoneLight")
for x in (-2.4, 2.4):
    block(details, "Lantern bracket", [.18, .2, .7], [x, 5.8, -6.7], "dark")
    block(details, "Lantern warm pane", [.45, .7, .4], [x, 5.25, -6.9], "flower")
    for y in (4.85, 5.65): block(details, "Lantern cap", [.65, .15, .6], [x, y, -6.9], "dark")


def planter(name, x, z, y=0, width=3.8):
    model = group(name, site)
    block(model, "Planter box", [width, .65, 1], [x, y+.325, z], "brick")
    block(model, "Soil", [width-.25, .1, .75], [x, y+.7, z], "soil")
    for i in range(4):
        xx=x-width*.34+i*width*.225
        block(model, "Block foliage", [.75, .5, .75], [xx, y+.95, z], "leaf")
        block(model, "Square blossom", [.4, .26, .4], [xx, y+1.32, z-.1], "flower" if i % 2 else "flowerRed")


for x in (-5.5, 5.5): planter("Upper window flower box", x, -6.85, 8.0, 3.8)
for x in (-10.6, 10.6):
    planter("Front garden flower bed", x, -8.5, .05, 3.8)
for z in (-4, 1, 6):
    block(site, "Side stepping stone", [1.35, .12, 2.2], [11.7, .06, z], "path")
for z in (-12.5, -13.6): block(site, "Approach paving", [4.3, .13, .9], [0, .065, z], "path")

fence = group("Picket boundary fence", site)
for x in (-13.7, 13.7):
    for z in (-11, -7, -3, 1, 5, 9, 12):
        block(fence, "Fence post", [.45, 2.5, .45], [x, 1.25, z], "trim")
        block(fence, "Post cap", [.62, .2, .62], [x, 2.6, z], "trim")
    for y in (.7, 1.75): block(fence, "Fence rail", [.22, .22, 23], [x, y, .5], "trim")
for x in (-10, -6, 6, 10):
    block(fence, "Front fence post", [.4, 2.3, .4], [x, 1.15, -12.1], "trim")
for center in (-8.5, 8.5):
    for y in (.7, 1.7): block(fence, "Front fence rail", [10.4, .2, .2], [center, y, -12.1], "trim")
    for i in range(11): block(fence, "Picket", [.32, 2.05, .22], [center-5+i, 1.025, -12.1], "trim")

# Block-built garden tree and a bench complete the footprint without mesh assets.
tree = group("Back garden tree", site)
block(tree, "Trunk", [.9, 4.3, .9], [-11.3, 2.15, 9.5], "wood")
for size, pos, col in (([3.8, 2.2, 3.8], [-11.3, 4.3, 9.5], "leaf"),
                       ([3, 1.8, 3], [-11.3, 6, 9.5], "leafLight"),
                       ([1.9, 1, 1.9], [-11.3, 7.35, 9.5], "leaf")):
    block(tree, "Stepped canopy", size, pos, col)
for x in (3, 6): block(site, "Bench leg", [.35, 1.25, 1.3], [x, .625, 11], "wood")
block(site, "Bench seat", [4.4, .25, 1.6], [4.5, 1.35, 11], "wood")
block(site, "Bench back", [4.4, 1.1, .25], [4.5, 2, 11.7], "wood")

block(interior, "Dining tabletop", [3.5, .25, 2.4], [-4, 3.25, 3], "wood")
for x in (-5.3, -2.7):
    for z in (2.2, 3.8): block(interior, "Table leg", [.25, 1.7, .25], [x, 2.3, z], "wood")
block(interior, "Fireplace breast", [3.8, 4.3, 1.1], [0, 3.65, 7.1], "brick")
block(interior, "Fireplace dark recess", [2.4, 2.3, .15], [0, 2.7, 6.48], "dark")
block(interior, "Mantel", [4.3, .3, 1.5], [0, 5.95, 7], "wood")

definition = {"version": 1, "root": house}
(ROOT/"house.json").write_text(json.dumps(definition, indent=2)+"\n", encoding="utf-8")

settings = {
    "views": ["front", "back", "left", "right", "top", "perspective"],
    "resolution": [720, 720], "samples": 48, "margin": 1.1,
    "background": [.82, .86, .87],
    "lighting": {"direction": [-5, 8, -6], "energy": 2.3, "ambient": .65, "angle": 15, "color": [1, .96, .89]},
    "customCameras": [{"name": "front-garden", "direction": [-1, .6, -1.35], "projection": "perspective", "fov": 35}],
}
(ROOT/"house-settings.json").write_text(json.dumps(settings, indent=2)+"\n", encoding="utf-8")
def count(node): return (node["class"] == "Part")+sum(count(child) for child in node.get("children", []))
print(f"Wrote house.json: {count(house)} rectangular studded Plastic Parts")

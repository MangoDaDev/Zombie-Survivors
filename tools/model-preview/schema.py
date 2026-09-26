"""Strict, versioned construction schema. No unknown fields are ever discarded."""
import copy
import json
import math
from transforms import IDENTITY, bounds, corners, euler, compose

SURFACES = ("TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface")
MATERIALS = {"Plastic": (.32, 0), "SmoothPlastic": (.20, 0), "Metal": (.24, 1)}
PART_DEFAULTS = dict(CFrame=IDENTITY, Size=[4, 1, 2], Color=[.6392156863]*3, Material="Plastic",
                     Transparency=0, Reflectance=0, Anchored=True, CanCollide=True, CanTouch=True,
                     CanQuery=True, CastShadow=True, Massless=False, Locked=False, Archivable=True,
                     CollisionGroup="Default", Shape="Block", PivotOffset=IDENTITY, CustomPhysicalProperties=None,
                     **{s: "Smooth" for s in SURFACES})
MODEL_DEFAULTS = dict(PrimaryPart=None, Archivable=True)
CLASS_DEFAULTS = {"Part": PART_DEFAULTS, "Model": MODEL_DEFAULTS}
REPORT_ONLY = ["Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless", "Locked", "Archivable",
               "CollisionGroup", "CustomPhysicalProperties"]
LIMITATIONS = [
    "Offline preview, not Roblox engine pixels: Plastic/Metal BRDF, stud/inlet normal relief, reflectance and lighting are approximations.",
    "Studs use a procedural square normal pattern at one-stud spacing; no silhouette or collision geometry is added.",
    "Physics/ownership are not simulated. Report-only properties: " + ", ".join(REPORT_ONLY) + ".",
    "Opaque intersections use actual box geometry. Coplanar faces are inherently ambiguous; remove overlapping duplicate faces.",
    "Byte reproducibility requires the same Blender build, CPU/platform and tool version; cross-version or cross-machine identity is not promised.",
]


class ValidationError(ValueError):
    pass


def fail(path, message, value):
    raise ValidationError(f"{path}: {message}; got {value!r}")


def obj(value, path, allowed, required=()):
    if not isinstance(value, dict):
        fail(path, "expected object", value)
    for key in value:
        if key not in allowed:
            fail(f"{path}.{key}", "unsupported field/property", value[key])
    for key in required:
        if key not in value:
            fail(f"{path}.{key}", "required field missing", None)


def number(value, path, low=-1e7, high=1e7):
    if type(value) not in (float, int) or not low <= value <= high or not math.isfinite(value):
        fail(path, f"expected finite number in [{low}, {high}]", value)
    return value


def vector(value, path, length=3, low=-1e7, high=1e7):
    if not isinstance(value, list) or len(value) != length:
        fail(path, f"expected array of {length} numbers", value)
    return [number(v, f"{path}[{i}]", low, high) for i, v in enumerate(value)]


def text(value, path):
    if not isinstance(value, str) or not value or len(value) > 256 or any(ord(c) < 32 for c in value):
        fail(path, "expected nonempty string, <=256 characters, no control characters", value)
    return value


def choice(value, path, allowed):
    if not isinstance(value, str) or value not in allowed:
        fail(path, "supported values: " + ", ".join(allowed), value)
    return value


def cframe(value, path):
    if isinstance(value, dict):
        obj(value, path, {"position", "rotationDegrees"})
        value = euler(vector(value.get("position", [0, 0, 0]), path+".position"),
                      vector(value.get("rotationDegrees", [0, 0, 0]), path+".rotationDegrees"))
    value = vector(value, path, 12)
    rows = [value[i:i+3] for i in (3, 6, 9)]
    for i in range(3):
        for j in range(3):
            if abs(sum(a*b for a, b in zip(rows[i], rows[j])) - (i == j)) > 1e-5:
                fail(path, "rotation must be orthonormal (no scale/shear)", value)
    a, b, c = rows
    det = a[0]*(b[1]*c[2]-b[2]*c[1])-a[1]*(b[0]*c[2]-b[2]*c[0])+a[2]*(b[0]*c[1]-b[1]*c[0])
    if abs(det-1) > 1e-5:
        fail(path, "rotation determinant must be +1 (no reflection)", value)
    return value


def properties(cls, raw, path):
    defaults = CLASS_DEFAULTS[cls]
    obj(raw, path, set(defaults) | ({"WorldPivot"} if cls == "Model" else set()))
    result = copy.deepcopy(defaults)
    for key, value in raw.items():
        where = path+"."+key
        if key in ("CFrame", "PivotOffset", "WorldPivot"):
            value = cframe(value, where)
        elif key == "Size":
            value = vector(value, where, low=.001, high=2048)
        elif key == "Color":
            value = vector(value, where, low=0, high=1)
        elif key in ("Transparency", "Reflectance"):
            value = number(value, where, 0, 1)
        elif key in SURFACES:
            value = choice(value, where, ("Smooth", "SmoothNoOutlines", "Studs", "Inlet"))
        elif key == "Material":
            value = choice(value, where, MATERIALS)
        elif key == "Shape":
            value = choice(value, where, ("Block",))
        elif key in ("CollisionGroup", "PrimaryPart"):
            if value is not None or key == "CollisionGroup":
                value = text(value, where)
        elif key == "CustomPhysicalProperties":
            if value is not None:
                fields = ("Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight")
                obj(value, where, fields, fields)
                for k, v in value.items():
                    lo, hi = {"Density": (.01, 100), "Friction": (0, 2), "Elasticity": (0, 1)}.get(k, (0, 100))
                    number(v, where+"."+k, lo, hi)
        elif type(value) is not bool:
            fail(where, "expected boolean", value)
        result[key] = value
    return result


def parse_json(source):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValidationError(f"duplicate JSON key {key!r}; every key must be unique")
            result[key] = value
        return result
    try:
        return json.loads(source.lstrip("\ufeff"), object_pairs_hook=pairs)
    except json.JSONDecodeError as error:
        raise ValidationError(f"JSON line {error.lineno}, column {error.colno}: {error.msg}") from error
    except RecursionError as error:
        raise ValidationError("$: JSON nesting exceeds parser limit") from error


def validate(data):
    obj(data, "$", ("version", "root"), ("version", "root"))
    if type(data["version"]) is not int or data["version"] != 1:
        fail("$.version", "expected schema version 1", data["version"])
    nodes, ids = [], {}

    def visit(raw, path, parent=None, depth=0):
        if depth > 64 or len(nodes) >= 5000:
            fail(path, "tool limit: 64 hierarchy levels / 5000 instances", depth)
        obj(raw, path, ("class", "name", "id", "properties", "children"), ("class", "name"))
        cls = choice(raw["class"], path+".class", CLASS_DEFAULTS)
        node = dict(className=cls, name=text(raw["name"], path+".name"), id=raw.get("id"), path=path,
                    parent=parent, properties=properties(cls, raw.get("properties", {}), path+".properties"), children=[])
        if node["id"] is not None:
            text(node["id"], path+".id")
            if node["id"] in ids:
                fail(path+".id", "duplicate instance id", node["id"])
            ids[node["id"]] = node
        nodes.append(node)
        children = raw.get("children", [])
        if not isinstance(children, list):
            fail(path+".children", "expected array", children)
        for i, child in enumerate(children):
            node["children"].append(visit(child, f"{path}.children[{i}]", node, depth+1))
        return node

    root = visit(data["root"], "$.root")
    parts = [n for n in nodes if n["className"] == "Part"]
    if not parts:
        fail("$.root", "model must contain at least one Part", data["root"])
    for n in nodes:
        if n["className"] == "Model":
            primary = n["properties"]["PrimaryPart"]
            if primary is not None:
                candidate = ids.get(primary)
                ancestor = candidate["parent"] if candidate else None
                while ancestor is not None and ancestor is not n:
                    ancestor = ancestor["parent"]
                if not candidate or candidate["className"] != "Part" or ancestor is not n:
                    fail(n["path"]+".properties.PrimaryPart", "must reference a descendant Part id", primary)
    return dict(root=root, nodes=nodes, parts=parts, ids=ids, source=data)


def part_points(model):
    return [p for n in model["parts"] for p in corners(n["properties"]["CFrame"], n["properties"]["Size"])]


def pivot(node, model):
    props = node["properties"]
    if node["className"] == "Part":
        return compose(props["CFrame"], props["PivotOffset"])
    if props["PrimaryPart"]:
        return pivot(model["ids"][props["PrimaryPart"]], model)
    if "WorldPivot" in props:
        return props["WorldPivot"]
    def points(n):
        result = corners(n["properties"]["CFrame"], n["properties"]["Size"]) if n["className"] == "Part" else []
        return result + [p for c in n["children"] for p in points(c)]
    all_points = points(node)
    if not all_points:
        return list(IDENTITY)
    lo, hi = bounds(all_points)
    return [(a+b)/2 for a, b in zip(lo, hi)] + IDENTITY[3:]

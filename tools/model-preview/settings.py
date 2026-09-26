import copy
from schema import obj, number, vector, choice, fail
from transforms import VIEWS, cross, dot

DEFAULTS = dict(views=list(VIEWS), projection="orthographic", resolution=[640, 640], fov=40,
                margin=1.18, background=[.12, .15, .19], transparent=False, samples=32, seed=0,
                lighting=dict(direction=[-3, 7, -5], energy=3, ambient=.65, angle=12, color=[1, .96, .90]),
                ground=False, groundColor=[.24, .27, .30], customCameras=[])


def validate_settings(raw):
    obj(raw, "$settings", DEFAULTS)
    result = copy.deepcopy(DEFAULTS)
    result.update(raw)
    for key in ("transparent", "ground"):
        if type(result[key]) is not bool:
            fail("$settings."+key, "expected boolean", result[key])
    for key in ("background", "groundColor"):
        vector(result[key], "$settings."+key, low=0, high=1)
    vector(result["resolution"], "$settings.resolution", length=2, low=64, high=4096)
    for v in result["resolution"]:
        if type(v) is not int:
            fail("$settings.resolution", "expected integer dimensions", v)
    for key, lo, hi in (("samples", 1, 4096), ("seed", 0, 2147483647)):
        number(result[key], "$settings."+key, lo, hi)
        if type(result[key]) is not int:
            fail("$settings."+key, "expected integer", result[key])
    number(result["fov"], "$settings.fov", 5, 150)
    number(result["margin"], "$settings.margin", 1.01, 4)
    choice(result["projection"], "$settings.projection", ("orthographic", "perspective"))
    if not isinstance(result["views"], list):
        fail("$settings.views", "expected array of view names", result["views"])
    for i, v in enumerate(result["views"]):
        choice(v, f"$settings.views[{i}]", VIEWS)
    if len(set(result["views"])) != len(result["views"]):
        fail("$settings.views", "duplicate camera names", result["views"])
    light = copy.deepcopy(DEFAULTS["lighting"])
    obj(result["lighting"], "$settings.lighting", light)
    light.update(result["lighting"])
    vector(light["direction"], "$settings.lighting.direction")
    if dot(light["direction"], light["direction"]) < 1e-10:
        fail("$settings.lighting.direction", "must be nonzero", light["direction"])
    vector(light["color"], "$settings.lighting.color", low=0, high=1)
    for key, lo, hi in (("energy", 0, 100), ("ambient", 0, 10), ("angle", 0, 90)):
        number(light[key], "$settings.lighting."+key, lo, hi)
    result["lighting"] = light
    custom = result["customCameras"]
    if not isinstance(custom, list) or len(custom) > 16:
        fail("$settings.customCameras", "expected array, at most 16 cameras", custom)
    names = set(result["views"])
    for i, camera in enumerate(custom):
        path = f"$settings.customCameras[{i}]"
        obj(camera, path, ("name", "direction", "target", "up", "projection", "fov"), ("name", "direction"))
        name = camera["name"]
        if not isinstance(name, str) or not name or len(name) > 48 or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789-_" for c in name):
            fail(path+".name", "use 1-48 lowercase ASCII letters, digits, '-' or '_'", name)
        if name in names or name in ("contact-sheet", "properties", "manifest", "definition", "construction"):
            fail(path+".name", "duplicate or reserved output name", name)
        names.add(name)
        direction = vector(camera["direction"], path+".direction")
        if dot(direction, direction) < 1e-10:
            fail(path+".direction", "must be nonzero", direction)
        if "up" in camera:
            up = vector(camera["up"], path+".up")
            if dot(cross(up, direction), cross(up, direction)) < 1e-10:
                fail(path+".up", "must not be zero or parallel to direction", up)
        if "target" in camera:
            vector(camera["target"], path+".target")
        if "projection" in camera:
            choice(camera["projection"], path+".projection", ("orthographic", "perspective"))
        if "fov" in camera:
            number(camera["fov"], path+".fov", 5, 150)
    if not names:
        fail("$settings.views", "at least one named or custom camera is required", [])
    return result

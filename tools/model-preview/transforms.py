"""Roblox coordinates throughout: X right, Y up, front is -Z; one unit = one stud."""
import itertools
import math

IDENTITY = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def add(a, b):
    return [x + y for x, y in zip(a, b)]


def sub(a, b):
    return [x - y for x, y in zip(a, b)]


def mul(a, s):
    return [x * s for x in a]


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def unit(a):
    return mul(a, 1 / math.sqrt(dot(a, a)))


def rotate(cf, point):
    return [dot(cf[3+i*3:6+i*3], point) for i in range(3)]


def point(cf, value):
    return add(cf[:3], rotate(cf, value))


def compose(a, b):
    cols = [b[3+j::3] for j in range(3)]
    return point(a, b[:3]) + [dot(a[3+i*3:6+i*3], cols[j]) for i in range(3) for j in range(3)]


def euler(position, degrees):
    # CFrame.Angles uses Rx * Ry * Rz, not Roblox Orientation's YXZ order.
    x, y, z = map(math.radians, degrees)
    cx, cy, cz, sx, sy, sz = math.cos(x), math.cos(y), math.cos(z), math.sin(x), math.sin(y), math.sin(z)
    return list(position) + [cy*cz, -cy*sz, sy, cx*sz+sx*sy*cz, cx*cz-sx*sy*sz, -sx*cy,
                             sx*sz-cx*sy*cz, sx*cz+cx*sy*sz, cx*cy]


def corners(cf, size):
    return [point(cf, [s*v/2 for s, v in zip(signs, size)]) for signs in itertools.product((-1, 1), repeat=3)]


def bounds(points):
    return ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])


def bounds_corners(box):
    return [list(p) for p in itertools.product(*zip(*box))]


VIEWS = {"front": [0, 0, -1], "back": [0, 0, 1], "left": [-1, 0, 0],
         "right": [1, 0, 0], "top": [0, 1, 0], "bottom": [0, -1, 0], "perspective": [1, .75, -1]}


def frame_camera(points, direction, projection, width, height, fov=40, margin=1.18, target=None, up=None):
    box = bounds(points)
    target = target or mul(add(*box), .5)
    back = unit(direction)
    up = up or ([0, 0, 1] if abs(back[1]) > .999 else [0, 1, 0])
    right = unit(cross(up, back))
    up = cross(back, right)
    coords = [[dot(sub(p, target), axis) for axis in (right, up, back)] for p in points]
    aspect = width / height
    tan_y = math.tan(math.radians(fov)/2)
    half_height = max(max(abs(p[1]), abs(p[0])/aspect) for p in coords) * margin
    # Solve each corner's perspective inequality, including its depth. A radius-only
    # heuristic clips long rotated models and narrow portrait renders.
    distance = max(p[2] + margin*max(abs(p[1])/tan_y, abs(p[0])/(tan_y*aspect)) for p in coords)
    distance = max(distance, max(p[2] for p in coords) + .1)
    if projection == "orthographic":
        distance = max(distance, max(p[2] for p in coords) + half_height*2 + 1)
    return dict(target=target, position=add(target, mul(back, distance)), right=right, up=up, back=back,
                distance=distance, halfHeight=max(half_height, .001), tanY=tan_y,
                projection=projection, width=width, height=height)


def project(camera, p):
    relative = sub(p, camera["target"])
    x, y, z = [dot(relative, camera[a]) for a in ("right", "up", "back")]
    scale = camera["halfHeight"]
    if camera["projection"] == "perspective":
        scale = max(1e-9, camera["distance"]-z) * camera["tanY"]
    pixels = camera["height"] / (2*scale)
    return [camera["width"]/2+x*pixels, camera["height"]/2-y*pixels]

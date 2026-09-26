"""Headless Cycles backend. All geometry is authored from the validated definition."""
import math
import bpy
from mathutils import Matrix, Vector
from schema import MATERIALS, part_points
from transforms import bounds, VIEWS, frame_camera


def linear(c):
    return c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4


def color(rgb):
    return (*[linear(v) for v in rgb], 1)


def matrix(cf):
    return Matrix([cf[3:6]+[cf[0]], cf[6:9]+[cf[1]], cf[9:12]+[cf[2]], [0, 0, 0, 1]])


def material(props, surface, cache):
    key = (tuple(props["Color"]), props["Material"], props["Transparency"], props["Reflectance"], surface)
    if key in cache:
        return cache[key]
    mat = bpy.data.materials.new(f"surface-{len(cache)}")
    cache[key] = mat
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color(props["Color"])
    rough, metal = MATERIALS[props["Material"]]
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Coat Weight"].default_value = props["Reflectance"]
    shader.inputs["Coat Roughness"].default_value = .035
    shader.inputs["Alpha"].default_value = 1-props["Transparency"]
    if surface in ("Studs", "Inlet"):
        def math_node(op, a, b=None):
            n = nodes.new("ShaderNodeMath")
            n.operation = op
            for i, value in enumerate((a, b)):
                if value is None:
                    continue
                if isinstance(value, (int, float)):
                    n.inputs[i].default_value = value
                else:
                    links.new(value, n.inputs[i])
            return n.outputs[0]
        uv = nodes.new("ShaderNodeTexCoord")
        split = nodes.new("ShaderNodeSeparateXYZ")
        links.new(uv.outputs["UV"], split.inputs[0])
        coords = [math_node("ABSOLUTE", math_node("SUBTRACT", math_node("FRACT", split.outputs[i]), .5)) for i in (0, 1)]
        maximum = math_node("MAXIMUM", *coords)
        ramp = nodes.new("ShaderNodeMapRange")
        ramp.interpolation_type = "SMOOTHERSTEP"
        links.new(maximum, ramp.inputs["Value"])
        ramp.inputs["From Min"].default_value = .24
        ramp.inputs["From Max"].default_value = .32
        ramp.inputs["To Min"].default_value = 1
        ramp.inputs["To Max"].default_value = 0
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = .75
        bump.inputs["Distance"].default_value = .06
        bump.invert = surface == "Inlet"
        links.new(ramp.outputs["Result"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
        links.new(bump.outputs["Normal"], shader.inputs["Coat Normal"])
    return mat


# Face normals and UV tangent axes use Roblox's face names, not Blender's Z-up labels.
FACES = [("RightSurface", (1, 0, 0), (0, 0, -1), (0, 1, 0)),
         ("LeftSurface", (-1, 0, 0), (0, 0, 1), (0, 1, 0)),
         ("TopSurface", (0, 1, 0), (1, 0, 0), (0, 0, -1)),
         ("BottomSurface", (0, -1, 0), (1, 0, 0), (0, 0, 1)),
         ("FrontSurface", (0, 0, -1), (-1, 0, 0), (0, 1, 0)),
         ("BackSurface", (0, 0, 1), (1, 0, 0), (0, 1, 0))]


def make_part(node, cache):
    props = node["properties"]
    size = props["Size"]
    verts, faces, uvs = [], [], []
    for _, normal, u, v in FACES:
        width = sum(abs(a)*b for a, b in zip(u, size))
        height = sum(abs(a)*b for a, b in zip(v, size))
        indices = []
        for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            indices.append(len(verts))
            verts.append([normal[i]*size[i]/2 + u[i]*x*width/2 + v[i]*y*height/2 for i in range(3)])
            # UV distance is measured in studs. Center anchoring prevents stretching
            # on thin/rotated parts; partial tiles are deliberately clipped at edges.
            uvs.append((x*width/2, y*height/2))
        faces.append(indices)
    mesh = bpy.data.meshes.new(node["name"])
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="StudSpace")
    for loop in mesh.loops:
        uv.data[loop.index].uv = uvs[loop.vertex_index]
    ob = bpy.data.objects.new(node["name"], mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.matrix_world = matrix(props["CFrame"])
    ob.visible_shadow = props["CastShadow"]
    for i, (surface, *_rest) in enumerate(FACES):
        mesh.materials.append(material(props, props[surface], cache))
        mesh.polygons[i].material_index = i
    return ob


def make_scene(model, settings):
    # Never use UI/screen capture, save .blend output, or mutate Studio assets.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = settings["samples"]
    scene.cycles.seed = settings["seed"]
    scene.cycles.use_animated_seed = False
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 12
    scene.cycles.transparent_max_bounces = 64
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 1
    scene.render.resolution_x, scene.render.resolution_y = settings["resolution"]
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 50
    scene.render.film_transparent = settings["transparent"]
    scene.render.use_stamp = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.render.dither_intensity = 0
    cache, objects = {}, {}
    for node in model["nodes"]:
        ob = make_part(node, cache) if node["className"] == "Part" else bpy.data.objects.new(node["name"], None)
        if node["className"] == "Model":
            scene.collection.objects.link(ob)
        if node["parent"]:
            # Parenting in Blender normally changes coordinates; preserve world matrices
            # to match Roblox, where Models are containers rather than transform nodes.
            world = ob.matrix_world.copy()
            ob.parent = objects[node["parent"]["path"]]
            ob.matrix_world = world
        objects[node["path"]] = ob
    world = bpy.data.worlds.new("Preview lighting")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    ambient = nodes.get("Background")
    ambient.inputs["Color"].default_value = (1, 1, 1, 1)
    ambient.inputs["Strength"].default_value = settings["lighting"]["ambient"]
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Color"].default_value = color(settings["background"])
    rays = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(rays.outputs["Is Camera Ray"], mix.inputs[0])
    links.new(ambient.outputs[0], mix.inputs[1])
    links.new(background.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], nodes.get("World Output").inputs[0])
    lamp = bpy.data.lights.new("Key", "SUN")
    lamp.energy = settings["lighting"]["energy"]
    lamp.color = color(settings["lighting"]["color"])[:3]
    lamp.angle = math.radians(settings["lighting"]["angle"])
    light = bpy.data.objects.new("Key", lamp)
    scene.collection.objects.link(light)
    light.rotation_euler = (-Vector(settings["lighting"]["direction"])).to_track_quat('-Z', 'Y').to_euler()
    if settings["ground"]:
        lo, hi = bounds(part_points(model))
        span = max(b-a for a, b in zip(lo, hi))*10
        bpy.ops.mesh.primitive_plane_add(size=span, location=((lo[0]+hi[0])/2, lo[1]-.002, (lo[2]+hi[2])/2), rotation=(math.pi/2, 0, 0))
        ground = bpy.context.object
        ground.name = "Preview ground (not exported)"
        ground.data.materials.append(material(dict(Color=settings["groundColor"], Material="Plastic", Transparency=0, Reflectance=0), "Smooth", cache))
    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam = bpy.data.objects.new("PreviewCamera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene


def cameras(model, settings):
    points = part_points(model)
    result = {}
    definitions = [dict(name=name, direction=VIEWS[name], projection="perspective" if name == "perspective" else settings["projection"]) for name in settings["views"]]
    definitions += settings["customCameras"]
    for spec in definitions:
        result[spec["name"]] = frame_camera(points, spec["direction"], spec.get("projection", settings["projection"]),
            *settings["resolution"], spec.get("fov", settings["fov"]), settings["margin"], spec.get("target"), spec.get("up"))
    return result


def configure_camera(scene, camera):
    cam = scene.camera
    right, up, back = camera["right"], camera["up"], camera["back"]
    cf = camera["position"] + [axis[i] for i in range(3) for axis in (right, up, back)]
    cam.matrix_world = matrix(cf)
    cam.data.type = "ORTHO" if camera["projection"] == "orthographic" else "PERSP"
    # Blender AUTO sensor fit changes in portrait mode. Force vertical fit so
    # the same vertical field of view is used by both framing and annotations.
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 32
    cam.data.lens = 16/camera["tanY"]
    cam.data.ortho_scale = camera["halfHeight"]*2
    cam.data.clip_start = .001
    cam.data.clip_end = max(100, camera["distance"]*10)


def render_view(scene, camera, path):
    configure_camera(scene, camera)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    from png import strip_metadata
    strip_metadata(path)

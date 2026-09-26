import os
from pathlib import Path
import tempfile
import unittest

try:
    import bpy
except ImportError:
    bpy = None

from schema import validate
from settings import validate_settings
from transforms import corners, euler, project
from test_core import fixture


@unittest.skipIf(bpy is None, "requires Blender")
class BackendTests(unittest.TestCase):
    def test_face_normals_uv_scale_and_world_transform(self):
        from backend import make_scene, FACES
        model = validate(fixture())
        scene = make_scene(model, validate_settings({}))
        ob = next(o for o in scene.objects if o.type == "MESH")
        for face, (_, expected, *_) in zip(ob.data.polygons, FACES):
            for a, b in zip(face.normal, expected):
                self.assertAlmostEqual(a, b)
        for a, b in zip(ob.matrix_world.translation, [3, 2, -1]):
            self.assertAlmostEqual(a, b)
        self.assertEqual(ob.parent.name, "Nested")
        # Top face's full UV extent equals its 2-by-6 stud dimensions.
        uv = [ob.data.uv_layers.active.data[i].uv[:] for i in ob.data.polygons[2].loop_indices]
        self.assertEqual(max(p[0] for p in uv)-min(p[0] for p in uv), 2)
        self.assertEqual(max(p[1] for p in uv)-min(p[1] for p in uv), 6)

    def test_camera_projection_matches_blender(self):
        from backend import make_scene, cameras, matrix
        from bpy_extras.object_utils import world_to_camera_view
        from mathutils import Vector
        for resolution in ([640, 240], [240, 640]):
            for mode in ("orthographic", "perspective"):
                settings = validate_settings(dict(resolution=resolution, projection=mode, views=["front"]))
                model = validate(fixture())
                scene = make_scene(model, settings)
                camera = cameras(model, settings)["front"]
                # Exercise production camera setup without spending time rendering.
                from backend import configure_camera
                configure_camera(scene, camera)
                bpy.context.view_layer.update()
                for p in corners(euler([3, 2, -1], [0, 90, 0]), [2, 4, 6]):
                    projected = world_to_camera_view(scene, scene.camera, Vector(p))
                    expected = project(camera, p)
                    self.assertAlmostEqual(projected.x*resolution[0], expected[0], places=3)
                    self.assertAlmostEqual((1-projected.y)*resolution[1], expected[1], places=3)


@unittest.skipUnless(bpy is not None and os.environ.get("MODEL_PREVIEW_RENDER_TESTS"), "pass --render-tests for CPU render determinism test")
class RenderTests(unittest.TestCase):
    def test_identical_output_and_transparent_pixels(self):
        from cli import render
        model = validate({"version": 1, "root": {"class": "Part", "name": "Stud test", "properties": {"TopSurface": "Studs", "FrontSurface": "Studs"}}})
        settings = validate_settings(dict(views=["perspective"], resolution=[64, 64], samples=4, transparent=True))
        with tempfile.TemporaryDirectory() as temporary:
            a, b = Path(temporary)/"a", Path(temporary)/"b"
            render(model, settings, a)
            render(model, settings, b)
            from reports import sha
            self.assertEqual({p.name:sha(p) for p in a.iterdir()}, {p.name:sha(p) for p in b.iterdir()})
            image = bpy.data.images.load(str(a/"perspective.png"), check_existing=False)
            try:
                self.assertEqual(image.pixels[3], 0)
                self.assertGreater(max(image.pixels[:][3::4]), .99)
            finally:
                bpy.data.images.remove(image)

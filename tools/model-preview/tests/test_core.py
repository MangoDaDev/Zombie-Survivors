import copy
import json
import math
import unittest
import tempfile
from pathlib import Path

from schema import validate, parse_json, ValidationError, part_points, pivot
from transforms import IDENTITY, euler, point, compose, corners, frame_camera, project, VIEWS
from settings import validate_settings
from luau import export_luau, parse_source, canonical_definition


def fixture():
    return {"version": 1, "root": {"class": "Model", "name": "Assembly", "properties": {"WorldPivot": {"position": [50, 0, 0]}}, "children": [
        {"class": "Model", "name": "Nested", "children": [
            {"class": "Part", "name": "Block", "id": "block", "properties": {"Size": [2, 4, 6], "CFrame": {"position": [3, 2, -1], "rotationDegrees": [0, 90, 0]}}}]}]}}


class ParsingTests(unittest.TestCase):
    def test_bom_and_json_errors(self):
        self.assertEqual(parse_json('\ufeff{"version":1}'), {"version": 1})
        with self.assertRaisesRegex(ValidationError, "line 2, column"):
            parse_json('{\n"bad": }')
        with self.assertRaisesRegex(ValidationError, "duplicate JSON key"):
            parse_json('{"version":1,"version":2}')

    def test_export_roundtrip(self):
        model = validate(fixture())
        source = export_luau(model)
        result = validate(parse_source(source))
        self.assertEqual(canonical_definition(model), canonical_definition(result))
        self.assertEqual(export_luau(result), source)
        with self.assertRaisesRegex(ValidationError, "adapter changed"):
            parse_source(source.replace('instance.Size =', 'instance.Color ='))
        with self.assertRaisesRegex(ValidationError, "arbitrary Luau"):
            parse_source('return Instance.new("Part")')

    def test_long_bracket_names(self):
        data = fixture()
        data["root"]["name"] = 'Test ]=] ]==] " quote'
        model = validate(data)
        self.assertEqual(validate(parse_source(export_luau(model)))["root"]["name"], data["root"]["name"])

    def test_hierarchy_and_world_frames(self):
        model = validate(fixture())
        part = model["parts"][0]
        self.assertEqual(part["parent"]["name"], "Nested")
        self.assertEqual(part["properties"]["CFrame"][:3], [3, 2, -1])
        self.assertEqual(pivot(model["root"], model)[:3], [50, 0, 0])
        for actual, expected in zip(pivot(part["parent"], model)[:3], [3, 2, -1]):
            self.assertAlmostEqual(actual, expected)
        self.assertEqual(len(part_points(model)), 8)

    def test_primary_part_pivot_offset(self):
        data = fixture()
        data["root"]["properties"]["PrimaryPart"] = "block"
        data["root"]["children"][0]["children"][0]["properties"]["PivotOffset"] = {"position": [1, 0, 0]}
        model = validate(data)
        actual = pivot(model["root"], model)[:3]
        for a, b in zip(actual, [3, 2, -2]):
            self.assertAlmostEqual(a, b)

    def test_invalid_fields_and_values(self):
        cases = [("Bogus", 7), ("Size", [0, 1, 1]), ("Size", [1, 2]), ("Color", [256, 0, 0]),
                 ("Transparency", float("nan")), ("Reflectance", True), ("Anchored", 1),
                 ("TopSurface", "Motor"), ("Material", "Wood"), ("Shape", "Ball"),
                 ("CFrame", [0]*12), ("CFrame", [0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, 1])]
        for key, value in cases:
            with self.subTest(key=key, value=value):
                data = {"version": 1, "root": {"class": "Part", "name": "P", "properties": {key: value}}}
                with self.assertRaises(ValidationError) as caught:
                    validate(data)
                self.assertIn("$.root.properties."+key, str(caught.exception))

    def test_bad_hierarchy(self):
        for change in (lambda d: d["root"].update({"class": "MeshPart"}),
                       lambda d: d["root"].update({"children": {}}),
                       lambda d: d["root"]["properties"].update({"PrimaryPart": "missing"}),
                       lambda d: d["root"].update({"id": "block"}),
                       lambda d: d.update({"version": True})):
            data = fixture()
            change(data)
            with self.assertRaises(ValidationError):
                validate(data)

    def test_settings_rejections(self):
        for raw in ({"resolution": [20, 640]}, {"resolution": [640.5, 640]}, {"views": ["front", "front"]},
                    {"views": []}, {"lighting": {"direction": [0, 0, 0]}}, {"typo": True},
                    {"customCameras": [{"name": "../escape", "direction": [1, 1, 1]}]},
                    {"customCameras": [{"name": "detail", "direction": [0, 1, 0], "up": [0, 1, 0]}]}):
            with self.subTest(raw=raw), self.assertRaises(ValidationError):
                validate_settings(raw)

    def test_invalid_render_preserves_previous_output(self):
        from cli import main
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)/"render"
            output.mkdir()
            previous = output/"front.png"
            previous.write_bytes(b"previous successful render")
            invalid = Path(directory)/"input.json"
            invalid.write_text('{"version":1,"root":{"class":"MeshPart","name":"Unsupported"}}')
            with self.assertRaisesRegex(ValidationError, r"\$\.root.class"):
                main(["render", str(invalid), "--out", str(output)])
            self.assertEqual(previous.read_bytes(), b"previous successful render")


class TransformTests(unittest.TestCase):
    def assertVector(self, actual, expected):
        for a, b in zip(actual, expected):
            self.assertAlmostEqual(a, b, places=7)

    def test_known_rotation_and_composition(self):
        cf = euler([10, 2, 3], [0, 90, 0])
        self.assertVector(point(cf, [1, 0, 0]), [10, 2, 2])
        offset = euler([2, 0, 0], [90, 0, 0])
        self.assertVector(point(compose(cf, offset), [0, 1, 0]), point(cf, point(offset, [0, 1, 0])))
        self.assertVector(compose(IDENTITY, cf), cf)

    def test_xyz_order(self):
        # Independent elementary rotations: Rz acts first, then Ry, then Rx.
        angles = [23, 47, -19]
        cf = euler([0, 0, 0], angles)
        x, y, z = [2, -3, 5]
        rz, ry, rx = map(math.radians, reversed(angles))
        x, y = x*math.cos(rz)-y*math.sin(rz), x*math.sin(rz)+y*math.cos(rz)
        x, z = x*math.cos(ry)+z*math.sin(ry), -x*math.sin(ry)+z*math.cos(ry)
        y, z = y*math.cos(rx)-z*math.sin(rx), y*math.sin(rx)+z*math.cos(rx)
        self.assertVector(point(cf, [2, -3, 5]), [x, y, z])

    def test_all_angles_and_aspect_ratios_frame_rotated_extents(self):
        pts = corners(euler([45, -21, 72], [37, 16, 51]), [30, 2, 7])
        for direction in list(VIEWS.values())+[[.01, 1, .03]]:
            for width, height in ((640, 640), (1600, 300), (300, 1600)):
                for mode in ("orthographic", "perspective"):
                    cam = frame_camera(pts, direction, mode, width, height)
                    for p in pts:
                        x, y = project(cam, p)
                        self.assertTrue(0 < x < width and 0 < y < height, (direction, mode, x, y))

    def test_custom_target_and_top_orientation(self):
        pts = corners(IDENTITY, [3, 4, 2])
        cam = frame_camera(pts, [0, 1, 0], "orthographic", 640, 480, target=[1, 2, 3])
        self.assertVector(cam["up"], [0, 0, 1])
        self.assertVector(project(cam, [1, 2, 3]), [320, 240])


if __name__ == "__main__":
    unittest.main()

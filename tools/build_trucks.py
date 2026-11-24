"""
Headless Blender builder for Truck App.

Models four fictional trucks and the swappable parts, exports glTF binary
files, and writes a studio preview plus anchor manifest.

Run:
  blender --background --python tools/build_trucks.py
  blender --background --python tools/build_trucks.py -- ridgehaul-summit
"""

from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
MODEL_ROOT = ROOT / "src" / "assets" / "models"
PREVIEW_DIR = ROOT / "tools" / "previews"
ANCHOR_PATH = ROOT / "src" / "content" / "anchors.json"

STOCK_TIRE_R = 0.38
ARCH_R = 0.55

TRUCKS = [
    {
        "id": "ridgehaul-summit",
        "wheelbase": 3.4,
        "track": 1.56,
        "front_over": 0.78,
        "rear_over": 0.78,
        "width": 1.86,
        "flare": 0.07,
        "belt": 0.96,
        "roof": 1.58,
        "cab_front": 1.18,
        "cab_rear": -0.42,
        "hood_nose": 2.32,
        "radius": 0.09,
        "crown": 0.04,
        "tumble": 0.08,
        "rake": 0.55,
        "grille": "bars",
        "lamps": "round",
        "fastback": 0.0,
        "cage": False,
        "scoop": False,
        "intake": False,
        "rack": False,
        "skirt": False,
        "plate": "SMIT 150",
        "paint": (0.55, 0.24, 0.1),
        "clearance": 0.26,
    },
    {
        "id": "veldt-meridian",
        "wheelbase": 3.55,
        "track": 1.7,
        "front_over": 0.86,
        "rear_over": 1.15,
        "width": 1.98,
        "flare": 0.13,
        "belt": 1.04,
        "roof": 1.7,
        "cab_front": 1.05,
        "cab_rear": 0.05,
        "hood_nose": 2.48,
        "radius": 0.1,
        "crown": 0.03,
        "tumble": 0.05,
        "rake": 0.48,
        "grille": "slots",
        "lamps": "rect",
        "fastback": 0.0,
        "cage": True,
        "scoop": True,
        "intake": True,
        "rack": False,
        "skirt": False,
        "plate": "VLDT 4",
        "paint": (0.62, 0.48, 0.26),
        "clearance": 0.32,
    },
    {
        "id": "northline-harbor",
        "wheelbase": 3.2,
        "track": 1.52,
        "front_over": 0.7,
        "rear_over": 0.9,
        "width": 1.82,
        "flare": 0.035,
        "belt": 1.0,
        "roof": 1.82,
        "cab_front": 0.92,
        "cab_rear": -0.28,
        "hood_nose": 1.95,
        "radius": 0.045,
        "crown": 0.012,
        "tumble": 0.03,
        "rake": 0.28,
        "grille": "grid",
        "lamps": "rect",
        "fastback": 0.0,
        "cage": False,
        "scoop": False,
        "intake": False,
        "rack": True,
        "skirt": False,
        "plate": "HBR 220",
        "paint": (0.62, 0.68, 0.74),
        "clearance": 0.28,
    },
    {
        "id": "kestrel-talon",
        "wheelbase": 3.15,
        "track": 1.66,
        "front_over": 0.95,
        "rear_over": 0.58,
        "width": 1.94,
        "flare": 0.1,
        "belt": 0.9,
        "roof": 1.36,
        "cab_front": 0.95,
        "cab_rear": -0.15,
        "hood_nose": 2.45,
        "radius": 0.11,
        "crown": 0.05,
        "tumble": 0.14,
        "rake": 0.78,
        "grille": "slit",
        "lamps": "blade",
        "fastback": 0.28,
        "cage": False,
        "scoop": False,
        "intake": False,
        "rack": False,
        "skirt": True,
        "plate": "TLN X",
        "paint": (0.22, 0.14, 0.32),
        "clearance": 0.22,
    },
]


def argv_filter() -> str | None:
    if "--" not in sys.argv:
        return None
    args = sys.argv[sys.argv.index("--") + 1 :]
    return args[0] if args else None


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def link(obj: bpy.types.Object) -> bpy.types.Object:
    bpy.context.collection.objects.link(obj)
    return obj


def assign(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    if obj.data is None:
        return
    if mat.name not in obj.data.materials:
        obj.data.materials.append(mat)
    if hasattr(obj.data, "polygons"):
        for poly in obj.data.polygons:
            poly.material_index = 0


def smooth(obj: bpy.types.Object, angle: float = 48) -> None:
    mesh = obj.data
    if not hasattr(mesh, "polygons"):
        return
    for poly in mesh.polygons:
        poly.use_smooth = True
    if hasattr(mesh, "use_auto_smooth"):
        mesh.use_auto_smooth = True
        mesh.auto_smooth_angle = math.radians(angle)


def apply_modifiers(obj: bpy.types.Object) -> None:
    activate(obj)
    for mod in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError as exc:
            print(f"modifier failed {obj.name} {mod.name}: {exc}")


def bevel(obj: bpy.types.Object, width: float = 0.01, segments: int = 2, angle: float = 38) -> None:
    smooth(obj)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    apply_modifiers(obj)
    smooth(obj)


def shade_all(obj: bpy.types.Object) -> None:
    smooth(obj, 55)


def make_mat(
    name: str,
    color: tuple[float, float, float],
    metallic: float = 0.0,
    rough: float = 0.45,
    coat: float = 0.0,
    emit: float = 0.0,
    alpha: float = 1.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.06
    bsdf.inputs["Emission Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = emit
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1:
        mat.blend_method = "BLEND"
        mat.show_transparent_back = False
    return mat


def palette(spec: dict) -> dict[str, bpy.types.Material]:
    paint = spec["paint"]
    return {
        "paint": make_mat("Paint", paint, 0.15, 0.22, coat=1.0),
        "trim": make_mat("PaintTrim", tuple(max(0, c * 0.55) for c in paint), 0.2, 0.4, coat=0.4),
        "glass": make_mat("Glass", (0.1, 0.14, 0.18), 0.08, 0.04, coat=1.0, alpha=0.72),
        "chrome": make_mat("Chrome", (0.78, 0.82, 0.86), 1.0, 0.12, coat=0.3),
        "plastic": make_mat("Plastic", (0.09, 0.09, 0.1), 0.15, 0.55),
        "rubber": make_mat("Rubber", (0.015, 0.015, 0.016), 0.0, 0.86),
        "light": make_mat("Light", (1.0, 0.9, 0.7), 0.0, 0.2, emit=4.0),
        "tail": make_mat("Tail", (0.8, 0.02, 0.015), 0.0, 0.3, emit=2.2),
        "interior": make_mat("Interior", (0.16, 0.09, 0.06), 0.05, 0.72),
        "plate": make_mat("Plate", (0.86, 0.8, 0.62), 0.0, 0.45),
    }


def rounded_loop(hw: float, y0: float, y1: float, radius: float, crown: float, tumble: float) -> list[tuple[float, float]]:
    corner = 4
    side = 4
    rad = min(radius, hw * 0.46, max(0.01, (y1 - y0) * 0.46))
    pts: list[tuple[float, float]] = []

    def arc(cx: float, cy: float, a0: float, a1: float) -> None:
        for i in range(corner):
            a = a0 + (a1 - a0) * (i / corner)
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))

    def line(x0: float, yy0: float, x1: float, yy1: float, n: int) -> None:
        for i in range(n):
            t = i / n
            pts.append((x0 + (x1 - x0) * t, yy0 + (yy1 - yy0) * t))

    arc(hw - rad, y0 + rad, -math.pi / 2, 0)
    line(hw, y0 + rad, hw, y1 - rad, side)
    arc(hw - rad, y1 - rad, 0, math.pi / 2)
    line(hw - rad, y1, -hw + rad, y1, side * 2)
    arc(-hw + rad, y1 - rad, math.pi / 2, math.pi)
    line(-hw, y1 - rad, -hw, y0 + rad, side)
    arc(-hw + rad, y0 + rad, math.pi, math.pi * 1.5)
    line(-hw + rad, y0, hw - rad, y0, side * 2)

    ymin = min(p[1] for p in pts)
    ymax = max(p[1] for p in pts)
    span = max(1e-5, ymax - ymin)
    shaped: list[tuple[float, float]] = []
    for x, y in pts:
        t = (y - ymin) / span
        lift = crown * (t**2) * max(0.0, 1 - (abs(x) / max(hw, 1e-4)) ** 2)
        shaped.append((x * (1 - tumble * t), y + lift))
    return shaped


def mesh_from_bmesh(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    link(obj)
    mesh.validate(verbose=False)
    return obj


def loft(name: str, stations: list[dict], mat: bpy.types.Material, bevel_w: float = 0.009) -> bpy.types.Object:
    loops = []
    for station in stations:
        loop = rounded_loop(
            station["hw"],
            station["y0"],
            station["y1"],
            station.get("r", 0.08),
            station.get("crown", 0.0),
            station.get("tumble", 0.0),
        )
        loops.append([(x, y, station["z"]) for x, y in loop])
    count = len(loops[0])
    bm = bmesh.new()
    rings = [[bm.verts.new(co) for co in loop] for loop in loops]
    bm.verts.ensure_lookup_table()
    for i in range(len(rings) - 1):
        a = rings[i]
        b = rings[i + 1]
        for k in range(count):
            try:
                bm.faces.new((a[k], a[(k + 1) % count], b[(k + 1) % count], b[k]))
            except ValueError:
                pass

    def cap(ring: list, outward: float) -> None:
        center = Vector((0, 0, 0))
        for vert in ring:
            center += vert.co
        center /= len(ring)
        hub = bm.verts.new(center)
        for k in range(count):
            v1 = ring[k]
            v2 = ring[(k + 1) % count]
            try:
                if outward > 0:
                    bm.faces.new((hub, v1, v2))
                else:
                    bm.faces.new((hub, v2, v1))
            except ValueError:
                pass

    # stations are ordered rear (-z) to front (+z)
    cap(rings[0], -1)
    cap(rings[-1], 1)
    obj = mesh_from_bmesh(name, bm, mat)
    bevel(obj, bevel_w, 2, 42)
    return obj


def tube(name: str, points: list[tuple[float, float, float]], radius: float, mat: bpy.types.Material, res: int = 5) -> bpy.types.Object:
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = res
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for index, point in enumerate(points):
        spline.points[index].co = (point[0], point[1], point[2], 1)
    obj = bpy.data.objects.new(name, curve)
    link(obj)
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    assign(obj, mat)
    shade_all(obj)
    return obj


def primitive(name: str, kind: str, mat: bpy.types.Material, **kwargs) -> bpy.types.Object:
    ops = {
        "cube": bpy.ops.mesh.primitive_cube_add,
        "cylinder": bpy.ops.mesh.primitive_cylinder_add,
        "uv": bpy.ops.mesh.primitive_uv_sphere_add,
        "torus": bpy.ops.mesh.primitive_torus_add,
    }
    ops[kind](**kwargs)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    assign(obj, mat)
    return obj


def join(name: str, objects: list[bpy.types.Object], mat: bpy.types.Material | None = None) -> bpy.types.Object:
    objects = [obj for obj in objects if obj is not None]
    activate(objects[0])
    for obj in objects:
        obj.select_set(True)
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    if mat is not None:
        obj.data.materials.clear()
        assign(obj, mat)
    return obj


def boolean_cut(obj: bpy.types.Object, location: tuple[float, float, float], radius: float) -> None:
    cutter = primitive(
        "Cutter",
        "cylinder",
        make_mat("CutterMat", (1, 0, 0)),
        vertices=48,
        radius=radius,
        depth=4.8,
        location=location,
        rotation=(0, math.radians(90), 0),
    )
    mod = obj.modifiers.new("Arch", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    apply_modifiers(obj)
    bpy.data.objects.remove(cutter, do_unlink=True)


def subdivide(obj: bpy.types.Object, levels: int = 1) -> None:
    mod = obj.modifiers.new("Sub", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    apply_modifiers(obj)
    smooth(obj, 60)


def empty(name: str, location: tuple[float, float, float]) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.06
    obj.location = location
    return link(obj)


def axles(spec: dict) -> tuple[float, float, float, float]:
    front = spec["wheelbase"] / 2
    return front, -front, front + spec["front_over"], -spec["wheelbase"] / 2 - spec["rear_over"]


def build_body(spec: dict, mats: dict) -> bpy.types.Object:
    front, rear, front_z, rear_z = axles(spec)
    hw = spec["width"] / 2
    flare = spec["flare"]
    belt = spec["belt"]
    y0 = spec["clearance"]
    radius = spec["radius"]
    stations = [
        dict(z=rear_z + 0.16, hw=hw * 0.9, y0=y0 + 0.04, y1=belt - 0.08, r=radius, crown=0.01, tumble=0.02),
        dict(z=rear - 0.42, hw=hw * 0.98, y0=y0, y1=belt, r=radius, crown=0.02, tumble=spec["tumble"] * 0.4),
        dict(z=rear, hw=hw + flare, y0=y0 - 0.02, y1=belt + 0.03, r=radius + 0.02, crown=0.025, tumble=spec["tumble"] * 0.3),
        dict(z=(rear + 0) / 2, hw=hw * 0.95, y0=y0 + 0.03, y1=belt - 0.01, r=radius, crown=0.015, tumble=spec["tumble"]),
        dict(z=0.05, hw=hw * 0.93, y0=y0 + 0.04, y1=belt - 0.02, r=radius * 0.9, crown=0.012, tumble=spec["tumble"]),
        dict(z=front - 0.48, hw=hw * 0.98, y0=y0, y1=belt, r=radius, crown=0.02, tumble=spec["tumble"] * 0.5),
        dict(z=front, hw=hw + flare, y0=y0 - 0.02, y1=belt + 0.04, r=radius + 0.03, crown=0.03, tumble=spec["tumble"] * 0.35),
        dict(z=front + 0.38, hw=hw * 0.96, y0=y0 + 0.02, y1=belt - 0.04, r=radius, crown=0.02, tumble=spec["tumble"] * 0.2),
        dict(z=min(spec["hood_nose"] - 0.05, front_z - 0.08), hw=hw * 0.88, y0=y0 + 0.06, y1=belt - 0.16, r=radius, crown=0.02, tumble=0.02),
    ]
    body = loft("PaintBody", stations, mats["paint"], 0.01)
    for z in (front, rear):
        boolean_cut(body, (0, STOCK_TIRE_R, z), ARCH_R)
    bevel(body, 0.008, 2, 30)
    return body


def build_hood(spec: dict, mats: dict) -> bpy.types.Object:
    front, _, front_z, _ = axles(spec)
    hw = spec["width"] / 2 * 0.9
    belt = spec["belt"]
    nose = spec["hood_nose"]
    cowl = spec["cab_front"] + 0.08
    stations = [
        dict(z=cowl, hw=hw, y0=belt - 0.22, y1=belt + 0.02, r=0.05, crown=spec["crown"], tumble=0.04),
        dict(z=(cowl + nose) / 2, hw=hw * 0.98, y0=belt - 0.28, y1=belt - 0.04, r=0.06, crown=spec["crown"] * 1.3, tumble=0.05),
        dict(z=nose, hw=hw * 0.86, y0=belt - 0.36, y1=spec["clearance"] + 0.48, r=0.07, crown=spec["crown"] * 0.4, tumble=0.02),
    ]
    hood = loft("PaintHood", stations, mats["paint"], 0.01)
    if spec["scoop"]:
        scoop = loft(
            "PaintScoop",
            [
                dict(z=cowl + 0.15, hw=0.16, y0=belt + 0.0, y1=belt + 0.1, r=0.04, crown=0.03),
                dict(z=cowl + 0.55, hw=0.2, y0=belt - 0.02, y1=belt + 0.16, r=0.05, crown=0.04),
                dict(z=cowl + 0.9, hw=0.12, y0=belt - 0.08, y1=belt + 0.04, r=0.04, crown=0.02),
            ],
            mats["paint"],
            0.008,
        )
        hood = join("PaintHood", [hood, scoop])
    return hood


def build_cab(spec: dict, mats: dict) -> bpy.types.Object:
    hw = spec["width"] * 0.4
    belt = spec["belt"]
    roof = spec["roof"]
    drop = spec["fastback"]
    z0 = spec["cab_rear"]
    z1 = spec["cab_front"]
    mid = (z0 + z1) / 2
    cab = loft(
        "PaintCab",
        [
            dict(z=z0, hw=hw * 0.96, y0=belt - 0.04, y1=roof - 0.08 - drop, r=spec["radius"] * 0.75, crown=spec["crown"], tumble=0.14),
            dict(z=mid, hw=hw, y0=belt - 0.06, y1=roof, r=spec["radius"] * 0.7, crown=spec["crown"] * 1.15, tumble=0.12),
            dict(z=z1, hw=hw * 0.94, y0=belt, y1=roof - 0.06, r=spec["radius"] * 0.65, crown=spec["crown"], tumble=0.1),
        ],
        mats["paint"],
        0.012,
    )
    return cab


def build_roof(spec: dict, mats: dict) -> bpy.types.Object:
    hw = spec["width"] * 0.36
    y = spec["roof"]
    rear_drop = spec["fastback"]
    stations = [
        dict(z=spec["cab_rear"], hw=hw * 0.92, y0=y - 0.08 - rear_drop, y1=y - rear_drop, r=0.04, crown=spec["crown"], tumble=0.2),
        dict(z=(spec["cab_rear"] + spec["cab_front"]) / 2, hw=hw, y0=y - 0.07, y1=y + 0.01, r=0.045, crown=spec["crown"] * 1.2, tumble=0.18),
        dict(z=spec["cab_front"], hw=hw * 0.9, y0=y - 0.1, y1=y - 0.02, r=0.04, crown=spec["crown"], tumble=0.16),
    ]
    return loft("PaintRoof", stations, mats["paint"], 0.008)


def cut_box(obj: bpy.types.Object, location: tuple[float, float, float], scale: tuple[float, float, float], rotation=(0.0, 0.0, 0.0)) -> None:
    cutter = primitive("Cutter", "cube", make_mat("CutterMat", (1, 0, 0)), size=1, location=location)
    cutter.scale = scale
    cutter.rotation_euler = rotation
    activate(cutter)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    mod = obj.modifiers.new("Window", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    apply_modifiers(obj)
    bpy.data.objects.remove(cutter, do_unlink=True)


def cut_windows(cab: bpy.types.Object, spec: dict) -> None:
    belt = spec["belt"]
    roof = spec["roof"]
    z0 = spec["cab_rear"]
    z1 = spec["cab_front"]
    mid_z = (z0 + z1) / 2
    mid_y = (belt + roof) / 2 + 0.02
    # Reach past the inner seat so the opening is a real window, not a painted pocket.
    cut_box(cab, (0.55, mid_y, mid_z), (0.42, 0.18, 0.34))
    cut_box(cab, (-0.55, mid_y, mid_z), (0.42, 0.18, 0.34))
    cut_box(cab, (0.0, mid_y + 0.06, z1 - 0.02), (0.62, 0.2, 0.22), (spec["rake"] * 0.35, 0.0, 0.0))
    cut_box(cab, (0.0, mid_y, z0 + 0.04), (0.5, 0.14, 0.16))


def build_interior(spec: dict, mats: dict) -> list[bpy.types.Object]:
    belt = spec["belt"]
    z0 = spec["cab_rear"]
    z1 = spec["cab_front"]
    made: list[bpy.types.Object] = []
    for z in (z0 + (z1 - z0) * 0.42, z0 + (z1 - z0) * 0.68):
        for side in (-1, 1):
            cushion = primitive("Interior", "uv", mats["interior"], radius=0.12, location=(side * 0.22, belt + 0.16, z), segments=12, ring_count=8)
            cushion.scale = (1.1, 0.55, 0.85)
            activate(cushion)
            bpy.ops.object.transform_apply(scale=True)
            back = primitive("Interior", "uv", mats["interior"], radius=0.11, location=(side * 0.22, belt + 0.32, z - 0.06), segments=12, ring_count=8)
            back.scale = (1.0, 0.9, 0.45)
            activate(back)
            bpy.ops.object.transform_apply(scale=True)
            made.extend([cushion, back])
    dash = primitive("Interior", "cube", mats["interior"], size=1, location=(0, belt + 0.22, z1 - 0.22))
    dash.scale = (0.48, 0.06, 0.1)
    activate(dash)
    bpy.ops.object.transform_apply(scale=True)
    wheel = primitive("Interior", "torus", mats["interior"], major_radius=0.09, minor_radius=0.012, location=(0.28, belt + 0.34, z1 - 0.28), rotation=(math.radians(70), 0, 0))
    made.extend([dash, wheel])
    return made


def glass_sheet(
    name: str,
    center: tuple[float, float, float],
    rotation: tuple[float, float, float],
    width: float,
    height: float,
    mat: bpy.types.Material,
    bend: float = 0.012,
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=10, y_segments=5, size=1)
    for vert in bm.verts:
        vert.co.x *= width / 2
        vert.co.y *= height / 2
        nx = vert.co.x / max(width / 2, 1e-4)
        ny = vert.co.y / max(height / 2, 1e-4)
        vert.co.z += bend * (1 - nx * nx) * (1 - ny * ny)
    obj = mesh_from_bmesh(name, bm, mat)
    obj.location = center
    obj.rotation_euler = rotation
    return obj


def build_glass(spec: dict, mats: dict) -> list[bpy.types.Object]:
    belt = spec["belt"]
    roof = spec["roof"]
    z0 = spec["cab_rear"]
    z1 = spec["cab_front"]
    mid_z = (z0 + z1) / 2
    mid_y = (belt + roof) / 2 + 0.02
    made: list[bpy.types.Object] = []
    for side in (-1, 1):
        glass = primitive(
            "Glass",
            "cube",
            mats["glass"],
            size=1,
            location=(side * 0.72, mid_y, mid_z),
        )
        glass.scale = (0.01, 0.3, 0.58)
        activate(glass)
        bpy.ops.object.transform_apply(scale=True)
        made.append(glass)
        x = side * 0.735
        made.append(primitive("Paint", "cube", mats["paint"], size=1, location=(x, mid_y + 0.16, mid_z)))
        made.append(primitive("Paint", "cube", mats["paint"], size=1, location=(x, mid_y - 0.16, mid_z)))
        made.append(primitive("Paint", "cube", mats["paint"], size=1, location=(x, mid_y, mid_z + 0.3)))
        made.append(primitive("Paint", "cube", mats["paint"], size=1, location=(x, mid_y, mid_z - 0.3)))
        for piece, scale in zip(made[-4:], ((0.012, 0.02, 0.64), (0.012, 0.02, 0.64), (0.012, 0.32, 0.02), (0.012, 0.32, 0.02))):
            piece.scale = scale
            activate(piece)
            bpy.ops.object.transform_apply(scale=True)
    windshield = primitive("Glass", "cube", mats["glass"], size=1, location=(0, mid_y + 0.05, z1 + 0.015))
    windshield.scale = (1.02, 0.3, 0.01)
    windshield.rotation_euler = (spec["rake"] * 0.2, 0, 0)
    activate(windshield)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    made.append(windshield)
    return made


def build_pillars(spec: dict, mats: dict) -> list[bpy.types.Object]:
    half = spec["width"] * 0.43
    header = (0, spec["roof"] - 0.06, spec["cab_front"])
    cowl_l = (-half, spec["belt"] + 0.04, spec["cab_front"] + 0.2)
    cowl_r = (half, spec["belt"] + 0.04, spec["cab_front"] + 0.2)
    rear_y = spec["roof"] - 0.05 - spec["fastback"]
    made = [
        tube("Paint", [(-half, header[1], header[2]), (half, header[1], header[2])], 0.018, mats["paint"]),
        tube("Paint", [cowl_l, (-half * 0.92, header[1], header[2])], 0.02, mats["paint"]),
        tube("Paint", [cowl_r, (half * 0.92, header[1], header[2])], 0.02, mats["paint"]),
        tube(
            "Paint",
            [(-half, spec["belt"] + 0.05, spec["cab_rear"]), (-half * 0.9, rear_y, spec["cab_rear"] + 0.04)],
            0.018,
            mats["paint"],
        ),
        tube(
            "Paint",
            [(half, spec["belt"] + 0.05, spec["cab_rear"]), (half * 0.9, rear_y, spec["cab_rear"] + 0.04)],
            0.018,
            mats["paint"],
        ),
    ]
    b_z = spec["cab_rear"] + (spec["cab_front"] - spec["cab_rear"]) * 0.48
    for side in (-1, 1):
        made.append(
            tube(
                "Plastic",
                [
                    (side * half, spec["belt"] + 0.05, b_z),
                    (side * half * 0.95, spec["roof"] - 0.08, b_z),
                ],
                0.016,
                mats["plastic"],
            )
        )
    return made


def build_bed(spec: dict, mats: dict) -> list[bpy.types.Object]:
    _, _, _, rear_z = axles(spec)
    bed_front = spec["cab_rear"] - 0.04
    bed_rear = rear_z + 0.2
    length = bed_front - bed_rear
    mid = (bed_front + bed_rear) / 2
    hw = spec["width"] * 0.47
    wall = 0.42 if not spec["fastback"] else 0.32
    if spec["rack"]:
        wall = 0.5
    floor = primitive("Plastic", "cube", mats["plastic"], size=1, location=(0, spec["clearance"] + 0.18, mid))
    floor.scale = (hw * 0.92, 0.04, length / 2)
    activate(floor)
    bpy.ops.object.transform_apply(scale=True)
    bevel(floor, 0.008, 1, 40)
    pieces = [floor]
    for side in (-1, 1):
        panel = primitive("Paint", "cube", mats["paint"], size=1, location=(side * hw, spec["belt"] * 0.55, mid))
        panel.scale = (0.035, wall / 2, length / 2)
        activate(panel)
        bpy.ops.object.transform_apply(scale=True)
        bevel(panel, 0.006, 2, 35)
        rail = tube(
            "Chrome",
            [(side * hw, spec["belt"] * 0.55 + wall / 2, bed_rear + 0.05), (side * hw, spec["belt"] * 0.55 + wall / 2, bed_front - 0.05)],
            0.018,
            mats["chrome"],
        )
        pieces.extend([panel, rail])
    tail = primitive("Paint", "cube", mats["paint"], size=1, location=(0, spec["belt"] * 0.55, bed_rear))
    tail.scale = (hw, wall / 2, 0.03)
    activate(tail)
    bpy.ops.object.transform_apply(scale=True)
    bevel(tail, 0.006, 2, 35)
    pieces.append(tail)
    plate = primitive("Plate", "cube", mats["plate"], size=1, location=(0, spec["clearance"] + 0.42, bed_rear - 0.02))
    plate.scale = (0.16, 0.055, 0.008)
    activate(plate)
    bpy.ops.object.transform_apply(scale=True)
    pieces.append(plate)
    if spec["rack"]:
        pieces.append(
            tube(
                "Plastic",
                [(-hw, spec["belt"] + 0.15, bed_front), (-hw, spec["roof"] - 0.15, bed_front), (hw, spec["roof"] - 0.15, bed_front), (hw, spec["belt"] + 0.15, bed_front)],
                0.02,
                mats["plastic"],
            )
        )
    if spec["cage"]:
        for z in (mid - length * 0.2, mid + length * 0.18):
            pieces.append(
                tube(
                    "Plastic",
                    [(-hw * 0.85, spec["belt"] * 0.4, z), (-hw * 0.85, spec["belt"] + 0.28, z), (hw * 0.85, spec["belt"] + 0.28, z), (hw * 0.85, spec["belt"] * 0.4, z)],
                    0.018,
                    mats["plastic"],
                )
            )
    return pieces


def build_face(spec: dict, mats: dict) -> list[bpy.types.Object]:
    _, _, front_z, _ = axles(spec)
    nose = spec["hood_nose"]
    y = spec["clearance"] + 0.46
    hw = spec["width"] * 0.38
    made: list[bpy.types.Object] = []
    opening = primitive("Plastic", "cube", mats["plastic"], size=1, location=(0, y, nose + 0.02))
    opening.scale = (hw, 0.11, 0.02)
    activate(opening)
    bpy.ops.object.transform_apply(scale=True)
    bevel(opening, 0.008, 2, 30)
    made.append(opening)
    if spec["grille"] == "bars":
        for index in range(3):
            bar = primitive("Chrome", "cube", mats["chrome"], size=1, location=(0, y - 0.07 + index * 0.07, nose + 0.045))
            bar.scale = (hw * 0.85, 0.012, 0.008)
            activate(bar)
            bpy.ops.object.transform_apply(scale=True)
            made.append(bar)
        badge = primitive("Chrome", "torus", mats["chrome"], major_radius=0.045, minor_radius=0.008, location=(0, y + 0.02, nose + 0.06))
        made.append(badge)
        chevron_l = tube("Chrome", [(-0.03, y - 0.01, nose + 0.07), (0, y + 0.045, nose + 0.07)], 0.006, mats["chrome"], 3)
        chevron_r = tube("Chrome", [(0.03, y - 0.01, nose + 0.07), (0, y + 0.045, nose + 0.07)], 0.006, mats["chrome"], 3)
        made.extend([chevron_l, chevron_r])
    elif spec["grille"] == "slots":
        for index in range(-3, 4):
            slat = primitive("Chrome", "cube", mats["chrome"], size=1, location=(index * 0.07, y, nose + 0.04))
            slat.scale = (0.012, 0.09, 0.008)
            activate(slat)
            bpy.ops.object.transform_apply(scale=True)
            made.append(slat)
    elif spec["grille"] == "grid":
        for index in range(4):
            bar = primitive("Chrome", "cube", mats["chrome"], size=1, location=(0, y - 0.08 + index * 0.05, nose + 0.04))
            bar.scale = (hw * 0.8, 0.008, 0.006)
            activate(bar)
            bpy.ops.object.transform_apply(scale=True)
            made.append(bar)
        for index in range(-2, 3):
            bar = primitive("Chrome", "cube", mats["chrome"], size=1, location=(index * 0.1, y, nose + 0.05))
            bar.scale = (0.008, 0.09, 0.006)
            activate(bar)
            bpy.ops.object.transform_apply(scale=True)
            made.append(bar)
    else:
        slit = primitive("Light", "cube", mats["light"], size=1, location=(0, y + 0.02, nose + 0.04))
        slit.scale = (hw * 0.7, 0.012, 0.01)
        activate(slit)
        bpy.ops.object.transform_apply(scale=True)
        made.append(slit)

    lamp_y = y + (0.12 if spec["lamps"] != "blade" else 0.1)
    for side in (-1, 1):
        x = side * hw * 0.72
        if spec["lamps"] == "round":
            bucket = primitive("Chrome", "cylinder", mats["chrome"], vertices=24, radius=0.09, depth=0.05, location=(x, lamp_y, nose + 0.03), rotation=(math.radians(90), 0, 0))
            lens = primitive("Light", "uv", mats["light"], radius=0.07, location=(x, lamp_y, nose + 0.06), segments=24, ring_count=12)
            lens.scale = (1, 1, 0.35)
            activate(lens)
            bpy.ops.object.transform_apply(scale=True)
            made.extend([bucket, lens])
        elif spec["lamps"] == "rect":
            bucket = primitive("Chrome", "cube", mats["chrome"], size=1, location=(x, lamp_y, nose + 0.03))
            bucket.scale = (0.14, 0.07, 0.03)
            activate(bucket)
            bpy.ops.object.transform_apply(scale=True)
            bevel(bucket, 0.012, 2, 30)
            lens = primitive("Light", "cube", mats["light"], size=1, location=(x, lamp_y, nose + 0.055))
            lens.scale = (0.11, 0.045, 0.01)
            activate(lens)
            bpy.ops.object.transform_apply(scale=True)
            made.extend([bucket, lens])
        else:
            lens = primitive("Light", "cube", mats["light"], size=1, location=(side * 0.42, lamp_y, nose + 0.05))
            lens.scale = (0.28, 0.018, 0.012)
            activate(lens)
            bpy.ops.object.transform_apply(scale=True)
            bevel(lens, 0.004, 1, 20)
            made.append(lens)
    for side in (-1, 1):
        tail_x = side * spec["width"] * 0.4
        _, _, _, rear_z = axles(spec)
        lamp = primitive("Tail", "cube", mats["tail"], size=1, location=(tail_x, spec["clearance"] + 0.55, rear_z + 0.12))
        lamp.scale = (0.09, 0.045, 0.02)
        activate(lamp)
        bpy.ops.object.transform_apply(scale=True)
        bevel(lamp, 0.008, 2, 25)
        made.append(lamp)
    return made


def build_details(spec: dict, mats: dict) -> list[bpy.types.Object]:
    made: list[bpy.types.Object] = []
    half = spec["width"] / 2 + spec["flare"] * 0.3
    for side in (-1, 1):
        mirror = primitive("Chrome", "uv", mats["chrome"], radius=0.055, location=(side * (half + 0.06), spec["belt"] + 0.18, spec["cab_front"] - 0.05), segments=16, ring_count=8)
        mirror.scale = (0.35, 1.1, 0.8)
        activate(mirror)
        bpy.ops.object.transform_apply(scale=True)
        stalk = tube(
            "Plastic",
            [(side * half, spec["belt"] + 0.12, spec["cab_front"] - 0.05), (side * (half + 0.05), spec["belt"] + 0.18, spec["cab_front"] - 0.05)],
            0.01,
            mats["plastic"],
            3,
        )
        handle = primitive("Chrome", "cube", mats["chrome"], size=1, location=(side * (half + 0.01), spec["belt"] - 0.02, (spec["cab_front"] + spec["cab_rear"]) / 2))
        handle.scale = (0.012, 0.018, 0.07)
        activate(handle)
        bpy.ops.object.transform_apply(scale=True)
        bevel(handle, 0.004, 1, 20)
        board_z0 = spec["cab_rear"]
        board_z1 = spec["cab_front"]
        board = tube(
            "Plastic",
            [(side * (half - 0.02), spec["clearance"] + 0.02, board_z0), (side * (half - 0.02), spec["clearance"] + 0.02, board_z1)],
            0.02 if not spec["skirt"] else 0.045,
            mats["plastic"],
        )
        made.extend([mirror, stalk, handle, board])
        for z in (spec["cab_rear"] + 0.08, (spec["cab_front"] + spec["cab_rear"]) * 0.55, spec["cab_front"] - 0.05):
            seam = primitive("Plastic", "cube", mats["plastic"], size=1, location=(side * (spec["width"] * 0.39), (spec["roof"] + spec["belt"]) / 2, z))
            seam.scale = (0.006, (spec["roof"] - spec["clearance"]) * 0.28, 0.008)
            activate(seam)
            bpy.ops.object.transform_apply(scale=True)
            made.append(seam)
    if spec["intake"]:
        made.append(
            tube(
                "Plastic",
                [
                    (half * 0.7, spec["belt"] - 0.05, spec["hood_nose"] - 0.4),
                    (half + 0.02, spec["belt"] + 0.15, spec["cab_front"]),
                    (half + 0.02, spec["roof"] - 0.05, spec["cab_front"] - 0.1),
                ],
                0.035,
                mats["plastic"],
            )
        )
    antenna = tube(
        "Plastic",
        [(half * 0.45, spec["roof"], spec["cab_rear"] + 0.2), (half * 0.55, spec["roof"] + 0.28, spec["cab_rear"] + 0.05)],
        0.006,
        mats["plastic"],
        3,
    )
    made.append(antenna)
    made.extend(build_interior(spec, mats))
    return made


def build_truck(spec: dict) -> tuple[list[bpy.types.Object], dict]:
    mats = palette(spec)
    front, rear, front_z, rear_z = axles(spec)
    cab = build_cab(spec, mats)
    cut_windows(cab, spec)
    objects: list[bpy.types.Object] = [
        build_body(spec, mats),
        build_hood(spec, mats),
        cab,
        build_roof(spec, mats),
        *build_glass(spec, mats),
        *build_bed(spec, mats),
        *build_face(spec, mats),
        *build_details(spec, mats),
    ]
    anchors = {
        "bumper_front": [0, spec["clearance"] + 0.18, front_z - 0.02],
        "bumper_rear": [0, spec["clearance"] + 0.2, rear_z + 0.04],
        "lightbar": [0, spec["roof"] + 0.04, spec["cab_front"] - 0.05],
        "exhaust": [spec["width"] * 0.28, spec["clearance"] + 0.08, rear_z + 0.12],
        "spoiler": [0, spec["belt"] * 0.55 + 0.28, rear_z + 0.22],
    }
    for name, loc in anchors.items():
        objects.append(empty(f"anchor_{name}", tuple(loc)))
    wheels = []
    half = spec["track"] / 2
    for side_name, side in (("l", -1), ("r", 1)):
        for axle_name, z in (("f", front), ("r", rear)):
            wheels.append({"id": f"{axle_name}{side_name}", "position": [side * half, STOCK_TIRE_R, z]})
    meta = {"anchors": anchors, "wheels": wheels, "paint": spec["paint"]}
    return objects, meta


def export_glb(objects: list[bpy.types.Object], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    faces = 0
    for obj in objects:
        if obj.type == "MESH":
            faces += len(obj.data.polygons)
    print(f"exported {path.name} faces={faces}")


def studio_camera(kind: str) -> bpy.types.Object:
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 42
    cam_data.clip_start = 0.05
    cam_data.clip_end = 80
    cam = bpy.data.objects.new("Cam", cam_data)
    link(cam)
    target = bpy.data.objects.new("CamTarget", None)
    target.location = (0, 0.85, 0.1)
    link(target)
    if kind == "side":
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = 8.2
        cam.location = (14, 1.15, 0.05)
    elif kind == "front":
        cam.location = (0.2, 1.7, 9.5)
        cam_data.lens = 48
    else:
        cam.location = (7.2, 2.8, 8.4)
        cam_data.lens = 38
    target.location = (0, 0.95, 0.05)
    constraint = cam.constraints.new("TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    bpy.context.scene.camera = cam
    return cam


def studio_lights() -> None:
    world = bpy.data.worlds.new("Studio") if bpy.data.worlds.get("Studio") is None else bpy.data.worlds["Studio"]
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.04, 0.045, 0.05, 1)
    bg.inputs["Strength"].default_value = 0.55

    def area(name: str, location: tuple[float, float, float], size: tuple[float, float], energy: float, color: tuple[float, float, float]) -> None:
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.color = color
        light.shape = "RECTANGLE"
        light.size = size[0]
        light.size_y = size[1]
        obj = bpy.data.objects.new(name, light)
        obj.location = location
        link(obj)
        direction = Vector((0, 0.7, 0)) - Vector(location)
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    area("Key", (3.2, 4.2, 3.4), (3.4, 1.8), 1800, (1, 0.93, 0.84))
    area("Fill", (-3.6, 2.4, 2.2), (2.2, 1.4), 500, (0.75, 0.82, 1))
    area("Rim", (-2.2, 3.2, -3.4), (2.8, 1.2), 900, (0.7, 0.78, 1))
    bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.name = "Ground"
    assign(ground, make_mat("Ground", (0.07, 0.07, 0.075), 0.0, 0.8))


def render_still(path: Path, view: str) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 32
    scene.eevee.use_gtao = True
    scene.eevee.gtao_distance = 0.4
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 680
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(path)
    studio_camera(view)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.view_layer.update()
    bpy.ops.render.render(write_still=True)
    print(f"rendered {path}")


def preview_wheels(spec: dict, mats: dict) -> list[bpy.types.Object]:
    made = []
    front, rear, _, _ = axles(spec)
    half = spec["track"] / 2
    for z in (front, rear):
        for side in (-1, 1):
            tire = primitive(
                "Rubber",
                "cylinder",
                mats["rubber"],
                vertices=28,
                radius=STOCK_TIRE_R,
                depth=0.26,
                location=(side * half, STOCK_TIRE_R, z),
                rotation=(0, math.radians(90), 0),
            )
            rim = primitive(
                "Chrome",
                "cylinder",
                mats["chrome"],
                vertices=20,
                radius=STOCK_TIRE_R * 0.62,
                depth=0.28,
                location=(side * half, STOCK_TIRE_R, z),
                rotation=(0, math.radians(90), 0),
            )
            made.extend([tire, rim])
    return made


def build_rim(style: dict, mats: dict) -> bpy.types.Object:
    pieces = []
    barrel = primitive("Chrome", "cylinder", mats["chrome"], vertices=32, radius=0.2, depth=0.16, rotation=(0, math.radians(90), 0))
    pieces.append(barrel)
    if style["lip"] > 0:
        lip = primitive(
            "Chrome",
            "cylinder",
            mats["chrome"],
            vertices=32,
            radius=0.23 + style["lip"] * 0.03,
            depth=0.035,
            location=(0.07, 0, 0),
            rotation=(0, math.radians(90), 0),
        )
        pieces.append(lip)
    if style["beadlock"]:
        ring = primitive(
            "Chrome",
            "torus",
            mats["chrome"],
            major_radius=0.225,
            minor_radius=0.012,
            major_segments=36,
            minor_segments=8,
            location=(0.06, 0, 0),
            rotation=(0, math.radians(90), 0),
        )
        pieces.append(ring)
    for index in range(style["spokes"]):
        ang = (index / style["spokes"]) * math.pi * 2 + (0.35 if style["turbine"] else 0)
        spoke = primitive(
            "Chrome",
            "cylinder",
            mats["chrome"],
            vertices=8,
            radius=style["radius"],
            depth=0.16,
            location=(0, math.cos(ang) * 0.1, math.sin(ang) * 0.1),
            rotation=(ang + (0.5 if style["turbine"] else 0), 0, 0),
        )
        pieces.append(spoke)
    hub = primitive("Chrome", "cylinder", mats["chrome"], vertices=20, radius=0.055, depth=0.18, rotation=(0, math.radians(90), 0))
    cap = primitive("Chrome", "uv", mats["chrome"], radius=0.04, location=(0.09, 0, 0), segments=16, ring_count=8)
    pieces.extend([hub, cap])
    obj = join(style["name"], pieces, mats["chrome"])
    shade_all(obj)
    return obj


def build_tire(style: dict, mats: dict) -> bpy.types.Object:
    tire = primitive(
        "Rubber",
        "torus",
        mats["rubber"],
        major_radius=style["radius"] * 0.86,
        minor_radius=max(0.055, style["width"] * 0.22),
        major_segments=40,
        minor_segments=12,
        rotation=(0, math.radians(90), 0),
    )
    shade_all(tire)
    pieces = [tire]
    if style["tread"] != "rib":
        count = 8 if style["tread"] == "paddle" else 14 if style["tread"] == "mud" else 18
        lug_h = 0.045 if style["tread"] == "paddle" else 0.03 if style["tread"] == "mud" else 0.016
        lug_d = 0.12 if style["tread"] == "paddle" else 0.05
        for index in range(count):
            ang = (index / count) * math.pi * 2
            lug = primitive(
                "Rubber",
                "cube",
                mats["rubber"],
                size=1,
                location=(0, math.cos(ang) * (style["radius"] + lug_h * 0.2), math.sin(ang) * (style["radius"] + lug_h * 0.2)),
                rotation=(ang, 0, 0),
            )
            lug.scale = (style["width"] * 0.72, lug_h, lug_d)
            activate(lug)
            bpy.ops.object.transform_apply(scale=True)
            pieces.append(lug)
    return join(style["name"], pieces, mats["rubber"])


def build_bumper(kind: str, mats: dict) -> bpy.types.Object:
    if kind == "factory":
        bar = primitive("Paint", "cube", mats["paint"], size=1, location=(0, 0.08, 0.08))
        bar.scale = (0.98, 0.11, 0.07)
        activate(bar)
        bpy.ops.object.transform_apply(scale=True)
        bevel(bar, 0.02, 3, 30)
        val = primitive("Plastic", "cube", mats["plastic"], size=1, location=(0, -0.02, 0.1))
        val.scale = (0.7, 0.035, 0.04)
        activate(val)
        bpy.ops.object.transform_apply(scale=True)
        return join("bp-factory", [bar, val])
    if kind == "tube":
        bar = tube("Plastic", [(-0.9, 0.02, 0.1), (0.9, 0.02, 0.1)], 0.04, mats["plastic"])
        left = tube("Plastic", [(-0.78, 0.02, 0.1), (-0.78, 0.22, 0.1)], 0.032, mats["plastic"])
        right = tube("Plastic", [(0.78, 0.02, 0.1), (0.78, 0.22, 0.1)], 0.032, mats["plastic"])
        return join("bp-tube", [bar, left, right])
    if kind == "winch":
        plate = primitive("Plastic", "cube", mats["plastic"], size=1, location=(0, 0.08, 0.08))
        plate.scale = (0.92, 0.14, 0.08)
        activate(plate)
        bpy.ops.object.transform_apply(scale=True)
        bevel(plate, 0.012, 2, 30)
        drum = primitive("Chrome", "cylinder", mats["chrome"], vertices=20, radius=0.07, depth=0.28, location=(0, 0.08, 0.14), rotation=(0, math.radians(90), 0))
        return join("bp-winch", [plate, drum])
    hoop = tube("Plastic", [(-0.82, 0.02, 0.08), (-0.82, 0.02, 0.28), (0.82, 0.02, 0.28), (0.82, 0.02, 0.08)], 0.038, mats["plastic"])
    upright_l = tube("Plastic", [(-0.7, 0.02, 0.22), (-0.7, 0.24, 0.22)], 0.03, mats["plastic"])
    upright_r = tube("Plastic", [(0.7, 0.02, 0.22), (0.7, 0.24, 0.22)], 0.03, mats["plastic"])
    skid = primitive("Plastic", "cube", mats["plastic"], size=1, location=(0, -0.04, 0.2))
    skid.scale = (0.62, 0.02, 0.18)
    activate(skid)
    bpy.ops.object.transform_apply(scale=True)
    return join("bp-pre", [hoop, upright_l, upright_r, skid])


def build_light(kind: str, mats: dict) -> bpy.types.Object:
    pieces = []
    if kind in ("pods", "dual"):
        for side in (-1, 1):
            pod = primitive("Plastic", "cube", mats["plastic"], size=1, location=(side * 0.42, 0, 0))
            pod.scale = (0.1, 0.06, 0.07)
            activate(pod)
            bpy.ops.object.transform_apply(scale=True)
            bevel(pod, 0.012, 2, 25)
            lens = primitive("Light", "cube", mats["light"], size=1, location=(side * 0.42, 0, 0.04))
            lens.scale = (0.07, 0.035, 0.01)
            activate(lens)
            bpy.ops.object.transform_apply(scale=True)
            pieces.extend([pod, lens])
    if kind in ("bar", "dual"):
        housing = primitive("Plastic", "cube", mats["plastic"], size=1, location=(0, 0.08, 0))
        housing.scale = (0.62, 0.035, 0.045)
        activate(housing)
        bpy.ops.object.transform_apply(scale=True)
        bevel(housing, 0.008, 2, 25)
        lens = primitive("Light", "cube", mats["light"], size=1, location=(0, 0.09, 0.03))
        lens.scale = (0.54, 0.018, 0.008)
        activate(lens)
        bpy.ops.object.transform_apply(scale=True)
        pieces.extend([housing, lens])
    return join(f"lt-{kind}", pieces)


def build_exhaust(kind: str, mats: dict) -> bpy.types.Object:
    if kind == "stock":
        pipe = tube("Chrome", [(0, 0, 0.32), (0, 0, 0.04)], 0.032, mats["chrome"])
        tip = primitive("Chrome", "cylinder", mats["chrome"], vertices=16, radius=0.045, depth=0.06, location=(0, 0, 0.02), rotation=(math.radians(90), 0, 0))
        return join("ex-stock", [pipe, tip])
    if kind == "side":
        pipe = tube("Chrome", [(0, 0, 0.25), (0.08, 0, 0.08), (0.2, 0, 0)], 0.042, mats["chrome"])
        tip = primitive("Chrome", "cylinder", mats["chrome"], vertices=16, radius=0.055, depth=0.07, location=(0.22, 0, 0), rotation=(0, math.radians(90), 0))
        return join("ex-side", [pipe, tip])
    left = tube("Chrome", [(-0.16, 0, 0), (-0.16, 0.85, 0)], 0.045, mats["chrome"])
    right = tube("Chrome", [(0.16, 0, 0), (0.16, 0.85, 0)], 0.045, mats["chrome"])
    return join("ex-stack", [left, right])


def build_spoiler(kind: str, mats: dict) -> bpy.types.Object:
    if kind == "lip":
        lip = primitive("Paint", "cube", mats["paint"], size=1, location=(0, 0.03, 0))
        lip.scale = (0.72, 0.025, 0.08)
        activate(lip)
        bpy.ops.object.transform_apply(scale=True)
        bevel(lip, 0.008, 2, 30)
        lip.name = "sp-lip"
        return lip
    wing = primitive("Paint", "cube", mats["paint"], size=1, location=(0, 0.16, 0))
    wing.scale = (0.78, 0.018, 0.12)
    activate(wing)
    bpy.ops.object.transform_apply(scale=True)
    bevel(wing, 0.006, 2, 25)
    stands = []
    for side in (-1, 1):
        stand = primitive("Plastic", "cube", mats["plastic"], size=1, location=(side * 0.42, 0.08, 0))
        stand.scale = (0.02, 0.08, 0.05)
        activate(stand)
        bpy.ops.object.transform_apply(scale=True)
        stands.append(stand)
    return join("sp-wing", [wing, *stands])


def part_mats() -> dict[str, bpy.types.Material]:
    return {
        "paint": make_mat("Paint", (0.55, 0.24, 0.1), 0.15, 0.22, coat=1),
        "chrome": make_mat("Chrome", (0.78, 0.82, 0.86), 1, 0.12, coat=0.25),
        "plastic": make_mat("Plastic", (0.08, 0.08, 0.09), 0.4, 0.45),
        "rubber": make_mat("Rubber", (0.02, 0.02, 0.02), 0, 0.84),
        "light": make_mat("Light", (1, 0.9, 0.72), 0, 0.2, emit=5),
    }


RIMS = [
    {"id": "wh-steel", "name": "wh-steel", "spokes": 8, "radius": 0.012, "lip": 0, "beadlock": False, "turbine": False},
    {"id": "wh-five", "name": "wh-five", "spokes": 5, "radius": 0.016, "lip": 0.2, "beadlock": False, "turbine": False},
    {"id": "wh-deep", "name": "wh-deep", "spokes": 5, "radius": 0.013, "lip": 1, "beadlock": False, "turbine": False},
    {"id": "wh-bead", "name": "wh-bead", "spokes": 6, "radius": 0.014, "lip": 0.25, "beadlock": True, "turbine": False},
    {"id": "wh-mesh", "name": "wh-mesh", "spokes": 12, "radius": 0.007, "lip": 0.45, "beadlock": False, "turbine": False},
    {"id": "wh-turbine", "name": "wh-turbine", "spokes": 7, "radius": 0.014, "lip": 0.7, "beadlock": False, "turbine": True},
]

TIRES = [
    {"id": "ti-hwy", "name": "ti-hwy", "radius": 0.38, "width": 0.26, "tread": "rib"},
    {"id": "ti-at", "name": "ti-at", "radius": 0.4, "width": 0.28, "tread": "allterrain"},
    {"id": "ti-mud", "name": "ti-mud", "radius": 0.43, "width": 0.32, "tread": "mud"},
    {"id": "ti-paddle", "name": "ti-paddle", "radius": 0.45, "width": 0.34, "tread": "paddle"},
]


def _as_list(obj):
    return obj if isinstance(obj, list) else [obj]


def export_parts() -> None:
    mats = part_mats()
    for style in RIMS:
        reset_scene()
        mats = part_mats()
        export_glb(_as_list(build_rim(style, mats)), MODEL_ROOT / "parts" / f"{style['id']}.glb")
    for style in TIRES:
        reset_scene()
        mats = part_mats()
        export_glb(_as_list(build_tire(style, mats)), MODEL_ROOT / "parts" / f"{style['id']}.glb")
    for kind, builder in (
        ("bp-factory", lambda m: build_bumper("factory", m)),
        ("bp-tube", lambda m: build_bumper("tube", m)),
        ("bp-winch", lambda m: build_bumper("winch", m)),
        ("bp-pre", lambda m: build_bumper("prerunner", m)),
        ("lt-pods", lambda m: build_light("pods", m)),
        ("lt-bar", lambda m: build_light("bar", m)),
        ("lt-dual", lambda m: build_light("dual", m)),
        ("ex-stock", lambda m: build_exhaust("stock", m)),
        ("ex-side", lambda m: build_exhaust("side", m)),
        ("ex-stack", lambda m: build_exhaust("stack", m)),
        ("sp-lip", lambda m: build_spoiler("lip", m)),
        ("sp-wing", lambda m: build_spoiler("wing", m)),
    ):
        reset_scene()
        mats = part_mats()
        export_glb(_as_list(builder(mats)), MODEL_ROOT / "parts" / f"{kind}.glb")


def export_trucks(only: str | None) -> None:
    manifest = {}
    for spec in TRUCKS:
        if only and only not in spec["id"] and only != "trucks":
            continue
        reset_scene()
        objects, meta = build_truck(spec)
        if os.environ.get("SKIP_PREVIEW") != "1":
            preview = preview_wheels(spec, palette(spec))
            studio_lights()
            render_still(PREVIEW_DIR / f"{spec['id']}-three-quarter.png", "34")
            render_still(PREVIEW_DIR / f"{spec['id']}-side.png", "side")
            for obj in preview:
                bpy.data.objects.remove(obj, do_unlink=True)
        exportable = [obj for obj in objects if obj.name in bpy.data.objects]
        export_glb(exportable, MODEL_ROOT / "trucks" / f"{spec['id']}.glb")
        manifest[spec["id"]] = meta
    if manifest:
        existing = {}
        if ANCHOR_PATH.exists() and only:
            existing = json.loads(ANCHOR_PATH.read_text())
        existing.update(manifest)
        ANCHOR_PATH.write_text(json.dumps(existing, indent=2))
        print(f"wrote {ANCHOR_PATH}")


def _bind_hero() -> None:
    import importlib.util

    path = Path(__file__).with_name("hero_parts.py")
    spec = importlib.util.spec_from_file_location("hero_parts", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    globals()["build_rim"] = module.build_rim
    globals()["build_tire"] = module.build_tire
    globals()["build_bumper"] = module.build_bumper


_bind_hero()


def main() -> None:
    only = argv_filter()
    MODEL_ROOT.joinpath("trucks").mkdir(parents=True, exist_ok=True)
    MODEL_ROOT.joinpath("parts").mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    if only in (None, "parts"):
        export_parts()
    if only != "parts":
        export_trucks(None if only in (None, "trucks") else only)


if __name__ == "__main__":
    main()

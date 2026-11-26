"""Detailed rims, tires, and bumpers for Truck App.

Axis: axle along +X, origin at the hub, outer face toward +X.
Bumpers: mount on z=0, body extends toward +Z, centered on X.
"""

from __future__ import annotations

import math

import bmesh
import bpy

def _mat(name: str, color: tuple[float, float, float], metallic: float = 0.0, rough: float = 0.4) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def _link(obj: bpy.types.Object) -> bpy.types.Object:
    bpy.context.collection.objects.link(obj)
    return obj


def _activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _assign(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    if obj.data is None:
        return
    if mat.name not in obj.data.materials:
        obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = obj.data.materials.find(mat.name)


def _smooth(obj: bpy.types.Object) -> None:
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if hasattr(obj.data, "use_auto_smooth"):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(55)


def _cube(name: str, loc, scale, mat, rot=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = rot
    _activate(obj)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    _assign(obj, mat)
    return obj


def _cyl(name: str, loc, radius: float, depth: float, mat, rot=(0.0, math.pi / 2, 0.0), verts: int = 16) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    _assign(obj, mat)
    _smooth(obj)
    return obj


def _torus(name: str, loc, major: float, minor: float, mat, rot=(0.0, math.pi / 2, 0.0), major_seg: int = 28, minor_seg: int = 8) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=major_seg,
        minor_segments=minor_seg,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    _assign(obj, mat)
    _smooth(obj)
    return obj


def _spoke(name: str, ang: float, inner: float, outer: float, width: float, thick: float, mat, twist: float = 0.0, x: float = 0.045) -> bpy.types.Object:
    length = outer - inner
    mid = (inner + outer) / 2
    return _cube(
        name,
        (x, math.cos(ang) * mid, math.sin(ang) * mid),
        (thick, length, width),
        mat,
        (ang, twist, 0.0),
    )


def _lugs(mat, x: float, radius: float, count: int, nut_r: float = 0.012) -> list[bpy.types.Object]:
    made = []
    for i in range(count):
        ang = (i / count) * math.pi * 2
        made.append(_cyl("Chrome", (x, math.cos(ang) * radius, math.sin(ang) * radius), nut_r, 0.012, mat, verts=6))
    return made


def _tube(name: str, loc, radius: float, depth: float, mat, rot=(0.0, math.pi / 2, 0.0), verts: int = 24) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NOTHING",
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    _assign(obj, mat)
    _smooth(obj)
    return obj


def _mesh_object(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    _link(obj)
    _smooth(obj)
    return obj


def _tapered_spoke(
    name: str,
    ang: float,
    inner: float,
    outer: float,
    inner_w: float,
    outer_w: float,
    thick: float,
    mat,
    sweep: float = 0.0,
    x_inner: float = 0.04,
    x_outer: float = 0.04,
) -> bpy.types.Object:
    """Spoke in the YZ wheel plane. sweep leans the outer end around the axle."""

    def ring(radius: float, width: float, extra: float, px: float) -> list[tuple[float, float, float]]:
        a = ang + extra
        cy = math.cos(a) * radius
        cz = math.sin(a) * radius
        ty = -math.sin(a)
        tz = math.cos(a)
        hw = width * 0.5
        ht = thick * 0.5
        return [
            (px - ht, cy + ty * hw, cz + tz * hw),
            (px + ht, cy + ty * hw, cz + tz * hw),
            (px + ht, cy - ty * hw, cz - tz * hw),
            (px - ht, cy - ty * hw, cz - tz * hw),
        ]

    bm = bmesh.new()
    verts = [bm.verts.new(co) for co in ring(inner, inner_w, 0.0, x_inner) + ring(outer, outer_w, sweep, x_outer)]
    for face in (
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (3, 7, 4, 0),
    ):
        bm.faces.new([verts[i] for i in face])
    return _mesh_object(name, bm, mat)


def _join_roles(pieces: list[bpy.types.Object]) -> list[bpy.types.Object]:
    """One mesh per material role so a phone draws a handful of calls, not forty."""

    def role(obj: bpy.types.Object) -> str:
        if obj.name.startswith("ChromeLOD"):
            return "ChromeLOD"
        if obj.name.startswith("Rotor"):
            return "Rotor"
        if obj.name.startswith("Caliper"):
            return "Caliper"
        return "Chrome"

    groups: dict[str, list[bpy.types.Object]] = {}
    for obj in pieces:
        groups.setdefault(role(obj), []).append(obj)
    if bpy.context.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    joined: list[bpy.types.Object] = []
    for name, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        objs[0].name = name
        joined.append(objs[0])
    return joined


def _hardware(chrome, face_x: float, lug_count: int = 5) -> list[bpy.types.Object]:
    return [
        _cyl("Chrome", (0.02, 0, 0), 0.046, 0.028, chrome, verts=16),
        _cyl("Chrome", (face_x + 0.012, 0, 0), 0.034, 0.012, chrome, verts=18),
        *_lugs(chrome, face_x + 0.006, 0.058, lug_count),
        *_rotor_and_caliper(face_x),
    ]


def _coarse_lod(chrome, face_x: float, outer: float, spokes: int = 5, twist: float = 0.0) -> list[bpy.types.Object]:
    lod = [
        _tube("ChromeLOD", (0.0, 0, 0), 0.15, 0.1, chrome, verts=10),
        _torus("ChromeLOD", (face_x, 0, 0), outer, 0.012, chrome, major_seg=10, minor_seg=4),
    ]
    for i in range(spokes):
        ang = (i / spokes) * math.pi * 2
        lod.append(_spoke("ChromeLOD", ang, 0.05, outer - 0.02, 0.018, 0.01, chrome, twist, face_x))
    return lod


def _build_sleek_rim(style: dict) -> list[bpy.types.Object]:
    """Four forged faces. Same axle, lip, lugs, cap, and visible caliper as the other rims."""
    chrome = _mat("Chrome", (0.78, 0.82, 0.86), 1.0, 0.16)
    kind = style["id"]
    lip = style["lip"]
    outer = 0.228 + lip * 0.012
    face_x = 0.05 + lip * 0.012
    pieces: list[bpy.types.Object] = [
        _tube("Chrome", (0.0, 0, 0), 0.142, 0.11, chrome, verts=24),
        _torus("Chrome", (face_x, 0, 0), outer, 0.011 + lip * 0.003, chrome, major_seg=28, minor_seg=6),
    ]
    if kind == "wh-aero":
        # Thin radial wires plus a second set and two hoops, so the face reads as mesh.
        count = 14
        for i in range(count):
            ang = (i / count) * math.pi * 2
            pieces.append(_tapered_spoke("Chrome", ang, 0.062, outer - 0.012, 0.0045, 0.0055, 0.004, chrome, x_inner=face_x - 0.004, x_outer=face_x - 0.002))
            pieces.append(
                _tapered_spoke(
                    "Chrome",
                    ang + math.pi / count,
                    0.11,
                    outer - 0.016,
                    0.004,
                    0.0045,
                    0.0035,
                    chrome,
                    x_inner=face_x - 0.001,
                    x_outer=face_x + 0.001,
                )
            )
        pieces.append(_torus("Chrome", (face_x - 0.002, 0, 0), 0.118, 0.0032, chrome, major_seg=24, minor_seg=4))
        pieces.append(_torus("Chrome", (face_x, 0, 0), outer - 0.02, 0.003, chrome, major_seg=28, minor_seg=4))
        pieces.extend(_hardware(chrome, face_x, 5))
        pieces.extend(_coarse_lod(chrome, face_x, outer, 6))
    elif kind == "wh-blade":
        # Every blade leans the same way, narrow at the hub and wide at the lip.
        count = 9
        sweep = 0.95
        for i in range(count):
            ang = (i / count) * math.pi * 2
            pieces.append(
                _tapered_spoke(
                    "Chrome",
                    ang,
                    0.048,
                    0.14,
                    0.012,
                    0.024,
                    0.008,
                    chrome,
                    sweep=sweep * 0.4,
                    x_inner=face_x - 0.012,
                    x_outer=face_x - 0.002,
                )
            )
            pieces.append(
                _tapered_spoke(
                    "Chrome",
                    ang + sweep * 0.35,
                    0.1,
                    outer - 0.012,
                    0.02,
                    0.046,
                    0.008,
                    chrome,
                    sweep=sweep * 0.55,
                    x_inner=face_x - 0.006,
                    x_outer=face_x + 0.006,
                )
            )
        pieces.extend(_hardware(chrome, face_x, 5))
        pieces.extend(_coarse_lod(chrome, face_x, outer, 5, 0.35))
    elif kind == "wh-split":
        # Deep barrel with a Y spoke: one root, two tips, sitting at the back of the dish.
        dish_x = 0.028
        mouth_x = face_x + 0.03
        pieces.append(_tube("Chrome", ((dish_x + mouth_x) * 0.5, 0, 0), outer + 0.004, mouth_x - dish_x, chrome, verts=32))
        pieces.append(_torus("Chrome", (mouth_x, 0, 0), outer + 0.006, 0.009, chrome, major_seg=28, minor_seg=6))
        count = 5
        for i in range(count):
            ang = (i / count) * math.pi * 2 - 0.2
            pieces.append(_tapered_spoke("Chrome", ang, 0.048, 0.145, 0.022, 0.04, 0.012, chrome, x_inner=dish_x, x_outer=dish_x + 0.006))
            for side in (-1, 1):
                pieces.append(
                    _tapered_spoke(
                        "Chrome",
                        ang + side * 0.05,
                        0.128,
                        outer - 0.018,
                        0.016,
                        0.02,
                        0.01,
                        chrome,
                        sweep=side * 0.28,
                        x_inner=dish_x + 0.004,
                        x_outer=dish_x + 0.012,
                    )
                )
        pieces.extend(_hardware(chrome, dish_x + 0.01, 5))
        pieces.extend(_coarse_lod(chrome, mouth_x - 0.01, outer, 5))
    else:
        # Concave monoblock: five broad faces, narrow slots the caliper shows through.
        count = 5
        for i in range(count):
            ang = (i / count) * math.pi * 2
            pieces.append(
                _tapered_spoke(
                    "Chrome",
                    ang,
                    0.04,
                    outer - 0.012,
                    0.022,
                    0.245,
                    0.01,
                    chrome,
                    x_inner=face_x - 0.036,
                    x_outer=face_x + 0.02,
                )
            )
        pieces.extend(_hardware(chrome, face_x + 0.006, 5))
        pieces.extend(_coarse_lod(chrome, face_x, outer, 5))
    return _join_roles(pieces)


def _rotor_and_caliper(chrome_x: float) -> list[bpy.types.Object]:
    rotor_mat = _mat("Rotor", (0.55, 0.56, 0.58), 0.85, 0.38)
    caliper_mat = _mat("Caliper", (0.45, 0.08, 0.07), 0.25, 0.45)
    disc = _cyl("Rotor", (-0.035, 0, 0), 0.195, 0.012, rotor_mat, verts=32)
    hat = _cyl("Rotor", (-0.02, 0, 0), 0.07, 0.02, rotor_mat, verts=16)
    pockets = []
    for i in range(6):
        ang = (i / 6) * math.pi * 2
        pockets.append(_cyl("Rotor", (-0.028, math.cos(ang) * 0.13, math.sin(ang) * 0.13), 0.012, 0.008, _mat("Rotor", (0.25, 0.26, 0.28), 0.7, 0.5), verts=8))
    caliper = _cube("Caliper", (-0.03, 0.155, 0.0), (0.045, 0.07, 0.09), caliper_mat)
    return [disc, hat, *pockets, caliper]


def build_rim(style: dict, mats: dict | None = None) -> list[bpy.types.Object]:
    if style["id"] in {"wh-aero", "wh-blade", "wh-split", "wh-mono"}:
        return _build_sleek_rim(style)
    chrome = _mat("Chrome", (0.78, 0.82, 0.86), 1.0, 0.16)
    spokes = style["spokes"]
    lip = style["lip"]
    bead = style["beadlock"]
    turbine = style["turbine"]
    outer = 0.232 + lip * 0.02
    inner = 0.055
    width = 0.012 + (0.02 if spokes <= 6 else 0.0)
    thick = 0.012 if spokes < 10 else 0.007
    twist = 0.55 if turbine else 0.0
    face_x = 0.055 + lip * 0.02
    pieces: list[bpy.types.Object] = [
        _cyl("Chrome", (0.0, 0, 0), 0.155, 0.13, chrome, verts=28),
        _torus("Chrome", (face_x, 0, 0), outer, 0.012 + lip * 0.004, chrome),
        _cyl("Chrome", (0.03, 0, 0), 0.048, 0.04, chrome, verts=20),
        _cyl("Chrome", (face_x + 0.01, 0, 0), 0.034, 0.012, chrome, verts=20),
    ]
    for i in range(spokes):
        ang = (i / spokes) * math.pi * 2
        pieces.append(_spoke("Chrome", ang, inner, outer - 0.01, width, thick, chrome, twist, face_x - 0.01))
        if style["id"] == "wh-mesh":
            pieces.append(_spoke("Chrome", ang + math.pi / spokes, inner + 0.01, outer - 0.015, width * 0.7, thick, chrome, -twist, face_x - 0.005))
    pieces.extend(_lugs(chrome, face_x + 0.004, 0.062, 5 if spokes != 8 else 6))
    if bead:
        for i in range(12):
            ang = (i / 12) * math.pi * 2
            pieces.append(_cyl("Chrome", (face_x + 0.012, math.cos(ang) * (outer + 0.004), math.sin(ang) * (outer + 0.004)), 0.006, 0.01, chrome, verts=6))
        pieces.append(_torus("Chrome", (face_x + 0.008, 0, 0), outer + 0.01, 0.008, chrome, major_seg=32, minor_seg=6))
    if lip >= 1:
        pieces.append(_cyl("Chrome", (face_x + 0.02, 0, 0), outer + 0.012, 0.028, chrome, verts=32))
    pieces.extend(_rotor_and_caliper(face_x))
    # Coarse wheel for when the camera is far. Same axle, fewer spokes, no rotor pockets.
    lod = [
        _cyl("ChromeLOD", (0.0, 0, 0), 0.15, 0.1, chrome, verts=12),
        _torus("ChromeLOD", (face_x, 0, 0), outer, 0.012, chrome, major_seg=12, minor_seg=4),
    ]
    for i in range(5):
        ang = (i / 5) * math.pi * 2
        lod.append(_spoke("ChromeLOD", ang, 0.05, outer - 0.02, 0.02, 0.012, chrome, 0.0, face_x))
    pieces.extend(lod)
    return pieces


def _spin_tire(name: str, radius: float, width: float, mat, segments: int, grooves: bool) -> bpy.types.Object:
    w = width
    r = radius
    profile = [
        (-w * 0.48, r * 0.68),
        (-w * 0.40, r * 0.80),
        (-w * 0.28, r * 0.94),
        (-w * 0.16, r * 0.99),
        (-w * 0.08, r),
    ]
    if grooves:
        profile.extend([(-w * 0.03, r - 0.01), (0.0, r), (w * 0.03, r - 0.01)])
    else:
        profile.append((0.0, r))
    profile.extend(
        [
            (w * 0.08, r),
            (w * 0.16, r * 0.99),
            (w * 0.28, r * 0.94),
            (w * 0.40, r * 0.80),
            (w * 0.48, r * 0.68),
        ]
    )
    bm = bmesh.new()
    rings = []
    for i in range(segments):
        ang = (i / segments) * math.pi * 2
        ring = []
        for x, rad in profile:
            ring.append(bm.verts.new((x, rad * math.cos(ang), rad * math.sin(ang))))
        rings.append(ring)
    count = len(profile)
    uv = bm.loops.layers.uv.new("UVMap")
    for i in range(segments):
        nxt = (i + 1) % segments
        for k in range(count - 1):
            face = bm.faces.new((rings[i][k], rings[nxt][k], rings[nxt][k + 1], rings[i][k + 1]))
            coords = [(i / segments, k / count), (nxt / segments, k / count), (nxt / segments, (k + 1) / count), (i / segments, (k + 1) / count)]
            for loop, co in zip(face.loops, coords):
                loop[uv].uv = co
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    _link(obj)
    _smooth(obj)
    return obj


def _normal_image(kind: str) -> bpy.types.Image:
    name = f"TireNormal_{kind}"
    image = bpy.data.images.get(name)
    if image is not None:
        return image
    size = 128
    image = bpy.data.images.new(name, size, size)
    pixels = []
    for y in range(size):
        for x in range(size):
            nx, ny, nz = 0.5, 0.5, 1.0
            if kind == "rib" and y % 18 < 2:
                ny = 0.25
            elif kind == "allterrain" and (x % 20 < 4) and (y % 24 < 10):
                nx = 0.3
            elif kind == "mud" and (x % 16 < 5) and (y % 28 < 12):
                nx = 0.22
                ny = 0.35
            elif kind == "paddle" and x % 24 < 6:
                nx = 0.2
            pixels.extend((nx, ny, nz, 1.0))
    image.pixels.foreach_set(pixels)
    image.pack()
    return image


def _rubber(kind: str) -> bpy.types.Material:
    mat = _mat("Rubber", (0.02, 0.02, 0.022), 0.0, 0.78)
    image = _normal_image(kind)
    tree = mat.node_tree
    tex = tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    normal = tree.nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value = 0.7
    tree.links.new(tex.outputs["Color"], normal.inputs["Color"])
    tree.links.new(normal.outputs["Normal"], tree.nodes["Principled BSDF"].inputs["Normal"])
    return mat


def build_tire(style: dict, mats: dict | None = None) -> list[bpy.types.Object]:
    kind = style["tread"]
    rubber = _rubber(kind)
    radius = style["radius"]
    width = style["width"]
    tire = _spin_tire("Rubber", radius, width, rubber, 36, kind == "rib")
    pieces = [tire]
    band_r = radius * 0.9
    for side in (-1, 1):
        pieces.append(_torus("Rubber", (side * width * 0.30, 0, 0), band_r, 0.006, rubber, major_seg=28, minor_seg=6))
    if kind != "rib":
        count = 10 if kind == "paddle" else 16 if kind == "mud" else 20
        lug_h = 0.035 if kind == "paddle" else 0.022 if kind == "mud" else 0.012
        lug_w = 0.09 if kind == "paddle" else 0.045
        for i in range(count):
            ang = (i / count) * math.pi * 2 + (0.15 if kind == "paddle" else 0)
            pieces.append(
                _cube(
                    "Rubber",
                    (0, math.cos(ang) * (radius + lug_h * 0.35), math.sin(ang) * (radius + lug_h * 0.35)),
                    (width * 0.62, lug_h, lug_w),
                    rubber,
                    (ang, 0, 0),
                )
            )
    pieces.append(_spin_tire("RubberLOD", radius, width, rubber, 16, False))
    return pieces


def _bolts(mat, z: float, y: float, xs: list[float]) -> list[bpy.types.Object]:
    return [_cyl("Chrome", (x, y, z), 0.012, 0.012, mat, (math.pi / 2, 0, 0), verts=6) for x in xs]


def _shackle(mat, x: float, y: float, z: float) -> list[bpy.types.Object]:
    ring = _torus("Chrome", (x, y, z), 0.035, 0.008, mat, rot=(math.pi / 2, 0, 0), major_seg=16, minor_seg=6)
    pin = _cyl("Chrome", (x, y + 0.03, z), 0.008, 0.07, mat, (0, math.pi / 2, 0), verts=8)
    return [ring, pin]


def build_bumper(kind: str, mats: dict | None = None) -> list[bpy.types.Object]:
    paint = _mat("Paint", (0.55, 0.24, 0.1), 0.15, 0.28)
    plastic = _mat("Plastic", (0.07, 0.07, 0.08), 0.35, 0.48)
    chrome = _mat("Chrome", (0.78, 0.82, 0.86), 1.0, 0.18)
    light = _mat("Light", (0.9, 0.85, 0.7), 0.0, 0.3)
    pieces: list[bpy.types.Object] = []
    if kind == "factory":
        bar = _cube("Paint", (0, 0.08, 0.09), (1.86, 0.16, 0.12), paint)
        valence = _cube("Plastic", (0, -0.02, 0.12), (1.55, 0.06, 0.08), plastic)
        pieces.extend([bar, valence, _cube("PlasticLOD", (0, 0.06, 0.09), (1.86, 0.18, 0.12), plastic)])
        pieces.extend(_bolts(chrome, 0.14, 0.14, [-0.7, -0.35, 0.35, 0.7]))
        for side in (-1, 1):
            pieces.append(_cube("Plastic", (side * 0.62, 0.05, 0.15), (0.16, 0.06, 0.02), plastic))
            pieces.append(_cube("Light", (side * 0.62, 0.05, 0.165), (0.1, 0.035, 0.008), light))
    elif kind == "tube":
        pieces.append(_cyl("Plastic", (0, 0.04, 0.12), 0.045, 1.7, plastic, (0, math.pi / 2, 0), verts=16))
        for side in (-1, 1):
            pieces.append(_cyl("Plastic", (side * 0.72, 0.14, 0.12), 0.032, 0.22, plastic, verts=12))
            pieces.extend(_shackle(chrome, side * 0.48, -0.02, 0.16))
        pieces.extend(_bolts(chrome, 0.16, 0.12, [-0.55, 0.55]))
        pieces.append(_cyl("PlasticLOD", (0, 0.04, 0.12), 0.05, 1.7, plastic, (0, math.pi / 2, 0), verts=8))
    elif kind == "winch":
        plate = _cube("Plastic", (0, 0.08, 0.1), (1.8, 0.28, 0.14), plastic)
        drum = _cyl("Chrome", (0, 0.1, 0.14), 0.07, 0.34, chrome, (0, math.pi / 2, 0), verts=24)
        # Roller fairlead: four bars around an open slot, not a solid plug.
        pieces.extend(
            [
                plate,
                drum,
                _cube("Chrome", (0, 0.13, 0.185), (0.18, 0.016, 0.02), chrome),
                _cube("Chrome", (0, 0.03, 0.185), (0.18, 0.016, 0.02), chrome),
                _cube("Chrome", (-0.09, 0.08, 0.185), (0.016, 0.1, 0.02), chrome),
                _cube("Chrome", (0.09, 0.08, 0.185), (0.016, 0.1, 0.02), chrome),
                _cyl("Chrome", (0, 0.08, 0.22), 0.008, 0.08, chrome, (math.pi / 2, 0, 0), verts=8),
                _torus("Chrome", (0, 0.04, 0.26), 0.028, 0.007, chrome, rot=(math.pi / 2, 0, 0), major_seg=14, minor_seg=6),
            ]
        )
        for side in (-1, 1):
            pieces.append(_cube("Plastic", (side * 0.55, 0.1, 0.16), (0.14, 0.07, 0.025), plastic))
            pieces.append(_cube("Light", (side * 0.55, 0.1, 0.178), (0.09, 0.04, 0.008), light))
        pieces.extend(_bolts(chrome, 0.17, 0.2, [-0.7, -0.4, 0.4, 0.7]))
        pieces.extend(_bolts(chrome, 0.17, -0.02, [-0.7, 0.7]))
        pieces.extend(_shackle(chrome, -0.32, -0.04, 0.18))
        pieces.extend(_shackle(chrome, 0.32, -0.04, 0.18))
        pieces.append(_cube("PlasticLOD", (0, 0.08, 0.1), (1.8, 0.28, 0.16), plastic))
    else:
        pieces.append(_cyl("Plastic", (0, 0.02, 0.22), 0.04, 1.55, plastic, (0, math.pi / 2, 0), verts=14))
        for side in (-1, 1):
            pieces.append(_cyl("Plastic", (side * 0.72, 0.14, 0.2), 0.03, 0.26, plastic, verts=10))
            pieces.append(_cube("Plastic", (side * 0.48, 0.1, 0.28), (0.14, 0.08, 0.03), plastic))
            pieces.append(_cube("Light", (side * 0.48, 0.1, 0.3), (0.09, 0.045, 0.01), light))
            pieces.extend(_shackle(chrome, side * 0.28, -0.04, 0.24))
        pieces.append(_cube("Plastic", (0, -0.06, 0.2), (1.15, 0.03, 0.28), plastic))
        pieces.extend(_bolts(chrome, 0.28, 0.08, [-0.4, 0, 0.4]))
        pieces.append(_cyl("PlasticLOD", (0, 0.02, 0.2), 0.045, 1.55, plastic, (0, math.pi / 2, 0), verts=8))
    return pieces

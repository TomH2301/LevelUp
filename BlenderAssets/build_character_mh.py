"""Builds a clean 2-axis (Fat / Muscular) character from MPFB2 (MakeHuman
Plugin For Blender) instead of CharMorph, and exports THREE SEPARATE,
non-skinned static meshes (Basis/Fat/Muscular) per body part — same
architecture as the original CharMorph-based build_character.py (see that
file's docstring for why: Blender's USD exporter always wraps shape-keyed
meshes in a UsdSkel Skeleton, which SceneKit's importer misinterprets).

Why MPFB2 instead of CharMorph: CharMorph/MB-Lab's base characters ship with
ZERO bundled assets (no eyes, no hair, no clothes — char.assets == {}), and
their own cosmetic "Tone" morph is too subtle to read as visible muscle.
MPFB2 has genuine built-in "weight"/"muscle" macro sliders (community-tuned
MakeHuman targets, not something we hand-rolled from mass/tone deltas), and
exposes precise named vertex groups (genitals, scalp, nipple, ears, ...)
instead of CharMorph's z-range guessing.

Usage:
  blender --background --python build_character_mh.py -- female LevelUp_Female
  blender --background --python build_character_mh.py -- male   LevelUp_Male
"""

import os
import sys
import bpy
import bmesh
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
gender_arg = argv[0] if len(argv) > 0 else "female"
out_base_name = argv[1] if len(argv) > 1 else "character"

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# --- Clear scene ---
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# --- Create base human via MPFB2 ---
# MPFB ships as a Blender Extension (not a legacy addon) and is enabled by
# default once installed, so no addon_enable() call is needed here (unlike
# CharMorph).
bpy.ops.mpfb.create_human()
obj = bpy.data.objects["Human"]
obj.name = "Body"
bpy.context.view_layer.objects.active = obj
obj.select_set(True)

# MPFB adds a "Hide helpers" Mask modifier (vertex group "body", invert=
# False) that hides every vertex NOT in the "body" group at render/evaluate
# time — this is what normally keeps helper-skirt/helper-tights/helper-eye/
# helper-genital/teeth/tongue invisible. We need a STABLE vertex count/index
# between obj.data.vertices and the depsgraph-evaluated mesh (used below to
# read Fat/Muscular positions), so instead of relying on the live modifier
# we bake its effect in ourselves: delete every non-"body" vertex for real,
# once, right after reading the landmarks we still need from them (eye
# socket centers) below. This also turned out to be necessary, not just
# convenient — removing only the modifier without deleting the helper
# vertices left helper-skirt/helper-tights visible as a floor-length "dress"
# in the export, since static-mesh export has no modifier stack to hide them.
for mod in list(obj.modifiers):
    if mod.type == "MASK":
        obj.modifiers.remove(mod)

scene = bpy.context.scene


def set_macro(name, value):
    setattr(scene, f"mpfb_macropanel_{name}", value)


# Neutral baseline: gender from CLI arg, everything else centered. Weight/
# muscle start at the SAME 0.5 "average" MPFB default — Fat and Muscular
# shapes below move ONE of these to the max while holding the other at this
# same baseline, so the two axes stay independent (mirrors the additive
# Fat/Muscular split from the CharMorph pipeline).
set_macro("gender", 0.0 if gender_arg == "female" else 1.0)
set_macro("age", 0.5)
set_macro("weight", 0.5)
set_macro("muscle", 0.5)
set_macro("height", 0.5)
set_macro("proportions", 0.5)
set_macro("cupsize", 0.5)
set_macro("firmness", 0.5)
bpy.context.view_layer.update()


def vgroup_indices(obj, name):
    vg = obj.vertex_groups.get(name)
    if not vg:
        return set()
    return {v.index for v in obj.data.vertices if any(g.group == vg.index for g in v.groups)}


def vgroup_center(obj, name):
    idx = vgroup_indices(obj, name)
    if not idx:
        return None
    coords = [obj.matrix_world @ obj.data.vertices[i].co for i in idx]
    return sum(coords, mathutils.Vector()) / len(coords)


# --- Capture eye-socket landmarks before we strip helper geometry ---
# helper-l-eye / helper-r-eye are NOT part of the "body" group (0 overlap,
# confirmed by inspection) and are about to be deleted below. We only need
# their world-space CENTER to place our own eyeball spheres later, so grab
# that now while the vertices still exist.
eye_centers = {side: vgroup_center(obj, f"helper-{side}-eye") for side in ("l", "r")}
eye_radii = {}
for side in ("l", "r"):
    idx = vgroup_indices(obj, f"helper-{side}-eye")
    coords = [obj.matrix_world @ obj.data.vertices[i].co for i in idx]
    eye_radii[side] = max((c - eye_centers[side]).length for c in coords) * 0.85 if coords else 0.012

# --- Strip to the "body" vertex group only ---
# This is what the "Hide helpers" Mask modifier normally does live (see
# above) — we bake it permanently so Fat/Muscular/Basis all share one
# stable, modifier-free topology, AND so helper-skirt/helper-tights/teeth/
# tongue/genitals never reach the export. Confirmed: "genitals" modeling
# lives entirely in "helper-genital", which has ZERO overlap with "body" —
# so this single step also satisfies "don't model genitals at all" without
# a separate smoothing pass.
body_idx = vgroup_indices(obj, "body")
bm = bmesh.new()
bm.from_mesh(obj.data)
bm.verts.ensure_lookup_table()
verts_to_delete = [v for v in bm.verts if v.index not in body_idx]
bmesh.ops.delete(bm, geom=verts_to_delete, context="VERTS")
bm.to_mesh(obj.data)
bm.free()
obj.data.update()

print(f"Created {gender_arg} human, {len(obj.data.vertices)} vertices after stripping to body group")


def bake_named_shape(result_name, weight, muscle):
    """Sets the macro weight/muscle sliders, evaluates the mesh through the
    depsgraph (MPFB only updates the EVALUATED mesh via shape-key mixing —
    obj.data.vertices stays at rest/Basis state, confirmed by direct test),
    and bakes the resulting absolute positions into a new shape key on the
    original object. This mirrors CharMorph pipeline's bake_from_deltas: by
    the time we reach export, Basis/Fat/Muscular are plain named shape keys
    with no further live dependency on MPFB."""
    set_macro("weight", weight)
    set_macro("muscle", muscle)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    eval_mesh = eval_obj.data
    if len(eval_mesh.vertices) != len(obj.data.vertices):
        raise RuntimeError(f"Evaluated vertex count {len(eval_mesh.vertices)} != base {len(obj.data.vertices)}")
    coords = [0.0] * (len(eval_mesh.vertices) * 3)
    eval_mesh.vertices.foreach_get("co", coords)

    if obj.data.shape_keys is None:
        obj.shape_key_add(name="Basis", from_mix=False)
    new_key = obj.shape_key_add(name=result_name, from_mix=False)
    new_key.data.foreach_set("co", coords)
    new_key.value = 0.0
    print(f"{result_name}: baked from weight={weight} muscle={muscle}")
    return new_key


bake_named_shape("Basis", weight=0.5, muscle=0.5)
bake_named_shape("Fat", weight=1.0, muscle=0.5)
bake_named_shape("Muscular", weight=0.5, muscle=1.0)

# Reset live sliders back to baseline now that Basis/Fat/Muscular are frozen
# into independent shape keys — otherwise the "Basis" shape key (which
# Blender always keeps at the rest pose) would visually disagree with
# obj.data.vertices still sitting at whatever the last macro state was.
set_macro("weight", 0.5)
set_macro("muscle", 0.5)
bpy.context.view_layer.update()

print("Shape keys:", [k.name for k in obj.data.shape_keys.key_blocks])


import struct


def export_mesh_and_morphs_binary(source_obj, out_prefix):
    """Replaces the old per-shape-USDZ export. Root-cause fix for the
    device bug where the avatar's head/geometry exploded once real weights
    were applied: loading Basis/Fat/Muscular as THREE SEPARATE .usdz files
    relied on Apple's USD importer independently re-triangulating/
    re-indexing each file IDENTICALLY so that vertex N in one file still
    means vertex N in another — unverifiable from our side, and evidently
    not reliable once per-vertex smooth normals (which differ between
    Fat/Muscular/Basis) started influencing the importer's internal vertex
    splitting.

    Instead we export ONE small custom binary format that Swift parses
    directly into SCNGeometry/SCNGeometrySource ourselves — no USD import
    involved for body parts at all, so vertex correspondence is guaranteed
    by construction rather than hoped for. Materials aren't needed in this
    format: AvatarView always overrides them with a solid SCNMaterial.

    <prefix>_mesh.bin:   vertexCount(u32) triangleCount(u32)
                         positions[vertexCount*3] f32 (Basis)
                         normals[vertexCount*3] f32 (Basis)
                         triangleIndices[triangleCount*3] u32
    <prefix>_<Shape>.bin: positions[vertexCount*3] f32 (same vertex order)
    """
    mesh = source_obj.data
    vcount = len(mesh.vertices)

    mesh.calc_loop_triangles()
    triangles = [idx for tri in mesh.loop_triangles for idx in tri.vertices]
    tcount = len(triangles) // 3

    def shape_positions(key_name):
        kb = mesh.shape_keys.key_blocks[key_name]
        coords = [0.0] * (vcount * 3)
        kb.data.foreach_get("co", coords)
        return coords

    basis_positions = shape_positions("Basis")

    # Temporarily move the mesh to the Basis pose so per-vertex normals are
    # computed for the Basis silhouette (shape keys don't affect
    # vertex.normal directly; we read it off obj.data.vertices, which
    # always holds Basis/rest positions, see bake_named_shape's docstring —
    # so no actual pose switch is needed here, Basis IS obj.data.vertices).
    normals = [0.0] * (vcount * 3)
    mesh.vertices.foreach_get("normal", normals)

    with open(f"{out_prefix}_mesh.bin", "wb") as f:
        f.write(struct.pack("<II", vcount, tcount))
        f.write(struct.pack(f"<{len(basis_positions)}f", *basis_positions))
        f.write(struct.pack(f"<{len(normals)}f", *normals))
        f.write(struct.pack(f"<{len(triangles)}I", *triangles))
    print(f"Exported mesh: {out_prefix}_mesh.bin ({vcount} verts, {tcount} tris)")

    for shape_name in ("Fat", "Muscular"):
        if shape_name not in mesh.shape_keys.key_blocks:
            continue
        positions = shape_positions(shape_name)
        with open(f"{out_prefix}_{shape_name}.bin", "wb") as f:
            f.write(struct.pack(f"<{len(positions)}f", *positions))
        print(f"Exported morph: {out_prefix}_{shape_name}.bin")


def extract_region_object(source_obj, name, vertex_group_names, expand_rings, offset_distance, color):
    """Extracts the union of one or more named vertex groups (e.g. MPFB's
    own 'scalp' group) into a new, separate object carrying all of
    source_obj's CURRENT shape keys (Basis/Fat/Muscular) — unlike the
    CharMorph pipeline's z-range heuristic, MPFB gives us precise, purpose-
    built vertex groups so no height-fraction guessing is needed.

    Offsets every copied vertex along its own Basis-state normal so the
    patch sits slightly above the skin (avoids z-fighting)."""
    keep_indices = set()
    for vg_name in vertex_group_names:
        keep_indices |= vgroup_indices(source_obj, vg_name)

    dup = source_obj.copy()
    dup.data = source_obj.data.copy()
    dup.name = name
    bpy.context.collection.objects.link(dup)

    if expand_rings:
        bpy.context.view_layer.objects.active = dup
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        for v in dup.data.vertices:
            v.select = v.index in keep_indices
        bpy.ops.object.mode_set(mode="EDIT")
        for _ in range(expand_rings):
            bpy.ops.mesh.select_more()
        bpy.ops.object.mode_set(mode="OBJECT")
        keep_indices = {v.index for v in dup.data.vertices if v.select}

    # Pure bmesh, no mode_set/operators for the deletion itself: avoids the
    # reproducible bug (see build_character.py) where bpy.ops.mesh.delete()
    # in EDIT mode, in --background scripts, sometimes affected the WRONG
    # object.
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    bm.verts.ensure_lookup_table()
    verts_to_delete = [v for v in bm.verts if v.index not in keep_indices]
    bmesh.ops.delete(bm, geom=verts_to_delete, context="VERTS")
    bm.to_mesh(dup.data)
    bm.free()
    dup.data.update()

    normals = [tuple(v.normal) for v in dup.data.vertices]
    for kb in dup.data.shape_keys.key_blocks:
        coords = [0.0] * (len(dup.data.vertices) * 3)
        kb.data.foreach_get("co", coords)
        import numpy as np
        coords = np.array(coords).reshape(-1, 3)
        for i, n in enumerate(normals):
            coords[i] += np.array(n) * offset_distance
        kb.data.foreach_set("co", coords.reshape(-1))

    mat = bpy.data.materials.new(f"{name}_mat")
    mat.use_nodes = False
    mat.diffuse_color = color
    dup.data.materials.clear()
    dup.data.materials.append(mat)

    print(f"{name}: {len(dup.data.vertices)} vertices extracted (groups {vertex_group_names})")
    return dup


UNDERWEAR_COLOR = (0.08, 0.08, 0.1, 1.0)
HAIR_COLOR = (0.15, 0.09, 0.06, 1.0)
BRA_COLOR = (0.08, 0.08, 0.1, 1.0)

# Underwear (briefs): MPFB has no dedicated "hips/underwear" vertex group,
# so fall back to a z-range band similar to the CharMorph pipeline, derived
# from this mesh's own bounding box (not a hardcoded fraction tuned for a
# different topology).
basis_coords_world = [obj.matrix_world @ v.co for v in obj.data.vertices]
zs = [c.z for c in basis_coords_world]
zmin, zmax = min(zs), max(zs)
height_total = zmax - zmin


xs = [c.x for c in basis_coords_world]
torso_half_width = max(abs(min(xs)), abs(max(xs))) * 0.55


def z_band_group(z_frac_min, z_frac_max):
    """Z-height band, ALSO constrained to stay near the body's central X
    axis. Z-only filtering looked right for a standing figure but silently
    also captured the outstretched T-pose hands/wrists, which sit at
    roughly chest height — visible as a symmetric "donut" artifact at both
    wrists once Fat/Muscular made the mismatched ring noticeable. The X
    cutoff is 55% of the mesh's furthest (fully-extended-arm) half-width,
    comfortably covering the torso while excluding the arms."""
    lo = zmin + height_total * z_frac_min
    hi = zmin + height_total * z_frac_max
    return {i for i, c in enumerate(basis_coords_world)
            if lo <= c.z <= hi and abs(c.x) <= torso_half_width}


# extract_region_object expects vertex GROUP names, so temporarily create
# throwaway vertex groups for the z-band selections to reuse the same
# extraction code path as the named-group regions (scalp, nipple).
def make_temp_vgroup(name, indices):
    vg = obj.vertex_groups.new(name=name)
    for i in indices:
        vg.add([i], 1.0, "ADD")
    return vg


make_temp_vgroup("_tmp_underwear", z_band_group(0.42, 0.58))
underwear_obj = extract_region_object(obj, "Underwear", ["_tmp_underwear"], expand_rings=0,
                                       offset_distance=0.01, color=UNDERWEAR_COLOR)

hair_obj = extract_region_object(obj, "Hair", ["scalp"], expand_rings=1,
                                  offset_distance=0.01, color=HAIR_COLOR)

if gender_arg == "female":
    nipple_center = vgroup_center(obj, "nipple")
    bra_z_frac = (nipple_center.z - zmin) / height_total
    make_temp_vgroup("_tmp_bra", z_band_group(bra_z_frac - 0.09, bra_z_frac + 0.07))
    bra_obj = extract_region_object(obj, "Bra", ["_tmp_bra"], expand_rings=0,
                                     offset_distance=0.012, color=BRA_COLOR)
else:
    bra_obj = None

for vg_name in ("_tmp_underwear", "_tmp_bra"):
    vg = obj.vertex_groups.get(vg_name)
    if vg:
        obj.vertex_groups.remove(vg)


def add_eyeball(side, center, radius):
    """Builds a simple two-sphere eyeball (white sclera + darker iris, no
    textures) positioned at the captured helper-l-eye / helper-r-eye socket
    center (captured before stripping to the "body" group above, since that
    helper geometry no longer exists on `obj` by this point). MPFB has no
    bundled eyeball mesh asset (only a shader-only "procedural eyes" node
    tree that cannot survive USD export), and CharMorph had the same gap —
    so we build the simplest thing that fixes the hollow-socket look and
    reliably survives USDZ export, rather than relying on either tool's
    defaults."""
    if center is None:
        print(f"WARNING: no helper-{side}-eye group found, skipping eyeball")
        return None

    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=center, segments=16, ring_count=10)
    sclera = bpy.context.active_object
    sclera.name = f"Eye_{side}_sclera"
    mat = bpy.data.materials.new(f"Eye_{side}_sclera_mat")
    mat.use_nodes = False
    mat.diffuse_color = (0.92, 0.92, 0.88, 1.0)
    sclera.data.materials.append(mat)

    # Offset chosen so the iris sphere clearly pokes THROUGH the sclera
    # surface (0.68 + 0.42 > 1.0 sclera radii) instead of sitting just
    # beneath it — a near-tangent overlap caused visible z-fighting/moire
    # banding on the sclera in the first version of this.
    iris_center = center + mathutils.Vector((0, -radius * 0.68, 0))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius * 0.42, location=iris_center, segments=12, ring_count=8)
    iris = bpy.context.active_object
    iris.name = f"Eye_{side}_iris"
    mat2 = bpy.data.materials.new(f"Eye_{side}_iris_mat")
    mat2.use_nodes = False
    mat2.diffuse_color = (0.25, 0.16, 0.09, 1.0)
    iris.data.materials.append(mat2)

    return sclera, iris


eyes = []
for side in ("l", "r"):
    result = add_eyeball(side, eye_centers[side], eye_radii[side])
    if result:
        eyes.extend(result)

# --- Export: one binary mesh + morph-target-position files per body part ---
base_path = os.path.join(OUT_DIR, out_base_name)
export_mesh_and_morphs_binary(obj, f"{base_path}_Body")
export_mesh_and_morphs_binary(underwear_obj, f"{base_path}_Underwear")
export_mesh_and_morphs_binary(hair_obj, f"{base_path}_Hair")
if bra_obj:
    export_mesh_and_morphs_binary(bra_obj, f"{base_path}_Bra")

# Eyeballs don't morph with Fat/Muscular (eye size is constant regardless of
# body composition) — export once, no shape-key variants.
#
# Sanity-checked: a stray default "Cube" object was showing up in this
# export (visible as a small cube near the feet in combined renders) even
# though only `eyes` was selected — name-filtering the whole scene instead
# of trusting the `eyes` list is a defensive fix against whatever creates
# it (suspected: MPFB's rig/joint-cube helper objects, see the "JointCubes"
# vertex group name).
if eyes:
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith("Eye_"):
            o.select_set(True)
    bpy.context.view_layer.objects.active = eyes[0]
    bpy.ops.wm.usd_export(filepath=f"{base_path}_Eyes.usdz", selected_objects_only=True)
    print(f"Exported Eyes: {base_path}_Eyes.usdz")

print("Done.")

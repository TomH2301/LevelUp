"""Builds a clean 2-axis (Fat / Muscular) character from a CharMorph base
model and exports THREE SEPARATE, non-skinned static meshes (Basis/Fat/
Muscular) instead of one shape-keyed/skinned USDZ.

Why: Blender's USD exporter always wraps shape-key blend shapes in a
UsdSkel Skeleton+SkelAnimation, even for a mesh with no actual armature.
Apple's SceneKit USD importer appears to misinterpret that skeletal
binding, badly distorting the mesh at runtime (confirmed: Blender itself
renders the shape-keyed export correctly, but SceneKit renders it warped).
Exporting plain static meshes instead avoids UsdSkel entirely; the
blend-shape morphing is instead built in Swift from the three separate
vertex-position sets (SCNMorpher targets constructed programmatically).

Usage:
  blender --background --python build_character.py -- mb_female LevelUp_Female
  blender --background --python build_character.py -- mb_male   LevelUp_Male
"""

import os
import re
import sys
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
base_model = argv[0] if len(argv) > 0 else "mb_female"
out_base_name = argv[1] if len(argv) > 1 else "character"

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# --- Clear scene ---
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# --- Import base character with real shape keys ---
bpy.ops.preferences.addon_enable(module="CharMorph")

ui = bpy.context.window_manager.charmorph_ui
ui.base_model = base_model
ui.use_sk = True
ui.import_morphs = True
ui.import_expressions = False
bpy.ops.charmorph.import_char()

obj = bpy.context.view_layer.objects.active
print(f"Imported base character: {obj.name}")

# --- Remove any extra objects (underwear/assets) - keep only the body mesh ---
for o in list(bpy.context.scene.objects):
    if o is not obj and o.type == "MESH":
        print(f"Removing extra object: {o.name}")
        bpy.data.objects.remove(o, do_unlink=True)

# NOTE: we deliberately do NOT use CharMorph's live morpher (prop_set +
# shape_key_add(from_mix=True)) to build the combined Fat/Muscular shapes.
# That path was verified broken: shape_key_add(from_mix=True) bakes garbage
# (badly collapsed geometry) when run via `blender --background`, regardless
# of which morph values are actually set — confirmed by baking with zero
# morphs active and still getting a collapsed result. The individual RAW
# per-region shape keys CharMorph imports are correct (verified directly),
# so we read their vertex data ourselves and sum the deltas in numpy,
# bypassing from_mix entirely.


def mesh_coords(key_name):
    kb = obj.data.shape_keys.key_blocks[key_name]
    coords = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    kb.data.foreach_get("co", coords)
    return coords.reshape(-1, 3)


basis_coords = mesh_coords("Basis")
all_key_names = [kb.name for kb in obj.data.shape_keys.key_blocks]

# Simple per-region 2-axis combo corner keys look like:
#   L2__<Region>Mass-<Region>Tone_<mass max/min>-<tone max/min>
# Exactly one "Mass" and one "Tone" in the name excludes the more complex
# 4-axis combos (e.g. Torso_BreastMass-BreastTone-Mass-Tone_*) which we
# deliberately skip for this simplified 2-axis avatar.
combo_pattern = re.compile(r"^L2__.*Mass.*Tone.*_(max|min)-(max|min)$")


def region_corner_keys(mass_token, tone_token):
    suffix = f"_{mass_token}-{tone_token}"
    return [
        name for name in all_key_names
        if combo_pattern.match(name) and name.endswith(suffix) and name.count("Mass") == 1 and name.count("Tone") == 1
    ]


def bake_from_deltas(result_name, corner_keys, scale):
    total_delta = np.zeros_like(basis_coords)
    for key_name in corner_keys:
        total_delta += (mesh_coords(key_name) - basis_coords) * scale
    final_coords = basis_coords + total_delta
    new_key = obj.shape_key_add(name=result_name, from_mix=False)
    new_key.data.foreach_set("co", final_coords.reshape(-1))
    new_key.value = 0.0
    print(f"{result_name}: summed {len(corner_keys)} region deltas, scale={scale}")
    return new_key


# "Fat" = high mass, low tone per region. "Muscular" = low mass, high tone.
# Scale < 1 because summing many overlapping regions (e.g. shoulders + arms
# near the armpit) at full weight would still over-compound. Muscular gets a
# higher scale than Fat — CharMorph's "Tone" corner alone reads as fairly
# subtle at 0.5 (Phase 7.10: tune geometry strength before reaching for
# texture-based definition).
FAT_DELTA_SCALE = 0.5
MUSCULAR_DELTA_SCALE = 0.75

fat_keys = region_corner_keys("max", "min")
muscular_keys = region_corner_keys("min", "max")
print(f"Fat corner keys ({len(fat_keys)}): {fat_keys}")
print(f"Muscular corner keys ({len(muscular_keys)}): {muscular_keys}")

bake_from_deltas("Fat", fat_keys, FAT_DELTA_SCALE)
bake_from_deltas("Muscular", muscular_keys, MUSCULAR_DELTA_SCALE)

# Phase 7.11: one face-shape axis (face width), driven at runtime by Vision
# face-landmark ratios from the user's calibration photo — not by KFA/Kraft
# like Fat/Muscular, so it's baked once here and applied as a static weight
# from AvatarProfile.faceWidthWeight (see AvatarView.swift). Deliberately
# scoped to ONE axis for now rather than CharMorph's dozen+ head sliders —
# proves the mechanism; more axes can be added the same way later.
FACE_KEY = "L2__Head_SizeX_max"
if FACE_KEY in all_key_names:
    bake_from_deltas("FaceWide", [FACE_KEY], 1.0)
else:
    print(f"WARNING: {FACE_KEY} not found, skipping FaceWide axis")

# --- Strip down to just Basis / Fat / Muscular (/ FaceWide) ---
keep = {"Basis", "Fat", "Muscular", "FaceWide"}
sk = obj.data.shape_keys
to_remove = [k for k in sk.key_blocks if k.name not in keep]
print(f"Removing {len(to_remove)} raw morph shape keys, keeping {keep}")
for k in to_remove:
    obj.shape_key_remove(k)

print("Final shape keys:", [k.name for k in obj.data.shape_keys.key_blocks])

# --- Strip to one material, one UV set, no extra mask attributes ---
# (SceneKit's USD importer is far less complete than Blender's/Pixar's reference
# implementation; CharMorph exports ~10 materials + many per-ethnicity mask
# primvars that may be too much for it to parse reliably.)
print("Attributes BEFORE cleanup:", [(a.name, a.data_type, a.domain) for a in obj.data.attributes])
print("UV layers BEFORE cleanup:", [uv.name for uv in obj.data.uv_layers])

first_material = obj.data.materials[0] if obj.data.materials else None
obj.data.materials.clear()
if first_material:
    obj.data.materials.append(first_material)

while len(obj.data.uv_layers) > 1:
    obj.data.uv_layers.remove(obj.data.uv_layers[-1])

# Nur bekannte CharMorph-Masken-/Textur-Zusatzattribute entfernen, statt
# pauschal alles außer einer festen Namensliste zu löschen (hat zuvor
# versehentlich Normalen-/Topologiedaten mit erwischt und zu kaputter
# Schattierung geführt).
junk_prefixes = ("hair_", "Eyes_", "L2_", "L1_", "charmorph_")
for attr in list(obj.data.attributes):
    if attr.name.startswith(junk_prefixes):
        try:
            obj.data.attributes.remove(attr)
        except RuntimeError:
            pass

print("Materials after cleanup:", [m.name for m in obj.data.materials])
print("UV layers after cleanup:", [uv.name for uv in obj.data.uv_layers])
print("Attributes after cleanup:", [a.name for a in obj.data.attributes])


def extract_region_object(source_obj, name, z_frac_min, z_frac_max, offset_distance, color):
    """Extracts a height-range band of source_obj's vertices — across ALL its
    current shape keys (Basis/Fat/Muscular) — into a new, separate object.
    Used for simple "painted-on" underwear/hair, since CharMorph ships no
    clothing/hair assets for mb_female/mb_male (verified: char.assets == {}).

    Offsets every copied vertex along its own Basis-state normal, so the
    patch sits slightly above the skin (avoids z-fighting) regardless of
    which side of the body it's on.
    """
    import bmesh

    zs = basis_coords[:, 2]
    zmin, zmax = float(zs.min()), float(zs.max())
    height = zmax - zmin
    z_lo = zmin + height * z_frac_min
    z_hi = zmin + height * z_frac_max

    keep_indices = {i for i in range(len(basis_coords)) if z_lo <= basis_coords[i][2] <= z_hi}

    dup = source_obj.copy()
    dup.data = source_obj.data.copy()
    dup.name = name
    bpy.context.collection.objects.link(dup)

    # Pure bmesh, no mode_set/operators: avoids a reproducible bug where
    # bpy.ops.mesh.delete() in EDIT mode, in --background scripts, sometimes
    # affected the WRONG object (source_obj lost all its vertices for the
    # "mb_male" character specifically, even though it was never made active).
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    bm.verts.ensure_lookup_table()
    verts_to_delete = [v for v in bm.verts if v.index not in keep_indices]
    bmesh.ops.delete(bm, geom=verts_to_delete, context="VERTS")
    bm.to_mesh(dup.data)
    bm.free()
    dup.data.update()

    indices = sorted(keep_indices)
    normals = [tuple(v.normal) for v in dup.data.vertices]
    for kb in dup.data.shape_keys.key_blocks:
        coords = np.empty(len(dup.data.vertices) * 3, dtype=np.float64)
        kb.data.foreach_get("co", coords)
        coords = coords.reshape(-1, 3)
        for i, n in enumerate(normals):
            coords[i] += np.array(n) * offset_distance
        kb.data.foreach_set("co", coords.reshape(-1))

    mat = bpy.data.materials.new(f"{name}_mat")
    mat.use_nodes = False
    mat.diffuse_color = color
    dup.data.materials.clear()
    dup.data.materials.append(mat)

    print(f"{name}: {len(indices)} vertices extracted (z {z_frac_min:.2f}-{z_frac_max:.2f})")
    return dup


# mb_female/mb_male ship with zero bundled assets (char.assets == {}), so
# underwear and hair are built here as offset skin patches — they inherit
# Basis/Fat/Muscular automatically since they're literal copies of body
# vertices at this point in the pipeline.
UNDERWEAR_COLOR = (0.08, 0.08, 0.1, 1.0)
HAIR_COLOR = (0.15, 0.09, 0.06, 1.0)

underwear_obj = extract_region_object(obj, "Underwear", 0.42, 0.58, 0.01, UNDERWEAR_COLOR)
hair_obj = extract_region_object(obj, "Hair", 0.94, 1.0, 0.01, HAIR_COLOR)


def export_shape_as_static(source_obj, key_name, out_path):
    """Bakes one shape key's absolute vertex positions into a plain,
    non-skinned mesh and exports it on its own — no Skeleton, no shape keys."""
    new_mesh = source_obj.data.copy()
    new_obj = bpy.data.objects.new(f"{source_obj.name}_{key_name}", new_mesh)
    bpy.context.collection.objects.link(new_obj)

    key_block = new_mesh.shape_keys.key_blocks[key_name]
    coords = [0.0] * (len(new_mesh.vertices) * 3)
    key_block.data.foreach_get("co", coords)

    # Shape keys MUST be removed before writing to raw vertex positions —
    # otherwise Blender's shape-key evaluation overwrites them again on removal.
    for kb in list(new_mesh.shape_keys.key_blocks):
        new_obj.shape_key_remove(kb)

    new_mesh.vertices.foreach_set("co", coords)
    new_mesh.update()

    bpy.ops.object.select_all(action="DESELECT")
    new_obj.select_set(True)
    bpy.context.view_layer.objects.active = new_obj

    bpy.ops.wm.usd_export(filepath=out_path, selected_objects_only=True)
    print(f"Exported {key_name}: {out_path}")

    bpy.data.objects.remove(new_obj, do_unlink=True)
    bpy.data.meshes.remove(new_mesh, do_unlink=True)


# --- Export: three separate static, non-skinned meshes per body part ---
base_path = os.path.join(OUT_DIR, out_base_name)
for shape_name in ("Basis", "Fat", "Muscular"):
    export_shape_as_static(obj, shape_name, f"{base_path}_{shape_name}.usdz")
    export_shape_as_static(underwear_obj, shape_name, f"{base_path}_Underwear_{shape_name}.usdz")
    export_shape_as_static(hair_obj, shape_name, f"{base_path}_Hair_{shape_name}.usdz")

if "FaceWide" in [k.name for k in obj.data.shape_keys.key_blocks]:
    export_shape_as_static(obj, "FaceWide", f"{base_path}_FaceWide.usdz")

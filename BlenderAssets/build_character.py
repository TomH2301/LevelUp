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
# near the armpit) at full weight would still over-compound.
DELTA_SCALE = 0.5

fat_keys = region_corner_keys("max", "min")
muscular_keys = region_corner_keys("min", "max")
print(f"Fat corner keys ({len(fat_keys)}): {fat_keys}")
print(f"Muscular corner keys ({len(muscular_keys)}): {muscular_keys}")

bake_from_deltas("Fat", fat_keys, DELTA_SCALE)
bake_from_deltas("Muscular", muscular_keys, DELTA_SCALE)

# --- Strip down to just Basis / Fat / Muscular ---
keep = {"Basis", "Fat", "Muscular"}
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


# --- Export: three separate static, non-skinned meshes ---
base_path = os.path.join(OUT_DIR, out_base_name)
for shape_name in ("Basis", "Fat", "Muscular"):
    export_shape_as_static(obj, shape_name, f"{base_path}_{shape_name}.usdz")

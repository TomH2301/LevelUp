"""Builds a clean 2-axis (Fat / Muscular) blend-shape character from a
CharMorph base model and exports it as USDZ for SceneKit.

Usage:
  blender --background --python build_character.py -- mb_female LevelUp_Female.usdz
  blender --background --python build_character.py -- mb_male   LevelUp_Male.usdz
"""

import os
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
base_model = argv[0] if len(argv) > 0 else "mb_female"
out_name = argv[1] if len(argv) > 1 else "character.usdz"

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

from CharMorph.lib import morpher_cores
m = morpher_cores.get(obj)

all_names = list(m.morphs_l2_dict.keys())
mass_names = [n for n in all_names if n.endswith("Mass")]
tone_names = [n for n in all_names if n.endswith("Tone")]
print(f"Mass morphs ({len(mass_names)}): {mass_names}")
print(f"Tone morphs ({len(tone_names)}): {tone_names}")


def reset_all():
    for n in all_names:
        m.prop_set(n, 0.0)


def bake(name, props_to_max):
    reset_all()
    for n in props_to_max:
        m.prop_set(n, 1.0)
    new_key = obj.shape_key_add(name=name, from_mix=True)
    new_key.value = 0.0
    return new_key


bake("Fat", mass_names)
bake("Muscular", tone_names)
reset_all()

# --- Strip down to just Basis / Fat / Muscular ---
keep = {"Basis", "Fat", "Muscular"}
sk = obj.data.shape_keys
to_remove = [k for k in sk.key_blocks if k.name not in keep]
print(f"Removing {len(to_remove)} raw morph shape keys, keeping {keep}")
for k in to_remove:
    obj.shape_key_remove(k)

print("Final shape keys:", [k.name for k in obj.data.shape_keys.key_blocks])

# --- Export ---
out_path = os.path.join(OUT_DIR, out_name)
bpy.ops.wm.usd_export(filepath=out_path, selected_objects_only=False)
print(f"Exported: {out_path}")

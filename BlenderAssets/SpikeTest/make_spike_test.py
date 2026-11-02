"""Headless Blender script: creates a sphere with one shape key ('Morph')
and exports it as both .dae (Collada) and .usdz (USD) to validate that
SceneKit can import morph targets from either format.

Run with:
  blender --background --python make_spike_test.py
"""

import os
import bpy

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# --- Clear default scene ---
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# --- Create base sphere ---
bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(0, 0, 0))
obj = bpy.context.active_object
obj.name = "MorphTestSphere"

# --- Shape keys: Basis + Morph ---
obj.shape_key_add(name="Basis", from_mix=False)
morph_key = obj.shape_key_add(name="Morph", from_mix=False)

# Deform the Morph key: stretch vertically, squeeze horizontally
# (so a visible difference is obvious at weight 1.0 vs 0.0)
for vertex in morph_key.data:
    vertex.co.z *= 1.8
    vertex.co.x *= 0.6
    vertex.co.y *= 0.6

# Reset the active shape key value so the exported "rest" mesh is the Basis form
obj.active_shape_key_index = 0

# --- Export: USDZ ---
usdz_path = os.path.join(OUT_DIR, "morphtest.usdz")
bpy.ops.wm.usd_export(filepath=usdz_path, selected_objects_only=False)
print(f"Exported USDZ: {usdz_path}")

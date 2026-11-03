"""Renders body + underwear + hair together for one shape state, to check
how the three parts line up — in Blender, in seconds, before touching iOS.

Usage:
  blender --background --python render_combined_check.py -- <base_path> <Basis|Fat|Muscular> <output.png>
  e.g. ... -- "...\LevelUp_Female" "Basis" "...\check.png"
"""

import sys
import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
base_path = argv[0]
shape = argv[1] if len(argv) > 1 else "Basis"
out_png = argv[2]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

for part in ("", "_Underwear", "_Hair"):
    bpy.ops.wm.usd_import(filepath=f"{base_path}{part}_{shape}.usdz")

print("--- objects in scene ---")
for obj in bpy.context.scene.objects:
    print(f"  {obj.name} ({obj.type}) verts={len(obj.data.vertices) if obj.type == 'MESH' else '-'}")

min_co = [1e9, 1e9, 1e9]
max_co = [-1e9, -1e9, -1e9]
for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    for corner in obj.bound_box:
        wc = obj.matrix_world @ mathutils.Vector(corner)
        for i in range(3):
            min_co[i] = min(min_co[i], wc[i])
            max_co[i] = max(max_co[i], wc[i])

center = [(min_co[i] + max_co[i]) / 2 for i in range(3)]
size = max(max_co[i] - min_co[i] for i in range(3))
print(f"center={center} size={size}")

cam_data = bpy.data.cameras.new("DebugCam")
cam_obj = bpy.data.objects.new("DebugCam", cam_data)
bpy.context.collection.objects.link(cam_obj)
dist = size * 2.2
cam_obj.location = (center[0], center[1] - dist, center[2])
look_dir = mathutils.Vector(center) - mathutils.Vector(cam_obj.location)
cam_obj.rotation_euler = look_dir.to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.camera = cam_obj

bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
bpy.context.scene.display.shading.light = "STUDIO"
bpy.context.scene.display.shading.color_type = "MATERIAL"
bpy.context.scene.render.resolution_x = 900
bpy.context.scene.render.resolution_y = 900
bpy.context.scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print(f"Rendered: {out_png}")

"""Same as render_combined_check.py but for the MakeHuman/MPFB-based
pipeline: body + underwear + hair + (bra for female) + eyes together.

Usage:
  blender --background --python render_combined_check_mh.py -- <base_path> <has_bra 0|1> <Basis|Fat|Muscular> <output.png>
"""

import sys
import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
base_path = argv[0]
has_bra = argv[1] == "1"
shape = argv[2] if len(argv) > 2 else "Basis"
out_png = argv[3]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

parts = ["", "_Underwear", "_Hair"]
if has_bra:
    parts.append("_Bra")
for part in parts:
    bpy.ops.wm.usd_import(filepath=f"{base_path}{part}_{shape}.usdz")
bpy.ops.wm.usd_import(filepath=f"{base_path}_Eyes.usdz")

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

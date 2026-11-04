"""Close-up face render of one exported body .usdz, to judge facial detail/
contours directly — zooms in on the head region instead of framing the
whole body.

Usage:
  blender --background --python render_face_check.py -- <body.usdz> <output.png>
"""

import sys
import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
usdz_path = argv[0]
out_png = argv[1]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

bpy.ops.wm.usd_import(filepath=usdz_path)

mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")

min_co = [1e9, 1e9, 1e9]
max_co = [-1e9, -1e9, -1e9]
for corner in mesh_obj.bound_box:
    wc = mesh_obj.matrix_world @ mathutils.Vector(corner)
    for i in range(3):
        min_co[i] = min(min_co[i], wc[i])
        max_co[i] = max(max_co[i], wc[i])

body_height = max_co[2] - min_co[2]
head_top = max_co[2]
head_center_z = head_top - body_height * 0.05
head_center = mathutils.Vector(((min_co[0] + max_co[0]) / 2, (min_co[1] + max_co[1]) / 2, head_center_z))

cam_data = bpy.data.cameras.new("FaceCam")
cam_obj = bpy.data.objects.new("FaceCam", cam_data)
bpy.context.collection.objects.link(cam_obj)
dist = body_height * 0.28
cam_obj.location = (head_center.x, head_center.y - dist, head_center.z)
look_dir = head_center - mathutils.Vector(cam_obj.location)
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

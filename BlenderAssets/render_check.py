"""Renders an exported USDZ character in Blender to verify geometry/shape-keys
BEFORE pushing to iOS — much faster feedback loop than the CI+AltStore cycle.

Usage:
  blender --background --python render_check.py -- <path-to.usdz> <output.png>
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

mesh_obj = next((o for o in bpy.context.scene.objects if o.type == "MESH"), None)

if mesh_obj is None:
    print("NO MESH OBJECT FOUND AFTER IMPORT")
else:
    print(f"Mesh: {mesh_obj.name}, verts: {len(mesh_obj.data.vertices)}")
    print(f"Shape keys: {[b.name for b in mesh_obj.data.shape_keys.key_blocks] if mesh_obj.data.shape_keys else None}")

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
    print(f"World bounds min={min_co} max={max_co} center={center} size={size}")

    cam_data = bpy.data.cameras.new("DebugCam")
    cam_obj = bpy.data.objects.new("DebugCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    dist = size * 2.5
    cam_obj.location = (center[0], center[1] - dist, center[2])
    look_dir = mathutils.Vector(center) - mathutils.Vector(cam_obj.location)
    cam_obj.rotation_euler = look_dir.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam_obj

    light_data = bpy.data.lights.new("DebugSun", type="SUN")
    light_data.energy = 3
    light_obj = bpy.data.objects.new("DebugSun", light_data)
    bpy.context.collection.objects.link(light_obj)
    light_obj.location = (center[0], center[1] - dist, center[2] + dist)

    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.render.resolution_x = 800
    bpy.context.scene.render.resolution_y = 800
    bpy.context.scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {out_png}")

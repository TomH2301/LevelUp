"""Parses our custom <prefix>_mesh.bin (+ optional <prefix>_<Shape>.bin morph
target) format with plain Python struct unpacking (no Blender-specific
assumptions) and reconstructs+renders it, to verify the binary export is
geometrically correct BEFORE writing the Swift-side parser.

Usage:
  blender --background --python render_binary_check.py -- <prefix> [ShapeName] <output.png>
  e.g. ... -- "...\LevelUp_Female_Body" Fat "...\check.png"
  e.g. ... -- "...\LevelUp_Female_Body" "" "...\check.png"   (Basis)
"""

import sys
import struct
import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
prefix = argv[0]
shape_name = argv[1]
out_png = argv[2]

with open(f"{prefix}_mesh.bin", "rb") as f:
    data = f.read()

offset = 0
vcount, tcount = struct.unpack_from("<II", data, offset)
offset += 8
positions = struct.unpack_from(f"<{vcount*3}f", data, offset)
offset += vcount * 3 * 4
normals = struct.unpack_from(f"<{vcount*3}f", data, offset)
offset += vcount * 3 * 4
indices = struct.unpack_from(f"<{tcount*3}I", data, offset)

print(f"Parsed mesh.bin: {vcount} verts, {tcount} tris")

if shape_name:
    with open(f"{prefix}_{shape_name}.bin", "rb") as f:
        morph_data = f.read()
    morph_positions = struct.unpack_from(f"<{vcount*3}f", morph_data, 0)
    positions = morph_positions
    print(f"Applied morph: {shape_name}")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

mesh = bpy.data.meshes.new("Parsed")
verts = [(positions[i*3], positions[i*3+1], positions[i*3+2]) for i in range(vcount)]
faces = [(indices[i*3], indices[i*3+1], indices[i*3+2]) for i in range(tcount)]
mesh.from_pydata(verts, [], faces)
mesh.update()
for poly in mesh.polygons:
    poly.use_smooth = True

obj = bpy.data.objects.new("Parsed", mesh)
bpy.context.collection.objects.link(obj)

min_co = [1e9, 1e9, 1e9]
max_co = [-1e9, -1e9, -1e9]
for v in mesh.vertices:
    for i in range(3):
        min_co[i] = min(min_co[i], v.co[i])
        max_co[i] = max(max_co[i], v.co[i])
center = [(min_co[i] + max_co[i]) / 2 for i in range(3)]
size = max(max_co[i] - min_co[i] for i in range(3))
print(f"center={center} size={size}")

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
dist = size * 2.2
cam.location = (center[0], center[1] - dist, center[2])
look_dir = mathutils.Vector(center) - mathutils.Vector(cam.location)
cam.rotation_euler = look_dir.to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.camera = cam

bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
bpy.context.scene.display.shading.light = "STUDIO"
bpy.context.scene.render.resolution_x = 900
bpy.context.scene.render.resolution_y = 900
bpy.context.scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print(f"Rendered: {out_png}")

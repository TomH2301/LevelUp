"""Parses our custom .bin mesh format (body+underwear+hair+bra) plus the
Eyes .usdz, combines them into one scene, and renders from front AND back
in one call — the current ground-truth check since the pipeline no longer
produces per-shape .usdz files for body parts (see BinaryMeshLoader.swift /
build_character_mh.py).

Usage:
  blender --background --python render_binary_combined_check.py -- <base_path> <has_bra 0|1> <Basis|Fat|Muscular> <out_front.png> <out_back.png>
  e.g. ... -- "...\LevelUp_Female" 1 Basis front.png back.png
"""

import sys
import struct
import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
base_path = argv[0]
has_bra = argv[1] == "1"
shape = argv[2] if len(argv) > 2 else "Basis"
out_front = argv[3]
out_back = argv[4]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


PART_COLORS = {
    "_Body": (0.86, 0.72, 0.6, 1.0),
    "_Underwear": (0.08, 0.08, 0.1, 1.0),
    "_Hair": (0.15, 0.09, 0.06, 1.0),
    "_Bra": (0.08, 0.08, 0.1, 1.0),
}


def load_part(prefix, shape_name):
    with open(f"{prefix}_mesh.bin", "rb") as f:
        data = f.read()
    offset = 0
    vcount, tcount = struct.unpack_from("<II", data, offset)
    offset += 8
    positions = struct.unpack_from(f"<{vcount*3}f", data, offset)
    offset += vcount * 3 * 4
    offset += vcount * 3 * 4  # skip normals, Blender recomputes on import
    indices = struct.unpack_from(f"<{tcount*3}I", data, offset)

    if shape_name:
        with open(f"{prefix}_{shape_name}.bin", "rb") as f:
            morph_data = f.read()
        positions = struct.unpack_from(f"<{vcount*3}f", morph_data, 0)

    mesh = bpy.data.meshes.new(prefix)
    verts = [(positions[i*3], positions[i*3+1], positions[i*3+2]) for i in range(vcount)]
    faces = [(indices[i*3], indices[i*3+1], indices[i*3+2]) for i in range(tcount)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(prefix, mesh)
    bpy.context.collection.objects.link(obj)

    for suffix, color in PART_COLORS.items():
        if prefix.endswith(suffix):
            mat = bpy.data.materials.new(f"{prefix}_mat")
            mat.use_nodes = False
            mat.diffuse_color = color
            mesh.materials.append(mat)
            break

    return obj


load_part(f"{base_path}_Body", shape)
load_part(f"{base_path}_Underwear", shape)
load_part(f"{base_path}_Hair", shape)
if has_bra:
    load_part(f"{base_path}_Bra", shape)
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

bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
bpy.context.scene.display.shading.light = "STUDIO"
bpy.context.scene.display.shading.color_type = "MATERIAL"
bpy.context.scene.render.resolution_x = 900
bpy.context.scene.render.resolution_y = 900

dist = size * 2.2


def render_from(y_offset, out_path):
    cam_data = bpy.data.cameras.new("DebugCam")
    cam_obj = bpy.data.objects.new("DebugCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_obj.location = (center[0], center[1] + y_offset, center[2])
    look_dir = mathutils.Vector(center) - mathutils.Vector(cam_obj.location)
    cam_obj.rotation_euler = look_dir.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam_obj
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {out_path}")
    bpy.data.objects.remove(cam_obj, do_unlink=True)


render_from(-dist, out_front)
render_from(dist, out_back)

import os
import bpy

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
usdz_path = os.path.join(OUT_DIR, "morphtest.usdz")

# Fresh scene
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

bpy.ops.wm.usd_import(filepath=usdz_path)

print("--- objects after import ---")
for obj in bpy.context.scene.objects:
    print("Object:", obj.name, obj.type)
    if obj.type == "MESH":
        sk = obj.data.shape_keys
        if sk:
            print("  Shape keys found:", [b.name for b in sk.key_blocks])
        else:
            print("  NO shape keys on this mesh")

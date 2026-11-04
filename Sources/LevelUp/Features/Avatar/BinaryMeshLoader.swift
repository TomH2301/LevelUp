import Foundation
import SceneKit

/// Parses the custom binary mesh format written by
/// BlenderAssets/build_character_mh.py's export_mesh_and_morphs_binary()
/// directly into SCNGeometry — no USDZ import involved for body parts.
///
/// Root-cause fix for a device bug where the avatar's geometry (head,
/// clothing fit) exploded once real Fat/Muscular weights were applied: the
/// previous pipeline loaded Basis/Fat/Muscular as THREE SEPARATE .usdz
/// files, which only works as morph targets if Apple's USD importer
/// independently re-triangulates/re-indexes every file IDENTICALLY so that
/// vertex N in one file still means vertex N in another. That isn't
/// something we can verify or control, and evidently wasn't reliable once
/// per-vertex smooth normals (which differ between Fat/Muscular/Basis)
/// started influencing the importer's internal vertex splitting. Building
/// the SCNGeometry ourselves from one shared vertex-index space guarantees
/// correspondence by construction instead of hoping Apple's importer
/// agrees with itself across files.
enum BinaryMeshLoader {
    struct Mesh {
        let geometry: SCNGeometry
        let vertexCount: Int
    }

    /// <prefix>_mesh.bin: vertexCount(u32) triangleCount(u32)
    ///   positions[vertexCount*3] f32 (Basis)
    ///   normals[vertexCount*3] f32 (Basis)
    ///   triangleIndices[triangleCount*3] u32
    static func loadMesh(named prefix: String) -> Mesh? {
        guard let url = Bundle.main.url(forResource: "\(prefix)_mesh", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else { return nil }

        var offset = 0
        guard let vertexCount = readUInt32(data, &offset),
              let triangleCount = readUInt32(data, &offset),
              let positions = readFloatArray(data, &offset, count: Int(vertexCount) * 3),
              let normals = readFloatArray(data, &offset, count: Int(vertexCount) * 3),
              let indices = readUInt32Array(data, &offset, count: Int(triangleCount) * 3) else {
            return nil
        }

        let vertexSource = SCNGeometrySource(
            data: positions.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .vertex,
            vectorCount: Int(vertexCount),
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        let normalSource = SCNGeometrySource(
            data: normals.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .normal,
            vectorCount: Int(vertexCount),
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        let element = SCNGeometryElement(
            data: indices.withUnsafeBufferPointer { Data(buffer: $0) },
            primitiveType: .triangles,
            primitiveCount: Int(triangleCount),
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        return Mesh(geometry: geometry, vertexCount: Int(vertexCount))
    }

    /// <prefix>_<shape>.bin: positions[vertexCount*3] f32, same vertex order
    /// as the base mesh from loadMesh(named:) — only a vertex-position
    /// source, no element, since SCNMorpher.targets geometries are only
    /// ever read for their vertex data, never rendered directly.
    static func loadMorphTarget(named prefix: String, shape: String, vertexCount: Int) -> SCNGeometry? {
        guard let url = Bundle.main.url(forResource: "\(prefix)_\(shape)", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else { return nil }

        var offset = 0
        guard let positions = readFloatArray(data, &offset, count: vertexCount * 3) else { return nil }

        let vertexSource = SCNGeometrySource(
            data: positions.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .vertex,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        return SCNGeometry(sources: [vertexSource], elements: nil)
    }

    // MARK: - Raw little-endian parsing

    private static func readUInt32(_ data: Data, _ offset: inout Int) -> UInt32? {
        guard let array = readUInt32Array(data, &offset, count: 1) else { return nil }
        return array[0]
    }

    private static func readFloatArray(_ data: Data, _ offset: inout Int, count: Int) -> [Float]? {
        let byteCount = count * MemoryLayout<Float>.size
        guard offset + byteCount <= data.count else { return nil }
        var result = [Float](repeating: 0, count: count)
        result.withUnsafeMutableBytes { dest in
            data.copyBytes(to: dest, from: offset..<(offset + byteCount))
        }
        offset += byteCount
        return result
    }

    private static func readUInt32Array(_ data: Data, _ offset: inout Int, count: Int) -> [UInt32]? {
        let byteCount = count * MemoryLayout<UInt32>.size
        guard offset + byteCount <= data.count else { return nil }
        var result = [UInt32](repeating: 0, count: count)
        result.withUnsafeMutableBytes { dest in
            data.copyBytes(to: dest, from: offset..<(offset + byteCount))
        }
        offset += byteCount
        // Blender writes explicit little-endian ("<" struct format); iOS
        // devices are little-endian too, so this is a no-op in practice —
        // kept explicit so it stays correct if that ever changes.
        return result.map { UInt32(littleEndian: $0) }
    }
}

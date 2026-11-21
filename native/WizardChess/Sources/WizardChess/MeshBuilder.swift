import RealityKit
import simd

struct MeshBuilder {
  private(set) var positions: [SIMD3<Float>] = []
  private(set) var normals: [SIMD3<Float>] = []
  private(set) var uvs: [SIMD2<Float>] = []

  var isEmpty: Bool { positions.isEmpty }

  mutating func addTriangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
    let n = cross(b - a, c - a)
    guard length(n) > 1e-7 else { return }
    let unit = normalize(n)
    append([a, b, c], normals: [unit, unit, unit])
  }

  private mutating func append(_ p: [SIMD3<Float>], normals n: [SIMD3<Float>]) {
    guard length(cross(p[1] - p[0], p[2] - p[0])) > 1e-8 else { return }
    positions += p
    normals += n
    uvs += p.map { SIMD2($0.x + $0.z * 0.7, $0.y) * 1.6 }
  }

  mutating func addLathe(
    _ profile: [SIMD2<Float>], segments: Int, twist: Float = 0, transform: float4x4 = matrix_identity_float4x4
  ) {
    func point(_ i: Int, _ j: Int) -> SIMD3<Float> {
      let angle = Float(j) / Float(segments) * 2 * .pi + twist * profile[i].y
      return transform.apply(SIMD3(profile[i].x * cos(angle), profile[i].y, profile[i].x * sin(angle)))
    }
    for i in 0..<(profile.count - 1) {
      for j in 0..<segments {
        let a = point(i, j), b = point(i + 1, j), c = point(i, j + 1), d = point(i + 1, j + 1)
        addTriangle(a, b, c)
        addTriangle(b, d, c)
      }
    }
  }

  mutating func addSmoothLathe(
    _ profile: [SIMD2<Float>], segments: Int = 28, arc: ClosedRange<Float> = 0...(2 * .pi),
    transform: float4x4 = matrix_identity_float4x4
  ) {
    let ring = profile.indices.map { i -> SIMD2<Float> in
      let t = profile[min(i + 1, profile.count - 1)] - profile[max(i - 1, 0)]
      return length(t) > 0 ? normalize(SIMD2(t.y, -t.x)) : SIMD2(0, 1)
    }
    func vertex(_ i: Int, _ j: Int) -> (SIMD3<Float>, SIMD3<Float>) {
      let a = arc.lowerBound + Float(j) / Float(segments) * (arc.upperBound - arc.lowerBound)
      let p = SIMD3(profile[i].x * cos(a), profile[i].y, profile[i].x * sin(a))
      let n = SIMD3(ring[i].x * cos(a), ring[i].y, ring[i].x * sin(a))
      return (transform.apply(p), transform.rotate(n))
    }
    for i in 0..<(profile.count - 1) {
      for j in 0..<segments {
        let a = vertex(i, j), b = vertex(i + 1, j), c = vertex(i, j + 1), d = vertex(i + 1, j + 1)
        append([a.0, b.0, c.0], normals: [a.1, b.1, c.1])
        append([b.0, d.0, c.0], normals: [b.1, d.1, c.1])
      }
    }
  }

  mutating func addEllipsoid(_ radii: SIMD3<Float>, transform: float4x4, stacks: Int = 10, slices: Int = 18) {
    func vertex(_ i: Int, _ j: Int) -> (SIMD3<Float>, SIMD3<Float>) {
      let phi = Float(i) / Float(stacks) * .pi
      let theta = Float(j) / Float(slices) * 2 * .pi
      let unit = SIMD3(sin(phi) * cos(theta), -cos(phi), sin(phi) * sin(theta))
      let p = unit * radii
      return (transform.apply(p), transform.rotate(normalize(unit / radii)))
    }
    for i in 0..<stacks {
      for j in 0..<slices {
        let a = vertex(i, j), b = vertex(i + 1, j), c = vertex(i, j + 1), d = vertex(i + 1, j + 1)
        append([a.0, b.0, c.0], normals: [a.1, b.1, c.1])
        append([b.0, d.0, c.0], normals: [b.1, d.1, c.1])
      }
    }
  }

  mutating func addRod(radius: Float, from: Float, to: Float, transform: float4x4) {
    addSmoothLathe(
      [SIMD2(0, from), SIMD2(radius, from), SIMD2(radius, to), SIMD2(0, to)], segments: 10, transform: transform)
  }

  mutating func addBox(_ size: SIMD3<Float>, transform: float4x4) {
    let h = size / 2
    let corners = (0..<8).map { i -> SIMD3<Float> in
      transform.apply(
        SIMD3<Float>(i & 1 == 0 ? -h.x : h.x, i & 2 == 0 ? -h.y : h.y, i & 4 == 0 ? -h.z : h.z))
    }
    let faces = [
      [0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5],
    ]
    for f in faces {
      addTriangle(corners[f[0]], corners[f[1]], corners[f[2]])
      addTriangle(corners[f[0]], corners[f[2]], corners[f[3]])
    }
  }

  mutating func addCrystal(radius: Float, height: Float, at center: SIMD3<Float>, sides: Int = 4) {
    addLathe(
      [SIMD2(0, -height / 2), SIMD2(radius, 0), SIMD2(0, height / 2)], segments: sides,
      transform: .translation(center))
  }

  func mesh() -> MeshResource {
    var d = MeshDescriptor(name: "carved")
    d.positions = MeshBuffers.Positions(positions)
    d.normals = MeshBuffers.Normals(normals)
    d.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
    d.primitives = .triangles((0..<UInt32(positions.count)).map { $0 })
    return try! MeshResource.generate(from: [d])
  }
}

extension float4x4 {
  static func translation(_ t: SIMD3<Float>) -> float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(t, 1)
    return m
  }

  static func pose(_ t: SIMD3<Float>, pitch: Float = 0, yaw: Float = 0, roll: Float = 0) -> float4x4 {
    let q =
      simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0])
      * simd_quatf(angle: roll, axis: [0, 0, 1])
    var m = float4x4(q)
    m.columns.3 = SIMD4(t, 1)
    return m
  }

  func apply(_ p: SIMD3<Float>) -> SIMD3<Float> {
    let q = self * SIMD4(p, 1)
    return SIMD3(q.x, q.y, q.z)
  }

  func rotate(_ n: SIMD3<Float>) -> SIMD3<Float> {
    let q = self * SIMD4(n, 0)
    return normalize(SIMD3(q.x, q.y, q.z))
  }
}

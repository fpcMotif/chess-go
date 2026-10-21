import AppKit
import ChessCore
import RealityKit
import simd

extension NSColor {
  convenience init(hex: UInt32, alpha: CGFloat = 1) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
  }
}

struct PieceLook {
  let body: any RealityKit.Material
  let accent: any RealityKit.Material
}

enum StoneKind {
  case marble, slate
}

enum Stone {
  static func material(_ kind: StoneKind, tint: UInt32, roughness: Float) -> PhysicallyBasedMaterial {
    let (color, normal) = textures(kind)
    var m = PhysicallyBasedMaterial()
    m.baseColor = .init(tint: NSColor(hex: tint), texture: .init(color))
    m.normal = .init(texture: .init(normal))
    m.roughness = .init(floatLiteral: roughness)
    m.textureCoordinateTransform = .init(scale: [1.4, 1.4])
    return m
  }

  static func tileMaterial(tint: UInt32, roughness: Float) -> PhysicallyBasedMaterial {
    let (color, normal) = Art.tile()
    var m = PhysicallyBasedMaterial()
    m.baseColor = .init(tint: NSColor(hex: tint), texture: .init(color))
    m.normal = .init(texture: .init(normal))
    m.roughness = .init(floatLiteral: roughness)
    return m
  }

  private static var cache: [StoneKind: (TextureResource, TextureResource)] = [:]

  private static func textures(_ kind: StoneKind) -> (TextureResource, TextureResource) {
    if let hit = cache[kind] { return hit }
    let made = textures(height: heightField(kind, size: 256), size: 256, relief: 2.5)
    cache[kind] = made
    return made
  }

  static func heightField(_ kind: StoneKind, size: Int) -> [Float] {
    var height = [Float](repeating: 0, count: size * size)
    var rng = SplitMix(seed: kind == .marble ? 11 : 29)
    let lattice = (0..<(65 * 65)).map { _ in rng.float(0, 1) }
    func value(_ x: Float, _ y: Float) -> Float {
      let xi = Int(x) & 63, yi = Int(y) & 63
      let fx = x - x.rounded(.down), fy = y - y.rounded(.down)
      let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
      let a = lattice[yi * 65 + xi], b = lattice[yi * 65 + xi + 1]
      let c = lattice[(yi + 1) * 65 + xi], d = lattice[(yi + 1) * 65 + xi + 1]
      return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy
    }
    for y in 0..<size {
      for x in 0..<size {
        var f: Float = 0, amp: Float = 0.5, freq: Float = 6 / Float(size)
        for _ in 0..<5 {
          f += amp * value(Float(x) * freq, Float(y) * freq)
          amp *= 0.5
          freq *= 2
        }
        let h: Float
        switch kind {
        case .marble:
          let vein = abs(sin((Float(x) * 0.035 + Float(y) * 0.02 + f * 6)))
          h = 0.86 + 0.14 * f - 0.32 * pow(1 - vein, 14)
        case .slate:
          h = 0.62 + 0.28 * f + 0.1 * sin(Float(y) * 0.15 + f * 6)
        }
        height[y * size + x] = h
      }
    }
    return height
  }

  static func textures(height: [Float], size: Int, relief: Float) -> (TextureResource, TextureResource) {
    var color = [UInt8](repeating: 255, count: size * size * 4)
    var normal = [UInt8](repeating: 255, count: size * size * 4)
    for y in 0..<size {
      for x in 0..<size {
        let i = y * size + x
        let g = UInt8(max(0, min(1, height[i])) * 255)
        color[i * 4] = g
        color[i * 4 + 1] = g
        color[i * 4 + 2] = g
        let dx = height[y * size + (x + 1) % size] - height[y * size + (x + size - 1) % size]
        let dy = height[((y + 1) % size) * size + x] - height[((y + size - 1) % size) * size + x]
        let n = normalize(SIMD3<Float>(-dx * relief, -dy * relief, 1))
        normal[i * 4] = UInt8((n.x * 0.5 + 0.5) * 255)
        normal[i * 4 + 1] = UInt8((n.y * 0.5 + 0.5) * 255)
        normal[i * 4 + 2] = UInt8((n.z * 0.5 + 0.5) * 255)
      }
    }
    return (texture(color, size, .color), texture(normal, size, .normal))
  }

  private static func texture(_ bytes: [UInt8], _ size: Int, _ semantic: TextureResource.Semantic) -> TextureResource {
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let image = CGImage(
      width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    return try! TextureResource(image: image, options: .init(semantic: semantic))
  }
}

final class PieceFactory {
  let looks: [Side: PieceLook]
  private var meshes: [Role: (body: MeshResource, accent: MeshResource)] = [:]
  let rubbleMeshes: [MeshResource]

  init(saga: Saga) {
    func look(_ army: Army) -> PieceLook {
      let accent: any RealityKit.Material
      if army.accentIsMetal {
        var metal = PhysicallyBasedMaterial()
        metal.baseColor = .init(tint: NSColor(hex: army.accent))
        metal.roughness = 0.2
        metal.metallic = 1.0
        accent = metal
      } else {
        accent = UnlitMaterial(color: NSColor(hex: army.accent))
      }
      let stone = Stone.material(army.stone, tint: army.tint, roughness: army.roughness)
      return PieceLook(body: Wizardry.enchant(stone, glow: army.strikeColor), accent: accent)
    }
    looks = [.white: look(saga.white), .black: look(saga.black)]

    var rng = SplitMix(seed: 0xB0_0DE5)
    rubbleMeshes = (0..<6).map { _ in
      var b = MeshBuilder()
      for _ in 0..<2 {
        b.addBox(
          [rng.float(0.04, 0.12), rng.float(0.04, 0.1), rng.float(0.04, 0.12)],
          transform: .pose(
            [rng.float(-0.02, 0.02), rng.float(-0.02, 0.02), 0], pitch: rng.float(0, 3), yaw: rng.float(0, 3)))
      }
      return b.mesh()
    }
  }

  func makeEntity(_ piece: Piece) -> Entity {
    let root = Entity()
    root.name = "\(piece.side)-\(piece.role)"
    let look = looks[piece.side]!
    let (body, accent) = mesh(piece.role)
    let holder = Entity()
    let facing: Float = (piece.side == .white ? 0 : .pi) + (piece.role == .knight ? 0.9 : 0)
    holder.orientation = simd_quatf(angle: facing, axis: [0, 1, 0])
    holder.addChild(ModelEntity(mesh: body, materials: [look.body]))
    holder.addChild(ModelEntity(mesh: accent, materials: [look.accent]))
    root.addChild(holder)
    return root
  }

  private func mesh(_ role: Role) -> (body: MeshResource, accent: MeshResource) {
    if let m = meshes[role] { return m }
    var body = MeshBuilder()
    var accent = MeshBuilder()
    let plinth: [SIMD2<Float>] = [[0, 0], [0.36, 0], [0.37, 0.03], [0.36, 0.06], [0.32, 0.075]]
    switch role {
    case .pawn:
      body.addSmoothLathe(
        plinth + [
          [0.26, 0.09], [0.21, 0.3], [0.16, 0.5], [0.19, 0.56], [0.17, 0.62], [0.09, 0.66], [0.13, 0.7],
          [0.145, 0.78], [0.12, 0.86], [0.06, 0.92], [0, 0.94],
        ])
      body.addEllipsoid([0.15, 0.2, 0.035], transform: .pose([-0.07, 0.42, -0.2], yaw: 0.25))
      body.addRod(radius: 0.017, from: -0.45, to: 0.5, transform: .pose([0.2, 0.55, -0.08]))
      accent.addSmoothLathe([[0, 0], [0.035, 0.0], [0, 0.14]], segments: 8, transform: .translation([0.2, 1.05, -0.08]))
      accent.addEllipsoid([0.05, 0.05, 0.03], transform: .pose([-0.09, 0.42, -0.235], yaw: 0.25))
      for k in 0..<7 {
        let a = Float(k) / 6 * 2.4 - 1.2
        accent.addBox(
          [0.035, 0.09 + 0.03 * cos(a), 0.06],
          transform: .pose([0, 0.84 + 0.13 * cos(a), 0.13 * sin(a)], pitch: a))
      }
    case .rook:
      body.addSmoothLathe(
        plinth + [
          [0.29, 0.1], [0.26, 0.62], [0.31, 0.68], [0.32, 0.82], [0.25, 0.82], [0.25, 0.76], [0, 0.76],
        ])
      for k in 0..<6 {
        let a = Float(k) / 6 * 2 * .pi
        body.addBox([0.11, 0.13, 0.1], transform: .pose([0.27 * cos(a), 0.88, 0.27 * sin(a)], yaw: -a))
      }
      for k in 0..<4 {
        let a = Float(k) / 4 * 2 * .pi + .pi / 4
        accent.addBox([0.04, 0.14, 0.02], transform: .pose([0.27 * cos(a), 0.42, 0.27 * sin(a)], yaw: .pi / 2 - a))
      }
    case .knight:
      body.addSmoothLathe(plinth + [[0.29, 0.1], [0.27, 0.22], [0.2, 0.26], [0, 0.27]])
      body.addEllipsoid([0.15, 0.17, 0.16], transform: .pose([0, 0.36, -0.03]))
      body.addEllipsoid([0.12, 0.3, 0.15], transform: .pose([0, 0.52, 0.03], pitch: -0.35))
      body.addEllipsoid([0.1, 0.11, 0.22], transform: .pose([0, 0.77, -0.12], pitch: 0.55))
      body.addEllipsoid([0.08, 0.08, 0.1], transform: .pose([0, 0.67, -0.29], pitch: 0.4))
      for s: Float in [-1, 1] {
        body.addSmoothLathe(
          [[0, 0], [0.035, 0], [0, 0.12]], segments: 8, transform: .pose([0.05 * s, 0.86, 0.0], roll: -0.25 * s))
        accent.addEllipsoid([0.025, 0.02, 0.025], transform: .translation([0.085 * s, 0.79, -0.17]))
      }
      for k in 0..<6 {
        let t = Float(k) / 5
        body.addBox(
          [0.05, 0.1, 0.09], transform: .pose([0, 0.38 + 0.44 * t, 0.17 - 0.18 * t * t], pitch: -0.4))
      }
    case .bishop:
      body.addSmoothLathe(
        plinth + [
          [0.27, 0.09], [0.21, 0.35], [0.15, 0.6], [0.18, 0.66], [0.16, 0.72], [0.08, 0.76], [0.11, 0.8],
          [0.105, 0.86], [0.13, 0.9], [0.145, 0.98], [0.12, 1.04], [0, 1.05],
        ])
      for s: Float in [-1, 1] {
        body.addEllipsoid([0.12, 0.17, 0.06], transform: .pose([0, 1.12, 0.045 * s], pitch: -0.28 * s))
      }
      body.addRod(radius: 0.02, from: -0.6, to: 0.55, transform: .pose([0.22, 0.62, -0.06]))
      body.addSmoothLathe(
        [[0.02, 0], [0.09, 0.02], [0.1, 0.05]], segments: 14, arc: 0...(1.4 * .pi),
        transform: .pose([0.22, 1.2, -0.06], pitch: .pi / 2))
      accent.addEllipsoid([0.055, 0.055, 0.055], transform: .translation([0.22, 1.21, -0.06]))
      accent.addBox([0.06, 0.24, 0.015], transform: .translation([0, 1.06, -0.115]))
    case .queen:
      body.addSmoothLathe(
        plinth + [
          [0.33, 0.1], [0.27, 0.3], [0.17, 0.55], [0.12, 0.72], [0.17, 0.84], [0.2, 0.9], [0.12, 0.95],
          [0.07, 0.99], [0.1, 1.03], [0.11, 1.1], [0.085, 1.16], [0, 1.18],
        ])
      for s: Float in [-1, 1] {
        body.addEllipsoid([0.05, 0.22, 0.06], transform: .pose([0.19 * s, 0.76, -0.02], roll: 0.25 * s))
      }
      body.addSmoothLathe(
        [[0.37, 0.08], [0.31, 0.3], [0.22, 0.6], [0.2, 0.8], [0.235, 0.92]], segments: 18,
        arc: (0.12 * .pi)...(0.88 * .pi))
      accent.addSmoothLathe([[0.1, 1.12], [0.12, 1.12], [0.12, 1.16], [0.1, 1.16]], segments: 20)
      for k in 0..<8 {
        let a = Float(k) / 8 * 2 * .pi
        accent.addSmoothLathe(
          [[0, 0], [0.022, 0], [0, 0.1]], segments: 6, transform: .translation([0.11 * cos(a), 1.15, 0.11 * sin(a)]))
      }
    case .king:
      body.addSmoothLathe(
        plinth + [
          [0.34, 0.1], [0.28, 0.35], [0.2, 0.65], [0.22, 0.88], [0.27, 0.97], [0.15, 1.02], [0.08, 1.05],
          [0.11, 1.1], [0.12, 1.18], [0.09, 1.24], [0, 1.26],
        ])
      for s: Float in [-1, 1] {
        body.addEllipsoid([0.06, 0.24, 0.07], transform: .pose([0.2 * s, 0.82, -0.1], pitch: 0.5, roll: 0.2 * s))
      }
      body.addSmoothLathe(
        [[0.38, 0.08], [0.33, 0.35], [0.25, 0.65], [0.25, 0.88], [0.295, 0.98]], segments: 18,
        arc: (0.1 * .pi)...(0.9 * .pi))
      accent.addBox([0.06, 0.62, 0.015], transform: .translation([0, 0.42, -0.27]))
      accent.addBox([0.22, 0.04, 0.04], transform: .translation([0, 0.74, -0.27]))
      accent.addRod(radius: 0.02, from: 0.74, to: 0.86, transform: .translation([0, 0, -0.27]))
      accent.addSmoothLathe([[0.115, 1.2], [0.135, 1.2], [0.135, 1.27], [0.115, 1.27]], segments: 20)
      for k in 0..<5 {
        let a = Float(k) / 5 * 2 * .pi
        accent.addSmoothLathe(
          [[0, 0], [0.025, 0], [0, 0.09]], segments: 6, transform: .translation([0.125 * cos(a), 1.26, 0.125 * sin(a)]))
      }
      accent.addBox([0.04, 0.16, 0.04], transform: .translation([0, 1.36, 0]))
      accent.addBox([0.12, 0.04, 0.04], transform: .translation([0, 1.38, 0]))
    }
    let m = (body.mesh(), accent.mesh())
    meshes[role] = m
    return m
  }
}

import AppKit
import RealityKit
import simd

final class World {
  let root = Entity()
  private var rocks: [(Entity, radius: Float, height: Float, phase: Float, rate: Float)] = []
  private var motes: [(ModelEntity, SIMD3<Float>, phase: Float)] = []
  private let moteRises: Bool
  private var rng: SplitMix

  init(saga: Saga) {
    moteRises = saga.abyss.moteRises
    rng = SplitMix(seed: UInt64(saga.id.utf8.reduce(99) { $0 &* 31 &+ UInt64($1) }))
    buildMonuments(saga)
    buildRocks(saga)
    buildMotes(saga)
  }

  private func stone(_ saga: Saga) -> any RealityKit.Material {
    switch saga.monument {
    case .columns: Stone.material(.marble, tint: 0xCFC6B4, roughness: 0.75)
    case .runestones: Stone.material(.slate, tint: 0x56606A, roughness: 0.85)
    case .obelisks: Stone.material(.marble, tint: 0xB89A6A, roughness: 0.7)
    }
  }

  private func buildMonuments(_ saga: Saga) {
    let body = stone(saga)
    var accent = UnlitMaterial(color: NSColor(hex: saga.rim))
    accent.blending = .transparent(opacity: 0.9)
    let corners: [SIMD3<Float>] = [[-5.6, 0, -5.6], [5.6, 0, -5.6], [-5.6, 0, 5.6], [5.6, 0, 5.6]]
    for (i, c) in corners.enumerated() {
      var b = MeshBuilder()
      var a = MeshBuilder()
      let h = rng.float(2.2, 3.6)
      b.addBox([1.6, 0.5, 1.6], transform: .translation([0, -0.45, 0]))
      switch saga.monument {
      case .columns:
        let flutes = 14
        b.addLathe([[0.55, -0.2], [0.55, 0], [0.42, 0.08], [0.42, h - 0.3], [0.5, h - 0.2], [0.5, h]], segments: flutes)
        if i % 2 == 0 {
          b.addLathe(
            [[0.5, h], [0.62, h + 0.12], [0.62, h + 0.3], [0, h + 0.3]], segments: 4,
            transform: .pose([0, 0, 0], yaw: .pi / 4))
        } else {
          for k in 0..<5 {
            b.addBox(
              [rng.float(0.2, 0.45), rng.float(0.15, 0.3), rng.float(0.2, 0.4)],
              transform: .pose(
                [rng.float(-0.9, 0.9), -0.05 + Float(k) * 0.02, rng.float(-0.9, 0.9)], pitch: rng.float(0, 1),
                yaw: rng.float(0, 3)))
          }
        }
        a.addLathe([[0.44, 0.4], [0.44, 0.52]], segments: flutes)
      case .runestones:
        b.addLathe(
          [[0.9, -0.1], [0.75, 0.3], [0.6, h * 0.7], [0.3, h], [0, h + 0.1]], segments: 5,
          transform: .pose([0, 0, 0], pitch: rng.float(-0.12, 0.12), yaw: rng.float(0, 2), roll: rng.float(-0.1, 0.1)))
        for k in 0..<6 {
          let y = 0.5 + Float(k) * (h - 0.9) / 6
          a.addBox([0.05, 0.28, 0.4], transform: .pose([0, y, 0.62 - y * 0.08], yaw: rng.float(-0.4, 0.4)))
          a.addBox([0.05, 0.05, 0.3], transform: .pose([0, y + 0.1, 0.62 - y * 0.08], roll: 0.8))
        }
      case .obelisks:
        b.addLathe([[0.5, 0], [0.5, 0.2], [0.42, 0.2], [0.26, h], [0.28, h], [0, h + 0.45]], segments: 4)
        a.addLathe([[0.36, 0.9], [0.36, 1.05]], segments: 4)
        a.addLathe([[0.3, 2.0], [0.3, 2.12]], segments: 4)
        a.addEllipsoid([0.18, 0.1, 0.05], transform: .translation([0, h - 0.5, 0.3]))
      }
      let e = Entity()
      e.addChild(ModelEntity(mesh: b.mesh(), materials: [body]))
      e.addChild(ModelEntity(mesh: a.mesh(), materials: [accent]))
      e.position = c
      e.orientation = simd_quatf(angle: atan2(-c.x, -c.z) + (saga.monument == .obelisks ? .pi / 4 : 0), axis: [0, 1, 0])
      root.addChild(e)
    }
  }

  private func buildRocks(_ saga: Saga) {
    let mat = stone(saga)
    for _ in 0..<16 {
      var b = MeshBuilder()
      for _ in 0..<3 {
        b.addBox(
          [rng.float(0.5, 1.6), rng.float(0.3, 0.9), rng.float(0.5, 1.6)],
          transform: .pose([rng.float(-0.3, 0.3), rng.float(-0.2, 0.2), 0], pitch: rng.float(0, 3), yaw: rng.float(0, 3)))
      }
      let e = ModelEntity(mesh: b.mesh(), materials: [mat])
      e.orientation = simd_quatf(angle: rng.float(0, 6), axis: [0, 1, 0])
      root.addChild(e)
      rocks.append((e, rng.float(7.5, 13), rng.float(-7, -2), rng.float(0, 2 * .pi), rng.float(0.02, 0.06)))
    }
  }

  private func buildMotes(_ saga: Saga) {
    let mesh = MeshResource.generateSphere(radius: 0.035)
    var m = UnlitMaterial(color: NSColor(hex: saga.abyss.mote))
    m.blending = .transparent(opacity: 0.85)
    for _ in 0..<150 {
      let e = ModelEntity(mesh: mesh, materials: [m])
      let home = SIMD3<Float>(rng.float(-9, 9), rng.float(-3, 6), rng.float(-9, 9))
      e.position = home
      root.addChild(e)
      motes.append((e, home, rng.float(0, 2 * .pi)))
    }
  }

  func tick(_ time: Float) {
    for (e, r, h, ph, rate) in rocks {
      let a = ph + time * rate
      e.position = [r * cos(a), h + 0.4 * sin(time * 0.3 + ph), r * sin(a)]
      e.orientation = simd_quatf(angle: time * rate * 2 + ph, axis: [0.2, 1, 0.1])
    }
    let climb: Float = moteRises ? 0.35 : -0.15
    for (e, home, ph) in motes {
      let y = home.y + (time * climb + ph).truncatingRemainder(dividingBy: 9) - (moteRises ? 0 : 9)
      let yy = y > 6 ? y - 9 : (y < -3 ? y + 9 : y)
      e.position = [home.x + 0.5 * sin(time * 0.4 + ph), yy, home.z + 0.5 * cos(time * 0.33 + ph * 1.3)]
      e.scale = SIMD3(repeating: 0.6 + 0.5 * sin(time * 2.2 + ph))
    }
  }
}

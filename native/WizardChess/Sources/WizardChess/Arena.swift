import AppKit
import ChessCore
import RealityKit
import simd

struct BoardSnapshot {
  let position: Position
  let selected: Square?
  let hints: Set<Square>
  let lastMove: Move?
  let check: Square?
  let flipped: Bool
  let effect: MoveEffect?
  let saga: Saga
}

private final class Actor {
  let entity: Entity
  var piece: Piece
  init(entity: Entity, piece: Piece) {
    self.entity = entity
    self.piece = piece
  }
}

private struct Flight {
  let actor: Actor
  let from: Square
  let to: Square
  let start: Float
  let duration: Float
  let arc: Float
  let spin: Float
  var victim: (entity: Entity, piece: Piece, square: Square)?
  var promoteTo: Piece?
  var omen = false
  var struck = false
  var landed = false

  var isDuel: Bool { victim != nil || struck }
}

private enum FxKind {
  case flicker
  case beam
  case ring(Float)
  case dust(SIMD3<Float>)
  case rubble(SIMD3<Float>, SIMD3<Float>, Float)
  case flash(Float)
  case meteor(SIMD3<Float>, SIMD3<Float>)
}

private struct Fx {
  let entity: Entity
  var kind: FxKind
  let born: Float
  let life: Float
}

private struct Ripple {
  let center: SIMD2<Float>
  let born: Float
  let strength: Float
}

func squareCenter(_ sq: Square) -> SIMD3<Float> {
  [Float(fileOf(sq)) - 3.5, 0, 3.5 - Float(rankOf(sq))]
}

final class Arena {
  let root = Entity()
  private let camera = PerspectiveCamera()
  private(set) var saga: Saga
  private var factory: PieceFactory
  private var slabs: [Entity] = []
  private var stones: [ModelEntity] = []
  private var glows: [ModelEntity] = []
  private var crystals: [ModelEntity] = []
  private var phases: [Float] = []
  private var actors: [Square: Actor] = [:]
  private var flights: [Flight] = []
  private var fx: [Fx] = []
  private var ripples: [Ripple] = []
  private var lastEffectID: Int?
  private var snapshot: BoardSnapshot?
  private var time: Float = 0
  private var shake: Float = 0
  private var rng = SplitMix(seed: 0xD1CE)
  private let moon = ModelEntity(mesh: .generateSphere(radius: 5))
  private let halo = ModelEntity(mesh: .generateSphere(radius: 7.5))
  private let rim = PointLight()
  private let under = PointLight()

  var yaw: Float = 0
  var pitch: Float = 0.74
  var distance: Float = 12.5
  private var shownYaw: Float = 0
  private var targetFlip: Float = 0

  private let selectedGlow = Arena.glow(0xFFD27A, 0.6)
  private let lastMoveGlow = Arena.glow(0x4FD1C5, 0.4)
  private let checkGlow = Arena.glow(0xFF2D55, 0.75)
  private let quietCrystal = UnlitMaterial(color: NSColor(hex: 0x7DF9FF))
  private let captureCrystal = UnlitMaterial(color: NSColor(hex: 0xFF4D2E))
  private let ringMesh: MeshResource
  private let dustMesh = MeshResource.generateSphere(radius: 0.22)

  private static func glow(_ hex: UInt32, _ alpha: Float) -> UnlitMaterial {
    var m = UnlitMaterial(color: NSColor(hex: hex))
    m.blending = .transparent(opacity: .init(floatLiteral: alpha))
    return m
  }

  init(saga: Saga) {
    self.saga = saga
    factory = PieceFactory(saga: saga)
    var ring = MeshBuilder()
    ring.addSmoothLathe([[1, 0.02], [0.8, 0.02]], segments: 48)
    ringMesh = ring.mesh()
    var seed = SplitMix(seed: 0x5EED_CAFE)
    buildSky(&seed)
    buildBoard(&seed)
    buildLights()
    camera.camera.fieldOfViewInDegrees = 38
    camera.camera.far = 400
    root.addChild(camera)
    applySagaLook()
  }

  private func buildSky(_ seed: inout SplitMix) {
    var stars = MeshBuilder()
    for _ in 0..<420 {
      let z = seed.float(-1, 1)
      let a = seed.float(0, 2 * .pi)
      let r = (1 - z * z).squareRoot()
      stars.addCrystal(
        radius: seed.float(0.08, 0.32), height: seed.float(0.2, 0.7), at: SIMD3(r * cos(a), z, r * sin(a)) * 120)
    }
    root.addChild(ModelEntity(mesh: stars.mesh(), materials: [UnlitMaterial(color: NSColor(hex: 0xFFF4D6))]))
    moon.position = [-62, -40, -95]
    halo.position = moon.position * 1.06
    root.addChild(moon)
    root.addChild(halo)
  }

  private func buildBoard(_ seed: inout SplitMix) {
    let slabMesh = MeshResource.generateBox(width: 0.94, height: 0.36, depth: 0.94, cornerRadius: 0.035)
    let glowMesh = MeshResource.generatePlane(width: 0.9, depth: 0.9, cornerRadius: 0.06)
    var crystal = MeshBuilder()
    crystal.addCrystal(radius: 0.16, height: 0.42, at: .zero, sides: 5)
    let crystalMesh = crystal.mesh()
    for sq in 0..<64 {
      let slab = Entity()
      let stone = ModelEntity(mesh: slabMesh)
      stone.position.y = -0.18
      slab.addChild(stone)
      let glow = ModelEntity(mesh: glowMesh, materials: [selectedGlow])
      glow.position.y = 0.004
      glow.isEnabled = false
      slab.addChild(glow)
      let gem = ModelEntity(mesh: crystalMesh, materials: [quietCrystal])
      gem.isEnabled = false
      slab.addChild(gem)
      slab.position = squareCenter(sq)
      root.addChild(slab)
      slabs.append(slab)
      stones.append(stone)
      glows.append(glow)
      crystals.append(gem)
      phases.append(seed.float(0, 2 * .pi))
    }
  }

  private func buildLights() {
    let sun = DirectionalLight()
    sun.light.color = NSColor(hex: 0xFFE2B0)
    sun.light.intensity = 3200
    sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 18, depthBias: 2)
    sun.look(at: .zero, from: [-5, 9, 4], relativeTo: nil)
    root.addChild(sun)
    rim.light.intensity = 90_000
    rim.light.attenuationRadius = 22
    rim.position = [6, 3, -7]
    root.addChild(rim)
    under.light.intensity = 40_000
    under.light.attenuationRadius = 14
    under.position = [-5, -2.5, 5]
    root.addChild(under)
  }

  private func applySagaLook() {
    let light = Stone.material(.marble, tint: saga.lightSquare, roughness: 0.6)
    let dark = Stone.material(.slate, tint: saga.darkSquare, roughness: 0.7)
    for sq in 0..<64 {
      stones[sq].model?.materials = [(fileOf(sq) + rankOf(sq)) % 2 == 1 ? light : dark]
    }
    moon.model?.materials = [UnlitMaterial(color: NSColor(hex: saga.moon))]
    halo.model?.materials = [Arena.glow(saga.moon, 0.12)]
    rim.light.color = NSColor(hex: saga.rim)
    under.light.color = NSColor(hex: saga.under)
  }

  private func rippleOffset(_ sq: Square) -> Float {
    let c = squareCenter(sq)
    var y: Float = 0
    for r in ripples {
      let age = time - r.born
      let w = length(SIMD2(c.x, c.z) - r.center) - 6 * age
      y -= r.strength * exp(-1.8 * age) * exp(-3 * w * w) * cos(2.5 * w)
    }
    return y
  }

  private func bob(_ sq: Square) -> Float {
    0.07 * sin(time * 1.15 + phases[sq]) + rippleOffset(sq)
  }

  private func restPosition(_ sq: Square) -> SIMD3<Float> {
    squareCenter(sq) + [0, bob(sq), 0]
  }

  func sync(_ s: BoardSnapshot) {
    if s.flipped != snapshot?.flipped { targetFlip = s.flipped ? .pi : 0 }
    if s.saga != saga {
      saga = s.saga
      factory = PieceFactory(saga: saga)
      applySagaLook()
      actors.removeAll()
    }
    snapshot = s
    if let e = s.effect, e.id != lastEffectID {
      lastEffectID = e.id
      startFlights(e)
    }
    if !actorsMatch(s.position) { rebuild(s.position) }
    for sq in 0..<64 {
      let glow = glows[sq]
      if sq == s.check {
        glow.model?.materials = [checkGlow]
      } else if sq == s.selected {
        glow.model?.materials = [selectedGlow]
      } else if let m = s.lastMove, m.from == sq || m.to == sq {
        glow.model?.materials = [lastMoveGlow]
      }
      glow.isEnabled =
        sq == s.check || sq == s.selected || s.lastMove.map { $0.from == sq || $0.to == sq } == true
      let gem = crystals[sq]
      gem.isEnabled = s.hints.contains(sq)
      gem.model?.materials = [s.position[sq] == nil ? quietCrystal : captureCrystal]
    }
  }

  private func actorsMatch(_ p: Position) -> Bool {
    for sq in 0..<64 where actors[sq]?.piece != p[sq] { return false }
    return true
  }

  private func rebuild(_ p: Position) {
    for f in flights {
      f.victim?.entity.removeFromParent()
      f.actor.entity.removeFromParent()
    }
    flights.removeAll()
    for e in Array(root.children) where e.name.hasPrefix("white-") || e.name.hasPrefix("black-") {
      e.removeFromParent()
    }
    actors.removeAll()
    for sq in 0..<64 {
      guard let piece = p[sq] else { continue }
      let e = factory.makeEntity(piece)
      e.position = restPosition(sq)
      root.addChild(e)
      actors[sq] = Actor(entity: e, piece: piece)
    }
  }

  private func startFlights(_ e: MoveEffect) {
    guard let mover = actors.removeValue(forKey: e.move.from) else { return }
    var victim: (Entity, Piece, Square)?
    if let vs = e.victimSquare, let v = actors.removeValue(forKey: vs) {
      victim = (v.entity, v.piece, vs)
    }
    let leap = mover.piece.role == .knight
    var flight = Flight(
      actor: mover, from: e.move.from, to: e.move.to, start: time,
      duration: victim != nil ? 1.9 : (leap ? 0.8 : 0.6), arc: leap ? 1.4 : 0.22, spin: leap ? 2 * .pi : 0,
      victim: victim)
    if let promo = e.move.promotion {
      let promoted = Piece(mover.piece.side, promo)
      flight.promoteTo = promoted
      mover.piece = promoted
    }
    actors[e.move.to] = mover
    flights.append(flight)
    if let r = e.rook, let rook = actors.removeValue(forKey: r.from) {
      actors[r.to] = rook
      flights.append(
        Flight(actor: rook, from: r.from, to: r.to, start: time + 0.15, duration: 0.6, arc: 0.9, spin: .pi))
    }
  }

  func tick(_ dt: Float) {
    time += dt
    ripples.removeAll { time - $0.born > 2.5 }
    for sq in 0..<64 {
      slabs[sq].position.y = bob(sq)
      crystals[sq].position.y = 0.55 + 0.06 * sin(time * 3 + Float(sq))
      crystals[sq].orientation = simd_quatf(angle: time * 1.6, axis: [0, 1, 0])
      if sq == snapshot?.check, glows[sq].isEnabled {
        glows[sq].scale = SIMD3(repeating: 0.9 + 0.12 * sin(time * 8))
      }
    }
    for (sq, a) in actors where !flights.contains(where: { $0.actor === a }) {
      a.entity.position = restPosition(sq)
      a.entity.orientation = simd_quatf(angle: 0.04 * sin(time * 0.9 + phases[sq]), axis: [0, 0, 1])
    }
    advanceFlights()
    advanceFx(dt)
    updateCamera(dt)
  }

  private static func ease(_ p: Float) -> Float {
    p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
  }

  private func advanceFlights() {
    var remaining: [Flight] = []
    for var f in flights {
      let p = min(max((time - f.start) / f.duration, 0), 1)
      let a = restPosition(f.from), b = restPosition(f.to)
      let dir = b - a
      let axis = length(dir) > 0 ? normalize(cross([0, 1, 0], dir)) : SIMD3<Float>(1, 0, 0)
      if f.isDuel {
        duelPose(&f, p, a, b, axis)
      } else {
        let eased = Self.ease(p)
        var pos = simd_mix(a, b, SIMD3(repeating: eased))
        pos.y += f.arc * sin(.pi * p)
        f.actor.entity.position = pos
        f.actor.entity.orientation =
          simd_quatf(angle: f.spin * eased, axis: [0, 1, 0]) * simd_quatf(angle: 0.35 * sin(.pi * p), axis: axis)
      }
      if p >= 1, let promo = f.promoteTo {
        let fresh = factory.makeEntity(promo)
        for child in Array(f.actor.entity.children) { child.removeFromParent() }
        for child in Array(fresh.children) { f.actor.entity.addChild(child) }
        f.promoteTo = nil
        flash(at: b + [0, 0.8, 0], color: saga.army(promo.side).strikeColor, peak: 300_000)
        ring(at: b, color: saga.army(promo.side).strikeColor, size: 2.5)
      }
      if p < 1 { remaining.append(f) }
    }
    flights = remaining
  }

  private func duelPose(_ f: inout Flight, _ p: Float, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ axis: SIMD3<Float>) {
    let side = f.actor.piece.side
    let army = saga.army(side)
    let poised = a + (b - a) * 0.5 + [0, 0.75, 0]
    var pos: SIMD3<Float>
    var lean: Float
    switch p {
    case ..<0.35:
      let q = Self.ease(p / 0.35)
      pos = simd_mix(a, a + (b - a) * 0.5, SIMD3(repeating: q))
      pos.y += 0.3 * sin(.pi * q)
      lean = 0.3 * sin(.pi * q)
    case ..<0.55:
      let q = Self.ease((p - 0.35) / 0.2)
      pos = simd_mix(a + (b - a) * 0.5, poised, SIMD3(repeating: q))
      lean = -0.5 * q
    case ..<0.8:
      pos = poised + [0, 0.05 * sin(time * 30) * (f.struck ? 1 : 0.3), 0]
      lean = f.struck ? 0.25 : -0.5
    default:
      let q = (p - 0.8) / 0.2
      pos = simd_mix(poised, b, SIMD3(repeating: q * q))
      lean = 0.5 * (1 - q)
    }
    f.actor.entity.position = pos
    f.actor.entity.orientation = simd_quatf(angle: lean, axis: axis)

    if p >= 0.4, !f.omen, let v = f.victim {
      f.omen = true
      if army.strike == .meteor {
        let target = restPosition(v.square) + [0, 0.5, 0]
        meteor(to: target, color: army.strikeColor, life: 0.22 * f.duration)
      }
      shake = max(shake, 0.05)
    }
    if p >= 0.62, !f.struck, let v = f.victim {
      f.struck = true
      let target = restPosition(v.square)
      switch army.strike {
      case .lightning: lightning(to: target + [0, 0.7, 0], color: army.strikeColor)
      case .beam: beam(at: target, color: army.strikeColor)
      case .meteor: break
      }
      shatter(v.entity, piece: v.piece, at: target, color: army.strikeColor)
      f.victim = nil
    }
    if p >= 1, !f.landed {
      f.landed = true
      ripples.append(Ripple(center: [b.x, b.z], born: time, strength: 0.08))
      shake = max(shake, 0.06)
    }
  }

  private func spawn(_ e: Entity, _ kind: FxKind, life: Float) {
    root.addChild(e)
    fx.append(Fx(entity: e, kind: kind, born: time, life: life))
  }

  private func unlit(_ hex: UInt32, _ alpha: Float = 1) -> UnlitMaterial {
    alpha < 1 ? Arena.glow(hex, alpha) : UnlitMaterial(color: NSColor(hex: hex))
  }

  private func lightning(to target: SIMD3<Float>, color: UInt32) {
    var core = MeshBuilder()
    var glow = MeshBuilder()
    func bolt(from start: SIMD3<Float>, to end: SIMD3<Float>, steps: Int, jag: Float, width: Float) {
      var prev = start
      for i in 1...steps {
        let t = Float(i) / Float(steps)
        var next = simd_mix(start, end, SIMD3(repeating: t))
        if i < steps { next += [rng.float(-jag, jag), rng.float(-jag, jag) * 0.3, rng.float(-jag, jag)] * (1 - t * 0.5) }
        let seg = next - prev
        let q = simd_quatf(from: [0, 1, 0], to: normalize(seg))
        var m = float4x4(q)
        m.columns.3 = SIMD4((prev + next) / 2, 1)
        core.addBox([width, length(seg) + width, width], transform: m)
        glow.addBox([width * 4, length(seg) + width, width * 4], transform: m)
        prev = next
      }
    }
    let top = target + [rng.float(-2, 2), 12, rng.float(-2, 2)]
    bolt(from: top, to: target, steps: 16, jag: 0.5, width: 0.05)
    for _ in 0..<3 {
      let t = rng.float(0.2, 0.7)
      let start = simd_mix(top, target, SIMD3(repeating: t))
      bolt(
        from: start, to: start + [rng.float(-1.6, 1.6), -rng.float(1, 2.5), rng.float(-1.6, 1.6)], steps: 5, jag: 0.3,
        width: 0.03)
    }
    let e = Entity()
    e.addChild(ModelEntity(mesh: core.mesh(), materials: [unlit(0xFFFFFF)]))
    e.addChild(ModelEntity(mesh: glow.mesh(), materials: [unlit(color, 0.45)]))
    spawn(e, .flicker, life: 0.45)
    flash(at: target + [0, 1, 0], color: color, peak: 600_000)
  }

  private func beam(at target: SIMD3<Float>, color: UInt32) {
    var core = MeshBuilder()
    core.addRod(radius: 0.09, from: 0, to: 16, transform: matrix_identity_float4x4)
    var glow = MeshBuilder()
    glow.addRod(radius: 0.38, from: 0, to: 16, transform: matrix_identity_float4x4)
    let e = Entity()
    e.addChild(ModelEntity(mesh: core.mesh(), materials: [unlit(0xFFFFFF)]))
    e.addChild(ModelEntity(mesh: glow.mesh(), materials: [unlit(color, 0.4)]))
    e.position = target
    spawn(e, .beam, life: 0.6)
    flash(at: target + [0, 1, 0], color: color, peak: 600_000)
  }

  private func meteor(to target: SIMD3<Float>, color: UInt32, life: Float) {
    let e = Entity()
    e.addChild(ModelEntity(mesh: .generateSphere(radius: 0.2), materials: [unlit(0xFFF2C0)]))
    e.addChild(ModelEntity(mesh: .generateSphere(radius: 0.42), materials: [unlit(color, 0.5)]))
    e.addChild(ModelEntity(mesh: .generateSphere(radius: 0.75), materials: [unlit(color, 0.18)]))
    let from = target + [rng.float(2, 4), 10, rng.float(-4, -2)]
    e.position = from
    spawn(e, .meteor(from, target), life: life)
    let light = PointLight()
    light.light.color = NSColor(hex: color)
    light.light.intensity = 120_000
    light.light.attenuationRadius = 5
    e.addChild(light)
  }

  private func ring(at pos: SIMD3<Float>, color: UInt32, size: Float) {
    let e = ModelEntity(mesh: ringMesh, materials: [unlit(color, 0.85)])
    e.position = pos + [0, 0.05, 0]
    spawn(e, .ring(size), life: 0.7)
  }

  private func flash(at pos: SIMD3<Float>, color: UInt32, peak: Float) {
    let light = PointLight()
    light.light.color = NSColor(hex: color)
    light.light.intensity = 0
    light.light.attenuationRadius = 8
    light.position = pos
    spawn(light, .flash(peak), life: 0.6)
  }

  private func shatter(_ victim: Entity, piece: Piece, at pos: SIMD3<Float>, color: UInt32) {
    victim.removeFromParent()
    let look = factory.looks[piece.side]!
    for i in 0..<30 {
      let chunk = ModelEntity(
        mesh: factory.rubbleMeshes[i % factory.rubbleMeshes.count], materials: [i % 6 == 0 ? look.accent : look.body])
      let a = rng.float(0, 2 * .pi)
      chunk.position = pos + [0.15 * cos(a), rng.float(0.05, 1.1), 0.15 * sin(a)]
      let speed = rng.float(1.4, 4.5)
      spawn(
        chunk,
        .rubble(
          [speed * cos(a), rng.float(2, 6.5), speed * sin(a)],
          normalize([rng.float(-1, 1), rng.float(-1, 1), rng.float(-1, 1)]), rng.float(4, 14)),
        life: rng.float(1.3, 2.2))
    }
    for _ in 0..<9 {
      let puff = ModelEntity(mesh: dustMesh, materials: [unlit(piece.side == .white ? 0xD8D0C0 : 0x5A5560, 0.35)])
      let a = rng.float(0, 2 * .pi)
      puff.position = pos + [0.2 * cos(a), rng.float(0.1, 0.6), 0.2 * sin(a)]
      spawn(puff, .dust([0.9 * cos(a), rng.float(0.3, 1), 0.9 * sin(a)]), life: rng.float(1, 1.6))
    }
    ring(at: pos, color: color, size: 3.2)
    ripples.append(Ripple(center: [pos.x, pos.z], born: time, strength: 0.32))
    flash(at: pos + [0, 0.6, 0], color: color, peak: 400_000)
    shake = 0.3
  }

  private func advanceFx(_ dt: Float) {
    fx.removeAll { f in
      guard time - f.born <= f.life else {
        f.entity.removeFromParent()
        return true
      }
      return false
    }
    for i in fx.indices {
      let e = fx[i].entity
      let age = time - fx[i].born
      let k = age / fx[i].life
      switch fx[i].kind {
      case .flicker:
        e.components.set(OpacityComponent(opacity: rng.float(0, 1) < 0.25 ? 0.15 : 1 - k * 0.6))
      case .beam:
        let w = max(0.05, 1 - k)
        e.scale = [w, 1, w]
        e.components.set(OpacityComponent(opacity: 1 - k))
      case .ring(let size):
        e.scale = SIMD3(repeating: 0.2 + size * Self.ease(min(1, k * 1.3)))
        e.components.set(OpacityComponent(opacity: 1 - k))
      case .dust(let v):
        e.position += v * dt * (1 - k)
        e.scale = SIMD3(repeating: 1 + 2.5 * k)
        e.components.set(OpacityComponent(opacity: 1 - k))
      case .rubble(var v, let axis, let rate):
        v.y -= 9.8 * dt
        var p = e.position + v * dt
        if p.y < -0.05 && abs(p.x) < 4 && abs(p.z) < 4 {
          p.y = -0.05
          v *= SIMD3(0.6, -0.35, 0.6)
        }
        e.position = p
        e.orientation = simd_quatf(angle: rate * dt, axis: axis) * e.orientation
        e.scale = SIMD3(repeating: min(1, (fx[i].life - age) / 0.45))
        fx[i].kind = .rubble(v, axis, rate)
      case .flash(let peak):
        (e as? PointLight)?.light.intensity = peak * max(0, 1 - k) * min(1, age * 30)
      case .meteor(let from, let to):
        e.position = simd_mix(from, to, SIMD3(repeating: k * k))
        e.scale = SIMD3(repeating: 0.8 + 0.4 * k)
      }
    }
  }

  private func updateCamera(_ dt: Float) {
    shownYaw += (yaw + targetFlip - shownYaw) * min(1, dt * 6)
    shake = max(0, shake - dt * 0.6)
    let jitter = shake > 0 ? SIMD3<Float>(sin(time * 61), sin(time * 47), sin(time * 53)) * shake * 0.35 : .zero
    let eye = SIMD3<Float>(
      distance * cos(pitch) * sin(shownYaw), distance * sin(pitch), distance * cos(pitch) * cos(shownYaw))
    camera.look(at: [0, -0.2, 0] + jitter * 0.4, from: eye + jitter, relativeTo: nil)
  }

  func square(alongRay origin: SIMD3<Float>, _ direction: SIMD3<Float>) -> Square? {
    guard direction.y < -1e-4 else { return nil }
    let hit = origin + direction * (-origin.y / direction.y)
    let file = Int((hit.x + 4).rounded(.down))
    let rank = Int((4 - hit.z).rounded(.down))
    guard (0..<8).contains(file), (0..<8).contains(rank) else { return nil }
    return squareAt(file, rank)
  }
}

struct SplitMix {
  private var state: UInt64
  init(seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  mutating func float(_ lo: Float, _ hi: Float) -> Float {
    lo + (hi - lo) * Float(next() >> 40) / Float(1 << 24)
  }
}

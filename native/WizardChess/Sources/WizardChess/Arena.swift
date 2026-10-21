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
  let mated: Square?
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
  var charged = false
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
  case decal(spin: Float, from: Float, to: Float, peak: Float)
  case orbit(Entity, phase: Float)
  case dissolve(drift: SIMD3<Float>)
  case soul
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
  private var slowmo: Float = 0
  private var focus: SIMD3<Float> = .zero
  private var focusHold: Float = 0
  private var shownFocus: Float = 0
  private var rng = SplitMix(seed: 0xD1CE)
  private let backdrop = ModelEntity(mesh: .generatePlane(width: 250, height: 141))
  private let skyFlash = ModelEntity(mesh: .generatePlane(width: 250, height: 141), materials: [Arena.glow(0xFFFFFF, 1)])
  private let abyss = ModelEntity(mesh: .generatePlane(width: 70, depth: 70))
  private var world: World
  private let selectionSigil = ModelEntity(mesh: .generatePlane(width: 1.25, depth: 1.25))
  private var auraLit: Entity?
  private var ghosts: [String: Entity] = [:]
  private var mated: Square?
  private var finaleWinner: Side?
  private var introT: Float = 0
  private var nextCrackle: Float = 0
  private var nextFlash: Float = 4
  private var flashLeft: Float = 0
  private let decalMesh = MeshResource.generatePlane(width: 1, depth: 1)
  private let sun = DirectionalLight()
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
    world = World(saga: saga)
    root.addChild(world.root)
    abyss.position.y = -3.2
    root.addChild(abyss)
    var ring = MeshBuilder()
    ring.addSmoothLathe([[1, 0.02], [0.8, 0.02]], segments: 48)
    ringMesh = ring.mesh()
    var seed = SplitMix(seed: 0x5EED_CAFE)
    buildSky(&seed)
    buildBoard(&seed)
    buildLights()
    camera.camera.fieldOfViewInDegrees = 38
    camera.camera.far = 400
    backdrop.position = [0, 0, -150]
    camera.addChild(backdrop)
    skyFlash.position = [0, 0, -149]
    skyFlash.components.set(OpacityComponent(opacity: 0))
    camera.addChild(skyFlash)
    root.addChild(camera)
    selectionSigil.isEnabled = false
    root.addChild(selectionSigil)
    applySagaLook()
  }

  private func sigilMaterial(_ side: Side) -> UnlitMaterial {
    var m = UnlitMaterial(texture: Art.sigil(saga, side))
    m.color.tint = .white
    m.blending = .transparent(opacity: 1.0)
    return m
  }

  private func decal(_ side: Side, size: Float) -> ModelEntity {
    let e = ModelEntity(mesh: decalMesh, materials: [sigilMaterial(side)])
    e.scale = SIMD3(repeating: size)
    e.components.set(OpacityComponent(opacity: 0))
    return e
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
    root.addChild(ModelEntity(mesh: stars.mesh(), materials: [Arena.glow(0xFFF4D6, 0.7)]))
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
    let light = Stone.tileMaterial(tint: saga.lightSquare, roughness: 0.55)
    let dark = Stone.tileMaterial(tint: saga.darkSquare, roughness: 0.7)
    for sq in 0..<64 {
      stones[sq].model?.materials = [(fileOf(sq) + rankOf(sq)) % 2 == 1 ? light : dark]
    }
    backdrop.model?.materials = [Art.backdropMaterial(saga)]
    let a = saga.abyss
    abyss.model?.materials = [Wizardry.abyss(style: a.style, speed: a.speed, dark: a.dark, bright: a.bright)]
    world.root.removeFromParent()
    world = World(saga: saga)
    root.addChild(world.root)
    for g in ghosts.values { g.removeFromParent() }
    ghosts.removeAll()
    introT = 0
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
    if s.mated != mated {
      mated = s.mated
      finaleWinner = nil
      if let sq = mated, let king = actors.removeValue(forKey: sq) { finale(king, at: sq) }
    }
    if !actorsMatch(s.position) { rebuild(s.position) }
    syncGhosts(s.position)
    let lit = s.selected.flatMap { actors[$0]?.entity }
    if lit !== auraLit {
      if let old = auraLit { Wizardry.set(old, dissolve: 0, aura: Wizardry.idleAura) }
      auraLit = lit
    }
    if let sel = s.selected, let piece = s.position[sel] {
      selectionSigil.model?.materials = [sigilMaterial(piece.side)]
      selectionSigil.isEnabled = true
    } else {
      selectionSigil.isEnabled = false
    }
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
    for sq in 0..<64 where sq != mated && actors[sq]?.piece != p[sq] { return false }
    return true
  }

  private func finale(_ king: Actor, at sq: Square) {
    let loser = king.piece.side
    let winner: Side = loser == .white ? .black : .white
    finaleWinner = winner
    let color = saga.army(winner).strikeColor
    let pos = restPosition(sq)
    spawn(king.entity, .dissolve(drift: [0, 0.3, 0]), life: 4.5)
    let ghost = factory.makeEntity(king.piece)
    Wizardry.paint(ghost, unlit(saga.army(loser).strikeColor, 0.3))
    ghost.position = pos
    spawn(ghost, .soul, life: 5)
    for i in 0..<3 {
      let r = ModelEntity(mesh: ringMesh, materials: [unlit(color, 0.8)])
      r.position = pos + [0, 0.08 + Float(i) * 0.5, 0]
      spawn(r, .ring(5 + Float(i) * 2), life: 1.6 + Float(i) * 0.4)
    }
    flash(at: pos + [0, 1.5, 0], color: color, peak: 900_000)
    ripples.append(Ripple(center: [pos.x, pos.z], born: time, strength: 0.5))
    slowmo = 1.2
    focus = pos
    focusHold = 4
    shake = 0.45
    nextFlash = time
  }

  private func syncGhosts(_ p: Position) {
    var fallen: [Side: [Role: Int]] = [.white: [:], .black: [:]]
    let full: [Role: Int] = [.pawn: 8, .knight: 2, .bishop: 2, .rook: 2, .queen: 1, .king: 1]
    for side in [Side.white, .black] { fallen[side] = full }
    for sq in 0..<64 {
      guard let piece = p[sq] else { continue }
      fallen[piece.side]![piece.role, default: 0] -= 1
    }
    var wanted: [String: (Piece, Int)] = [:]
    for side in [Side.white, .black] {
      var slot = 0
      for role in [Role.queen, .rook, .bishop, .knight, .pawn] {
        for n in 0..<max(0, fallen[side]![role] ?? 0) {
          wanted["\(side)-\(role)-\(n)"] = (Piece(side, role), slot)
          slot += 1
        }
      }
    }
    for (key, g) in ghosts where wanted[key] == nil {
      g.removeFromParent()
      ghosts[key] = nil
    }
    for (key, (piece, slot)) in wanted where ghosts[key] == nil {
      let g = factory.makeEntity(piece)
      g.name = "ghost"
      Wizardry.paint(g, unlit(saga.army(piece.side).strikeColor, 0.5))
      g.position = [piece.side == .white ? 5.4 : -5.4, 0.25, -3.6 + Float(slot) * 0.5]
      g.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
      root.addChild(g)
      ghosts[key] = g
    }
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
    for sq in 0..<64 where sq != mated {
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
    if victim != nil {
      let mid = (squareCenter(e.move.from) + squareCenter(e.move.to)) / 2
      let charge = decal(mover.piece.side, size: 0.3)
      charge.position = mid + [0, 0.13, 0]
      spawn(charge, .decal(spin: 2.4, from: 0.3, to: 2.2, peak: 0.95), life: 0.62 * flight.duration)
    }
    if let r = e.rook, let rook = actors.removeValue(forKey: r.from) {
      actors[r.to] = rook
      flights.append(
        Flight(actor: rook, from: r.from, to: r.to, start: time + 0.15, duration: 0.6, arc: 0.9, spin: .pi))
    }
  }

  var isBusy: Bool { !flights.isEmpty || fx.contains { $0.life < 3 } }

  func tick(_ realDt: Float) {
    let dt = slowmo > 0 ? realDt * 0.22 : realDt
    slowmo -= realDt
    time += dt
    ripples.removeAll { time - $0.born > 2.5 }
    if let sel = snapshot?.selected, selectionSigil.isEnabled {
      selectionSigil.position = squareCenter(sel) + [0, bob(sel) + 0.012, 0]
      selectionSigil.orientation = simd_quatf(angle: time * 0.8, axis: [0, 1, 0])
      selectionSigil.components.set(OpacityComponent(opacity: 0.75 + 0.25 * sin(time * 4)))
    }
    if let lit = auraLit { Wizardry.set(lit, dissolve: 0, aura: 0.55 + 0.35 * sin(time * 5)) }
    for sq in 0..<64 {
      slabs[sq].position.y = bob(sq)
      crystals[sq].position.y = 0.55 + 0.06 * sin(time * 3 + Float(sq))
      crystals[sq].orientation = simd_quatf(angle: time * 1.6, axis: [0, 1, 0])
      if sq == snapshot?.check, glows[sq].isEnabled {
        glows[sq].scale = SIMD3(repeating: 0.9 + 0.12 * sin(time * 8))
      }
    }
    for (sq, a) in actors where !flights.contains(where: { $0.actor === a }) {
      let lift: Float = a.entity === auraLit ? 0.2 + 0.04 * sin(time * 5) : 0
      a.entity.position = restPosition(sq) + [0, lift, 0]
      a.entity.orientation = idle(a.piece, sq)
      a.entity.scale = .one
      if let w = finaleWinner, a.piece.side == w {
        Wizardry.set(a.entity, dissolve: 0, aura: 0.7 + 0.5 * sin(time * 3 + phases[sq]))
      }
    }
    for (key, g) in ghosts {
      let ph = Float(key.utf8.reduce(0) { $0 &+ Int($1) } % 60)
      g.position.y = 0.25 + 0.1 * sin(time * 0.7 + ph)
      g.orientation = simd_quatf(angle: .pi / 2 + 0.1 * sin(time * 0.5 + ph), axis: [0, 1, 0])
    }
    crackleIfChecked()
    flickerSky(dt)
    world.tick(time)
    advanceFlights()
    advanceFx(dt)
    updateCamera(realDt)
  }

  private func idle(_ piece: Piece, _ sq: Square) -> simd_quatf {
    let ph = phases[sq]
    let roll = simd_quatf(angle: 0.04 * sin(time * 0.9 + ph), axis: [0, 0, 1])
    switch piece.role {
    case .knight:
      let f: Float = (piece.side == .white ? 0 : .pi) + 0.9
      let rear = pow(max(0, sin(time * 0.45 + ph)), 10) * 0.32
      return simd_quatf(angle: rear, axis: [cos(f), 0, -sin(f)]) * roll
    case .king, .queen:
      return simd_quatf(angle: 0.16 * sin(time * 0.4 + ph), axis: [0, 1, 0]) * roll
    case .bishop:
      return simd_quatf(angle: 0.07 * sin(time * 0.8 + ph), axis: [1, 0, 0]) * roll
    case .pawn:
      return simd_quatf(angle: 0.08 * sin(time * 0.3 + ph), axis: [0, 1, 0]) * roll
    case .rook:
      return roll
    }
  }

  private func crackleIfChecked() {
    guard let c = snapshot?.check, actors[c] != nil, time > nextCrackle else { return }
    nextCrackle = time + rng.float(0.35, 0.9)
    let k = restPosition(c)
    for _ in 0..<2 {
      let a = rng.float(0, 2 * .pi), b = a + rng.float(1.5, 4)
      let p0 = k + [0.7 * cos(a), rng.float(0.2, 1.1), 0.7 * sin(a)]
      let p1 = k + [0.7 * cos(b), rng.float(0.2, 1.1), 0.7 * sin(b)]
      var core = MeshBuilder(), glow = MeshBuilder()
      bolt(from: p0, to: p1, steps: 6, jag: 0.18, width: 0.02, core: &core, glow: &glow)
      let e = Entity()
      e.addChild(ModelEntity(mesh: core.mesh(), materials: [unlit(0xFFFFFF)]))
      e.addChild(ModelEntity(mesh: glow.mesh(), materials: [unlit(0xFF2D55, 0.5)]))
      spawn(e, .flicker, life: 0.16)
    }
    flash(at: k + [0, 0.8, 0], color: 0xFF2D55, peak: 50_000)
  }

  private func flickerSky(_ dt: Float) {
    let stormy = saga.white.strike == .lightning || saga.black.strike == .lightning
    if time > nextFlash, stormy || finaleWinner != nil {
      flashLeft = rng.float(0.1, 0.28)
      nextFlash = time + (finaleWinner != nil ? rng.float(0.4, 1.2) : rng.float(3, 9))
    }
    flashLeft -= dt
    let on = flashLeft > 0 && rng.float(0, 1) < 0.7
    skyFlash.components.set(OpacityComponent(opacity: on ? rng.float(0.08, 0.3) : 0))
    sun.light.intensity = on ? 7000 : 3200
  }

  private static func facing(_ side: Side, toward d: SIMD3<Float>) -> simd_quatf {
    let yaw = side == .white ? atan2(d.x, d.z) : atan2(-d.x, -d.z)
    return simd_quatf(angle: yaw, axis: [0, 1, 0])
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
    let turn = Self.ease(min(1, p / 0.3)) * (p > 0.85 ? max(0, 1 - (p - 0.85) / 0.15) : 1)
    let face = simd_slerp(simd_quatf(angle: 0, axis: [0, 1, 0]), Self.facing(side, toward: b - a), turn)
    let titan: Float =
      p < 0.35 ? 0 : p < 0.62 ? Self.ease((p - 0.35) / 0.27) : p < 0.8 ? 1 : 1 - Self.ease((p - 0.8) / 0.2)
    f.actor.entity.scale = SIMD3(repeating: 1 + 0.45 * titan)
    f.actor.entity.position = pos
    f.actor.entity.orientation = simd_quatf(angle: lean, axis: axis) * face
    let aura = p < 0.62 ? Wizardry.idleAura + (1.4 - Wizardry.idleAura) * Self.ease(p / 0.62) : max(Wizardry.idleAura, 1.4 * (1 - (p - 0.62) / 0.38))
    Wizardry.set(f.actor.entity, dissolve: 0, aura: aura)

    if let v = f.victim {
      let fear = min(1, max(0, (p - 0.25) / 0.35))
      let jitter = SIMD3<Float>(sin(time * 71), 0, cos(time * 59)) * 0.035 * fear
      v.entity.position = restPosition(v.square) + jitter + [0, 0.05 * fear, 0]
      v.entity.orientation =
        simd_quatf(angle: -0.18 * fear, axis: axis)
        * simd_slerp(simd_quatf(angle: 0, axis: [0, 1, 0]), Self.facing(v.piece.side, toward: a - b), Self.ease(fear))
      Wizardry.set(v.entity, dissolve: 0, aura: Wizardry.idleAura + 0.5 * fear)
    }
    if p >= 0.35, !f.charged {
      f.charged = true
      var gem = MeshBuilder()
      gem.addCrystal(radius: 0.06, height: 0.2, at: .zero, sides: 4)
      let mesh = gem.mesh()
      for i in 0..<7 {
        let c = ModelEntity(mesh: mesh, materials: [unlit(i % 2 == 0 ? 0xFFFFFF : army.strikeColor)])
        spawn(c, .orbit(f.actor.entity, phase: Float(i) / 7 * 2 * .pi), life: 0.27 * f.duration)
      }
    }

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
      shatter(v.entity, piece: v.piece, at: target, color: army.strikeColor, push: normalize(b - a + [0, 0.001, 0]))
      let scorch = decal(side, size: 1.15)
      scorch.position.y = 0.014
      spawn(scorch, .decal(spin: 0.25, from: 1.6, to: 1.05, peak: 1), life: 8, parent: slabs[v.square])
      slowmo = 0.45
      focus = target
      focusHold = 0.9
      f.victim = nil
    }
    if p >= 1, !f.landed {
      f.landed = true
      ripples.append(Ripple(center: [b.x, b.z], born: time, strength: 0.08))
      shake = max(shake, 0.06)
    }
  }

  private func spawn(_ e: Entity, _ kind: FxKind, life: Float, parent: Entity? = nil) {
    (parent ?? root).addChild(e)
    fx.append(Fx(entity: e, kind: kind, born: time, life: life))
  }

  private func unlit(_ hex: UInt32, _ alpha: Float = 1) -> UnlitMaterial {
    alpha < 1 ? Arena.glow(hex, alpha) : UnlitMaterial(color: NSColor(hex: hex))
  }

  private func bolt(
    from start: SIMD3<Float>, to end: SIMD3<Float>, steps: Int, jag: Float, width: Float,
    core: inout MeshBuilder, glow: inout MeshBuilder
  ) {
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

  private func lightning(to target: SIMD3<Float>, color: UInt32) {
    var core = MeshBuilder()
    var glow = MeshBuilder()
    let top = target + [rng.float(-2, 2), 12, rng.float(-2, 2)]
    bolt(from: top, to: target, steps: 16, jag: 0.5, width: 0.05, core: &core, glow: &glow)
    for _ in 0..<3 {
      let t = rng.float(0.2, 0.7)
      let start = simd_mix(top, target, SIMD3(repeating: t))
      bolt(
        from: start, to: start + [rng.float(-1.6, 1.6), -rng.float(1, 2.5), rng.float(-1.6, 1.6)], steps: 5, jag: 0.3,
        width: 0.03, core: &core, glow: &glow)
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

  private func shatter(_ victim: Entity, piece: Piece, at pos: SIMD3<Float>, color: UInt32, push: SIMD3<Float>) {
    victim.removeFromParent()
    spawn(victim, .dissolve(drift: push * 0.9 + [0, 0.25, 0]), life: 0.8)
    let ghost = factory.makeEntity(piece)
    ghost.name = "soul"
    Wizardry.paint(ghost, unlit(saga.army(piece.side).strikeColor, 0.3))
    ghost.position = pos
    spawn(ghost, .soul, life: 2.2)
    var spark = MeshBuilder()
    spark.addCrystal(radius: 0.025, height: 0.16, at: .zero, sides: 3)
    let sparkMesh = spark.mesh()
    for i in 0..<26 {
      let s = ModelEntity(mesh: sparkMesh, materials: [unlit(i % 3 == 0 ? 0xFFFFFF : color)])
      let a = rng.float(0, 2 * .pi)
      s.position = pos + [0, rng.float(0.3, 0.9), 0]
      let speed = rng.float(3, 7)
      spawn(
        s, .rubble([speed * cos(a), rng.float(1.5, 6), speed * sin(a)], [0, 1, 0], rng.float(10, 20)),
        life: rng.float(0.45, 0.85))
    }
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
      case .decal(let spin, let from, let to, let peak):
        e.scale = SIMD3(repeating: from + (to - from) * Self.ease(min(1, k * 1.6)))
        e.orientation = simd_quatf(angle: spin * age, axis: [0, 1, 0])
        e.components.set(OpacityComponent(opacity: peak * min(1, age * 4) * min(1, (1 - k) * 4)))
      case .orbit(let anchor, let phase):
        let a = phase + age * 7
        let r = 0.85 - 0.45 * k
        e.position = anchor.position(relativeTo: root) + [r * cos(a), 0.5 + 0.5 * k + 0.12 * sin(a * 2), r * sin(a)]
        e.orientation = simd_quatf(angle: a * 2, axis: [0, 1, 0])
        e.scale = SIMD3(repeating: min(1, age * 5))
      case .dissolve(let drift):
        e.position += drift * dt * (1 - k)
        Wizardry.set(e, dissolve: min(1, k * 1.15), aura: 1.6)
      case .soul:
        e.position.y += 1.1 * dt
        e.scale = SIMD3(repeating: 1 + 0.35 * k)
        e.orientation = simd_quatf(angle: 0.8 * age, axis: [0, 1, 0])
        e.components.set(OpacityComponent(opacity: min(1, age * 3) * (1 - k)))
      }
    }
  }

  private func updateCamera(_ dt: Float) {
    shownYaw += (yaw + targetFlip - shownYaw) * min(1, dt * 6)
    shake = max(0, shake - dt * 0.6)
    let jitter = shake > 0 ? SIMD3<Float>(sin(time * 61), sin(time * 47), sin(time * 53)) * shake * 0.35 : .zero
    focusHold -= dt
    shownFocus += ((focusHold > 0 ? 1 : 0) - shownFocus) * min(1, dt * (focusHold > 0 ? 7 : 1.6))
    introT += dt
    let intro = Self.ease(min(1, introT / 3.2))
    let center = simd_mix(SIMD3<Float>(0, -0.2, 0), focus, SIMD3(repeating: 0.5 * shownFocus))
    let reach = simd_mix(22, distance, intro) * (1 - 0.22 * shownFocus)
    let tilt = simd_mix(0.16, pitch, intro)
    let spin = shownYaw + (1 - intro) * 1.7
    let eye = center + SIMD3<Float>(reach * cos(tilt) * sin(spin), reach * sin(tilt), reach * cos(tilt) * cos(spin))
    camera.look(at: center + jitter * 0.4, from: eye + jitter, relativeTo: nil)
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

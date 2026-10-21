import AppKit
import Metal
import OSLog
import RealityKit

enum Wizardry {
  static let idleAura: Float = 0.12
  private static let log = Logger(subsystem: "dev.chessgo.wizardchess", category: "shader")

  private static let surface: CustomMaterial.SurfaceShader? = {
    guard let device = MTLCreateSystemDefaultDevice(),
      let library = try? device.makeDefaultLibrary(bundle: .module)
    else {
      log.error("wizardSurface shader library is unavailable; pieces use plain stone")
      return nil
    }
    return CustomMaterial.SurfaceShader(named: "wizardSurface", in: library)
  }()

  static func enchant(_ stone: PhysicallyBasedMaterial, glow: UInt32) -> any RealityKit.Material {
    guard let surface, var m = try? CustomMaterial(from: stone, surfaceShader: surface) else { return stone }
    m.emissiveColor = .init(color: NSColor(hex: glow))
    m.custom.value = [0, idleAura, 0, 0]
    return m
  }

  static func set(_ entity: Entity, dissolve: Float, aura: Float) {
    if let model = entity as? ModelEntity, var m = model.model?.materials.first as? CustomMaterial {
      m.custom.value = [dissolve, aura, 0, 0]
      model.model?.materials = [m]
    }
    for child in entity.children { set(child, dissolve: dissolve, aura: aura) }
  }

  static func paint(_ entity: Entity, _ material: any RealityKit.Material) {
    if let model = entity as? ModelEntity { model.model?.materials = [material] }
    for child in entity.children { paint(child, material) }
  }
}

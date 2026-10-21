import AppKit
import ChessCore
import Combine
import RealityKit
import SwiftUI

final class ArenaView: ARView {
  let arena = Arena(saga: .olympus)
  var onTapSquare: ((Square) -> Void)?
  private var updates: (any Cancellable)?
  private var downPoint: CGPoint?
  private var dragged = false

  required init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let anchor = AnchorEntity(world: .zero)
    anchor.addChild(arena.root)
    scene.addAnchor(anchor)
    updates = scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
      let dt = Float(event.deltaTime)
      MainActor.assumeIsolated { self?.arena.tick(dt) }
    }
  }

  @available(*, unavailable)
  required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  private func viewPoint(_ event: NSEvent) -> CGPoint {
    convert(event.locationInWindow, from: nil)
  }

  override func mouseDown(with event: NSEvent) {
    downPoint = viewPoint(event)
    dragged = false
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start = downPoint else { return }
    let p = viewPoint(event)
    if hypot(p.x - start.x, p.y - start.y) > 4 { dragged = true }
    guard dragged else { return }
    arena.yaw -= Float(event.deltaX) * 0.008
    arena.pitch = min(1.4, max(0.22, arena.pitch + Float(event.deltaY) * 0.006))
  }

  override func mouseUp(with event: NSEvent) {
    defer { downPoint = nil }
    guard !dragged, let ray = ray(through: viewPoint(event)),
      let sq = arena.square(alongRay: ray.origin, ray.direction)
    else { return }
    onTapSquare?(sq)
  }

  override func scrollWheel(with event: NSEvent) {
    arena.distance = min(20, max(6.5, arena.distance * exp(Float(event.scrollingDeltaY) * -0.01)))
  }

  override func magnify(with event: NSEvent) {
    arena.distance = min(20, max(6.5, arena.distance / (1 + Float(event.magnification))))
  }
}

struct BoardView: NSViewRepresentable {
  let model: GameModel

  func makeNSView(context: Context) -> ArenaView {
    let view = ArenaView(frame: .zero)
    view.onTapSquare = { [model] sq in model.tap(sq) }
    return view
  }

  func updateNSView(_ view: ArenaView, context: Context) {
    view.environment.background = .color(NSColor(hex: model.saga.sky))
    view.arena.sync(
      BoardSnapshot(
        position: model.position, selected: model.selected, hints: model.hints,
        lastMove: model.game.lastMove, check: model.checkSquare, flipped: model.flipped,
        effect: model.effect, saga: model.saga))
  }
}

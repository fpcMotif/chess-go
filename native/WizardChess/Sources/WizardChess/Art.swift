import AVFoundation
import AppKit
import ChessCore
import RealityKit

enum Art {
  private static var loopers: [String: AVPlayerLooper] = [:]
  private static var sigils: [String: TextureResource] = [:]
  private static var tiles: (TextureResource, TextureResource)?

  private static let generated = [
    "backdrop_olympus": "Gemini_Generated_Image_ws1nelws1nelws1n",
    "backdrop_ragnarok": "Gemini_Generated_Image_w46aocw46aocw46a",
    "backdrop_duat": "Gemini_Generated_Image_2yvbsn2yvbsn2yvb",
    "sigil_olympus": "Gemini_Generated_Image_ok2ft8ok2ft8ok2f",
    "sigil_ragnarok": "Gemini_Generated_Image_qbd8pkqbd8pkqbd8",
    "tile": "Gemini_Generated_Image_2jpckn2jpckn2jpc",
  ]

  private static func url(_ name: String, _ exts: [String]) -> URL? {
    [name, generated[name]].lazy.compactMap { $0 }.flatMap { file in
      exts.lazy.compactMap { Bundle.module.url(forResource: file, withExtension: $0) }
    }.first
  }

  static func backdropMaterial(_ saga: Saga) -> any RealityKit.Material {
    let name = "backdrop_\(saga.id)"
    if let video = url(name, ["mp4", "mov", "m4v"]) {
      let player = AVQueuePlayer()
      player.isMuted = true
      loopers[saga.id] = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: video))
      player.play()
      return VideoMaterial(avPlayer: player)
    }
    let image = url(name, ["png", "jpg", "jpeg", "webp"]).flatMap { NSImage(contentsOf: $0)?.cgImage }
      ?? paintBackdrop(saga)
    var m = UnlitMaterial(texture: texture(image, .color))
    m.color.tint = .white
    return m
  }

  static func sigil(_ saga: Saga, _ side: Side) -> TextureResource {
    let key = "\(saga.id)-\(side)"
    if let hit = sigils[key] { return hit }
    let tint = saga.army(side).strikeColor
    let made: TextureResource
    if let file = url("sigil_\(saga.id)", ["png", "jpg", "jpeg", "webp"]),
      let image = NSImage(contentsOf: file)?.cgImage
    {
      made = texture(glowToAlpha(image, tint: tint), .color)
    } else {
      made = texture(paintSigil(saga, tint: tint), .color)
    }
    sigils[key] = made
    return made
  }

  static func tile() -> (color: TextureResource, normal: TextureResource) {
    if let tiles { return tiles }
    let size = 512
    let made: (TextureResource, TextureResource)
    if let file = url("tile", ["png", "jpg", "jpeg", "webp"]), let image = NSImage(contentsOf: file)?.cgImage {
      made = (texture(image, .color), Stone.textures(height: gray(image, size: size), size: size, relief: 3).1)
    } else {
      made = Stone.textures(height: engravedTile(size: size), size: size, relief: 4)
    }
    tiles = made
    return made
  }

  static func texture(_ image: CGImage, _ semantic: TextureResource.Semantic) -> TextureResource {
    try! TextureResource(image: image, options: .init(semantic: semantic))
  }

  private static func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(
      data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  }

  private static func cg(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    NSColor(hex: hex, alpha: alpha).cgColor
  }

  private static func gray(_ image: CGImage, size: Int) -> [Float] {
    let ctx = context(size, size)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    let px = ctx.data!.bindMemory(to: UInt8.self, capacity: size * size * 4)
    return (0..<(size * size)).map { i in
      (Float(px[i * 4]) * 0.3 + Float(px[i * 4 + 1]) * 0.59 + Float(px[i * 4 + 2]) * 0.11) / 255
    }
  }

  private static func glowToAlpha(_ image: CGImage, tint: UInt32) -> CGImage {
    let size = 1024
    let ctx = context(size, size)
    let side = min(image.width, image.height)
    let square = image.cropping(
      to: CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side))!
    ctx.draw(square, in: CGRect(x: 0, y: 0, width: size, height: size))
    let px = ctx.data!.bindMemory(to: UInt8.self, capacity: size * size * 4)
    for i in 0..<(size * size) {
      let peak = Float(max(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])) / 255
      let a = min(1, max(0, (peak - 0.28) / 0.5))
      for c in 0..<3 { px[i * 4 + c] = UInt8(Float(px[i * 4 + c]) * a) }
      px[i * 4 + 3] = UInt8(a * 255)
    }
    return ctx.makeImage()!
  }

  private static func paintBackdrop(_ saga: Saga) -> CGImage {
    let w = 2048, h = 1024
    let ctx = context(w, h)
    var rng = SplitMix(seed: UInt64(saga.id.utf8.reduce(7) { $0 &* 31 &+ UInt64($1) }))
    let sky = CGGradient(
      colorsSpace: nil,
      colors: [cg(saga.sky), cg(saga.sky), cg(saga.rim, 0.55), cg(saga.moon, 0.7)] as CFArray,
      locations: [0, 0.45, 0.8, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: Int(Double(h) * 0.28)), options: [])

    for _ in 0..<26 {
      let c = [saga.rim, saga.under, saga.moon, saga.white.strikeColor, saga.black.strikeColor][Int(rng.next() % 5)]
      let center = CGPoint(x: CGFloat(rng.float(0, Float(w))), y: CGFloat(rng.float(Float(h) * 0.35, Float(h))))
      let r = CGFloat(rng.float(80, 380))
      let g = CGGradient(colorsSpace: nil, colors: [cg(c, 0.16), cg(c, 0)] as CFArray, locations: [0, 1])!
      ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: [])
    }
    for _ in 0..<900 {
      let p = CGPoint(x: CGFloat(rng.float(0, Float(w))), y: CGFloat(rng.float(Float(h) * 0.3, Float(h))))
      let s = CGFloat(rng.float(0.6, 2.4))
      ctx.setFillColor(cg(0xFFF4D6, CGFloat(rng.float(0.3, 1))))
      ctx.fillEllipse(in: CGRect(x: p.x, y: p.y, width: s, height: s))
    }
    let moon = CGPoint(x: CGFloat(w) * 0.72, y: CGFloat(h) * 0.72)
    let halo = CGGradient(
      colorsSpace: nil, colors: [cg(saga.moon, 0.5), cg(saga.moon, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: moon, startRadius: 60, endCenter: moon, endRadius: 260, options: [])
    ctx.setFillColor(cg(saga.moon))
    ctx.fillEllipse(in: CGRect(x: moon.x - 70, y: moon.y - 70, width: 140, height: 140))

    let horizon = CGFloat(h) * 0.3
    for layer in 0..<3 {
      let shade = CGFloat(0.55 - Double(layer) * 0.2)
      ctx.setFillColor(NSColor(hex: saga.sky).blended(withFraction: 0.5, of: .black)!.withAlphaComponent(1 - shade * 0.4).cgColor)
      ctx.beginPath()
      ctx.move(to: CGPoint(x: 0, y: 0))
      var x: CGFloat = 0
      while x <= CGFloat(w) {
        let y = horizon - CGFloat(layer) * 40 + CGFloat(rng.float(-30, 90)) * (1 - CGFloat(layer) * 0.3)
        ctx.addLine(to: CGPoint(x: x, y: y))
        x += CGFloat(rng.float(40, 140))
      }
      ctx.addLine(to: CGPoint(x: CGFloat(w), y: 0))
      ctx.closePath()
      ctx.fillPath()
    }
    ctx.setFillColor(cg(0x05030A, 0.95))
    for _ in 0..<9 {
      let x = CGFloat(rng.float(60, Float(w) - 60))
      let base = horizon - 60
      let tall = CGFloat(rng.float(120, 320))
      switch saga.id {
      case "olympus":
        for c in 0..<Int(rng.float(2, 6)) {
          let cx = x + CGFloat(c) * 34
          let ht = tall * CGFloat(rng.float(0.5, 1))
          ctx.fill(CGRect(x: cx, y: base, width: 16, height: ht))
          ctx.fill(CGRect(x: cx - 5, y: base + ht, width: 26, height: 8))
        }
      case "ragnarok":
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: base))
        ctx.addLine(to: CGPoint(x: x + 16, y: base + tall))
        ctx.addLine(to: CGPoint(x: x + 52, y: base + tall * 0.92))
        ctx.addLine(to: CGPoint(x: x + 60, y: base))
        ctx.closePath()
        ctx.fillPath()
      default:
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x - tall * 0.8, y: base))
        ctx.addLine(to: CGPoint(x: x, y: base + tall * 0.9))
        ctx.addLine(to: CGPoint(x: x + tall * 0.8, y: base))
        ctx.closePath()
        ctx.fillPath()
      }
    }
    return ctx.makeImage()!
  }

  private static func paintSigil(_ saga: Saga, tint: UInt32) -> CGImage {
    let size = 1024
    let ctx = context(size, size)
    let c = CGPoint(x: size / 2, y: size / 2)
    ctx.setShadow(offset: .zero, blur: 18, color: cg(tint))
    ctx.setStrokeColor(cg(tint))
    ctx.setFillColor(cg(tint))
    for (r, w) in [(490.0, 10.0), (452.0, 3.0), (330.0, 6.0), (300.0, 2.0), (120.0, 5.0)] {
      ctx.setLineWidth(w)
      ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
    ctx.setLineWidth(5)
    let marks = 36
    for k in 0..<marks {
      let a = Double(k) / Double(marks) * 2 * .pi
      let r0 = 345.0, r1 = 440.0
      switch saga.id {
      case "olympus":
        let mid = (r0 + r1) / 2
        let p = CGPoint(x: c.x + mid * cos(a), y: c.y + mid * sin(a))
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: a)
        ctx.stroke(CGRect(x: -26, y: -26, width: 52, height: 52))
        ctx.stroke(CGRect(x: -12, y: -12, width: 24, height: 24))
        ctx.restoreGState()
      case "ragnarok":
        let p0 = CGPoint(x: c.x + r0 * cos(a), y: c.y + r0 * sin(a))
        let p1 = CGPoint(x: c.x + r1 * cos(a), y: c.y + r1 * sin(a))
        let b = a + (k.isMultiple(of: 2) ? 0.06 : -0.06)
        ctx.strokeLineSegments(between: [
          p0, p1, CGPoint(x: c.x + 400 * cos(a), y: c.y + 400 * sin(a)), CGPoint(x: c.x + 430 * cos(b), y: c.y + 430 * sin(b)),
        ])
      default:
        let p = CGPoint(x: c.x + 392 * cos(a), y: c.y + 392 * sin(a))
        ctx.fillEllipse(in: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18))
        ctx.strokeEllipse(in: CGRect(x: p.x - 24, y: p.y - 24, width: 48, height: 48))
      }
    }
    ctx.setLineWidth(12)
    switch saga.id {
    case "olympus":
      let bolt: [CGPoint] = [[-40, 230], [40, 30], [-20, 30], [60, -230], [-60, -10], [5, -10], [-70, 230]].map {
        CGPoint(x: c.x + $0[0], y: c.y + $0[1])
      }
      ctx.addLines(between: bolt)
      ctx.closePath()
      ctx.fillPath()
    case "ragnarok":
      for k in 0..<8 {
        let a = Double(k) / 8 * 2 * .pi
        let tip = CGPoint(x: c.x + 270 * cos(a), y: c.y + 270 * sin(a))
        ctx.strokeLineSegments(between: [c, tip])
        let fork = CGPoint(x: c.x + 210 * cos(a), y: c.y + 210 * sin(a))
        ctx.strokeLineSegments(between: [
          fork, CGPoint(x: fork.x + 50 * cos(a + 0.9), y: fork.y + 50 * sin(a + 0.9)),
          fork, CGPoint(x: fork.x + 50 * cos(a - 0.9), y: fork.y + 50 * sin(a - 0.9)),
        ])
      }
    default:
      let eye = CGMutablePath()
      eye.move(to: CGPoint(x: c.x - 250, y: c.y))
      eye.addQuadCurve(to: CGPoint(x: c.x + 250, y: c.y), control: CGPoint(x: c.x, y: c.y + 230))
      eye.addQuadCurve(to: CGPoint(x: c.x - 250, y: c.y), control: CGPoint(x: c.x, y: c.y - 230))
      ctx.addPath(eye)
      ctx.strokePath()
      ctx.fillEllipse(in: CGRect(x: c.x - 70, y: c.y - 70, width: 140, height: 140))
    }
    return ctx.makeImage()!
  }

  private static func engravedTile(size: Int) -> [Float] {
    let ctx = context(size, size)
    ctx.setFillColor(.white)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.setStrokeColor(cg(0x000000))
    ctx.setLineWidth(5)
    let inset: CGFloat = 26
    ctx.stroke(CGRect(x: inset, y: inset, width: CGFloat(size) - 2 * inset, height: CGFloat(size) - 2 * inset))
    ctx.setLineWidth(3)
    let step: CGFloat = 32
    var x = inset + 10
    while x < CGFloat(size) - inset - step {
      for y in [inset + 10, CGFloat(size) - inset - 26] {
        ctx.addLines(between: [
          CGPoint(x: x, y: y), CGPoint(x: x, y: y + 16), CGPoint(x: x + 16, y: y + 16), CGPoint(x: x + 16, y: y + 6),
          CGPoint(x: x + 8, y: y + 6), CGPoint(x: x + 8, y: y),
        ])
        ctx.addLines(between: [
          CGPoint(x: y, y: x), CGPoint(x: y + 16, y: x), CGPoint(x: y + 16, y: x + 16), CGPoint(x: y + 6, y: x + 16),
          CGPoint(x: y + 6, y: x + 8), CGPoint(x: y, y: x + 8),
        ])
      }
      x += step
    }
    ctx.strokePath()
    ctx.setLineWidth(4)
    let c = CGFloat(size) / 2
    ctx.strokeEllipse(in: CGRect(x: c - 60, y: c - 60, width: 120, height: 120))
    ctx.strokeEllipse(in: CGRect(x: c - 18, y: c - 18, width: 36, height: 36))
    let carved = gray(ctx.makeImage()!, size: size)
    let marble = Stone.heightField(.marble, size: size)
    return zip(carved, marble).map { $1 - (1 - $0) * 0.35 }
  }
}

extension NSImage {
  var cgImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }
}

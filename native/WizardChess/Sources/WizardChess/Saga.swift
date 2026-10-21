import ChessCore

enum StrikeStyle {
  case lightning, beam, meteor
}

struct Army {
  let name: String
  let stone: StoneKind
  let tint: UInt32
  let roughness: Float
  let accent: UInt32
  let accentIsMetal: Bool
  let strike: StrikeStyle
  let strikeColor: UInt32
}

struct Saga: Identifiable, Hashable {
  let id: String
  let title: String
  let tagline: String
  let white: Army
  let black: Army
  let sky: UInt32
  let moon: UInt32
  let rim: UInt32
  let under: UInt32
  let lightSquare: UInt32
  let darkSquare: UInt32

  func army(_ side: Side) -> Army { side == .white ? white : black }

  static func == (a: Saga, b: Saga) -> Bool { a.id == b.id }
  func hash(into h: inout Hasher) { h.combine(id) }

  static let olympus = Saga(
    id: "olympus", title: "Olympus", tagline: "The Titanomachy: Olympians against Titans",
    white: Army(
      name: "Olympians", stone: .marble, tint: 0xF2ECDF, roughness: 0.55, accent: 0xE0B04A, accentIsMetal: true,
      strike: .lightning, strikeColor: 0xFFF3C4),
    black: Army(
      name: "Titans", stone: .slate, tint: 0x46424E, roughness: 0.45, accent: 0xFF4A1C, accentIsMetal: false,
      strike: .lightning, strikeColor: 0xFF3B2F),
    sky: 0x12071F, moon: 0xBFE9DA, rim: 0xC03CFF, under: 0x28E0C0, lightSquare: 0xD8D0BE, darkSquare: 0x2A2B33)

  static let ragnarok = Saga(
    id: "ragnarok", title: "Ragnarök", tagline: "The twilight of the gods: Aesir against fire giants",
    white: Army(
      name: "Aesir", stone: .marble, tint: 0xDCE8F0, roughness: 0.35, accent: 0x8FE3FF, accentIsMetal: false,
      strike: .beam, strikeColor: 0xBFF4FF),
    black: Army(
      name: "Jötnar", stone: .slate, tint: 0x3A2A26, roughness: 0.6, accent: 0xFF7A1A, accentIsMetal: false,
      strike: .meteor, strikeColor: 0xFF6A10),
    sky: 0x03141A, moon: 0xE8F4FF, rim: 0x3CFFB0, under: 0xFF5A1F, lightSquare: 0xC9D6DC, darkSquare: 0x1F2226)

  static let duat = Saga(
    id: "duat", title: "Duat", tagline: "The weighing of the heart: Ra's court against Apep",
    white: Army(
      name: "Ra's court", stone: .marble, tint: 0xE9C98F, roughness: 0.7, accent: 0x2E5BFF, accentIsMetal: true,
      strike: .beam, strikeColor: 0xFFD25A),
    black: Army(
      name: "Serpents of Apep", stone: .slate, tint: 0x1E2A22, roughness: 0.3, accent: 0x5CFF6A,
      accentIsMetal: false, strike: .lightning, strikeColor: 0x7CFF4A),
    sky: 0x1A0B05, moon: 0xFFB347, rim: 0xFF8A3C, under: 0x3CFF8A, lightSquare: 0xD9B98A, darkSquare: 0x2B1E14)

  static let all = [olympus, ragnarok, duat]
}

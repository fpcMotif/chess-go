import AppKit
import ChessCore
import SwiftUI

@main
struct WizardChessApp: App {
  init() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate()
  }

  var body: some Scene {
    WindowGroup("Merlin's Chess") {
      ContentView()
        .frame(minWidth: 900, minHeight: 640)
    }
    .windowStyle(.hiddenTitleBar)
  }
}

private let ink = Color(red: 0.96, green: 0.91, blue: 0.78)
private let ember = Color(red: 1, green: 0.35, blue: 0.12)

struct ContentView: View {
  @State private var model = GameModel()

  var body: some View {
    ZStack {
      BoardView(model: model)
        .ignoresSafeArea()
      VStack(alignment: .leading, spacing: 0) {
        header
        Spacer()
        HStack(alignment: .bottom) {
          controls
          Spacer()
          MoveLog(sans: model.game.sanHistory)
        }
      }
      .padding(24)
      if let p = model.pendingPromotion {
        PromotionPicker(side: p.side) { model.choosePromotion($0) }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("MERLIN'S CHESS")
        .font(.system(size: 30, weight: .black, design: .serif))
        .tracking(6)
        .foregroundStyle(
          LinearGradient(colors: [ink, Color(red: 0.85, green: 0.66, blue: 0.23)], startPoint: .top, endPoint: .bottom))
      HStack(spacing: 8) {
        ForEach(Saga.all) { saga in
          Button(saga.title) { model.saga = saga }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .bold, design: .serif))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(model.saga == saga ? AnyShapeStyle(ink.opacity(0.9)) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
            .foregroundStyle(model.saga == saga ? Color.black : ink)
        }
      }
      Text(model.saga.tagline)
        .font(.system(size: 13, weight: .regular, design: .serif).italic())
        .foregroundStyle(ink.opacity(0.7))
      Text(model.status)
        .font(.system(size: 15, weight: .semibold, design: .monospaced))
        .foregroundStyle(model.position.isCheck ? ember : ink.opacity(0.85))
        .contentTransition(.numericText())
        .animation(.snappy, value: model.status)
    }
  }

  private var controls: some View {
    HStack(spacing: 10) {
      RuneButton(title: "Undo", symbol: "arrow.uturn.backward") { model.undo() }
        .disabled(model.game.moves.isEmpty)
      RuneButton(title: "Flip", symbol: "arrow.triangle.2.circlepath") { model.flipped.toggle() }
      RuneButton(title: "New game", symbol: "sparkles") { model.reset() }
      RuneButton(title: "Opera duel", symbol: "theatermasks") { model.replayOperaGame() }
    }
    .task {
      if let id = CommandLine.arguments.first(where: { $0.hasPrefix("--saga=") })?.dropFirst(7),
        let saga = Saga.all.first(where: { $0.id == id })
      {
        model.saga = saga
      }
      if CommandLine.arguments.contains("--demo") { model.replayOperaGame() }
    }
  }
}

private struct RuneButton: View {
  let title: String
  let symbol: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 13, weight: .semibold, design: .serif))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(ink.opacity(0.25)))
    }
    .buttonStyle(.plain)
    .foregroundStyle(ink)
  }
}

private struct MoveLog: View {
  let sans: [String]

  var body: some View {
    let rows = stride(from: 0, to: sans.count, by: 2).map { i in
      (i / 2 + 1, sans[i], i + 1 < sans.count ? sans[i + 1] : "")
    }
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 3) {
          ForEach(rows, id: \.0) { row in
            HStack(spacing: 10) {
              Text("\(row.0).").foregroundStyle(ink.opacity(0.45)).frame(width: 28, alignment: .trailing)
              Text(row.1).frame(width: 56, alignment: .leading)
              Text(row.2).frame(width: 56, alignment: .leading)
            }
            .id(row.0)
          }
        }
        .font(.system(size: 13, design: .monospaced).monospacedDigit())
        .foregroundStyle(ink)
        .padding(12)
      }
      .onChange(of: sans.count) { proxy.scrollTo(rows.last?.0) }
    }
    .frame(width: 190, height: min(220, CGFloat(rows.count) * 19 + 26))
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    .opacity(sans.isEmpty ? 0 : 1)
  }
}

private struct PromotionPicker: View {
  let side: Side
  let choose: (Role?) -> Void

  var body: some View {
    let glyphs: [(Role, String)] =
      side == .white
      ? [(.queen, "♕"), (.rook, "♖"), (.bishop, "♗"), (.knight, "♘")]
      : [(.queen, "♛"), (.rook, "♜"), (.bishop, "♝"), (.knight, "♞")]
    ZStack {
      Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { choose(nil) }
      VStack(spacing: 14) {
        Text("Ascend to")
          .font(.system(size: 18, weight: .bold, design: .serif))
          .foregroundStyle(ink)
        HStack(spacing: 12) {
          ForEach(glyphs, id: \.0) { role, glyph in
            Button { choose(role) } label: {
              Text(glyph).font(.system(size: 44)).frame(width: 72, height: 72)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ink)
          }
        }
      }
      .padding(24)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
  }
}

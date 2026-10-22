const SVG_NS = "http://www.w3.org/2000/svg"
const VIEW_W = 1400
const VIEW_H = 1000
const BOARD_X = 620
const BOARD_Y = 490
const SQUARE = 20
const INK_DRAW_MS = 2200
const INK_DRAW_TARGET = 0.62
const SCROLL_DRAW_SPAN = 0.55
const DPR_CAP = 2

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
const narrow = window.matchMedia("(max-width: 719px)")

type Attrs = Record<string, string>

function svgEl<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Attrs): SVGElementTagNameMap[K] {
  const node = document.createElementNS(SVG_NS, tag)
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value)
  return node
}

function inkPath(d: string, cls?: string): SVGPathElement {
  const path = svgEl("path", { d, pathLength: "1" })
  if (cls) path.setAttribute("class", cls)
  return path
}

function group(id: string): SVGGElement | null {
  return document.querySelector<SVGGElement>(`#${id}`)
}

function makeRandom(seed: number): () => number {
  let state = seed >>> 0
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0
    return state / 4294967296
  }
}

function spreadDraw(node: SVGElement, start: number, end: number): void {
  node.style.setProperty("--s", start.toFixed(3))
  node.style.setProperty("--e", end.toFixed(3))
}

function buildWater(): void {
  const water = group("water")
  if (!water) return
  const random = makeRandom(57)
  const rows: ReadonlyArray<readonly [number, number, number]> = [
    [190, 600, 3],
    [170, 640, 4],
    [180, 680, 4],
    [210, 720, 3],
    [260, 750, 2],
    [330, 620, 3],
    [360, 660, 2],
  ]
  for (const [x0, y, count] of rows) {
    let x = x0 + random() * 20
    for (let i = 0; i < count; i += 1) {
      const path = inkPath(`M${x} ${y} q7 -4 14 0 q7 4 14 0`)
      spreadDraw(path, 0.04 + random() * 0.1, 0.18 + random() * 0.1)
      water.append(path)
      x += 44 + random() * 18
    }
  }
}

function buildGrass(): void {
  const grass = group("grass")
  if (!grass) return
  const random = makeRandom(22)
  const patches: ReadonlyArray<readonly [number, number, number, number]> = [
    [60, 460, 300, 520],
    [120, 820, 440, 900],
    [940, 920, 1340, 990],
    [1000, 300, 1360, 360],
    [430, 360, 500, 460],
  ]
  for (const [x0, y0, x1, y1] of patches) {
    const count = 8 + Math.floor(random() * 7)
    for (let i = 0; i < count; i += 1) {
      const x = x0 + random() * (x1 - x0)
      const y = y0 + random() * (y1 - y0)
      const path = inkPath(`M${x} ${y} l3 -6 m2 6 l1 -8 m2 8 l4 -6`)
      spreadDraw(path, 0.1 + random() * 0.4, 0.5 + random() * 0.4)
      grass.append(path)
    }
  }
}

function buildMerlons(): void {
  const merlons = group("merlons")
  if (!merlons) return
  const spans: ReadonlyArray<readonly [number, number, number]> = [
    [536, 664, 680],
    [740, 864, 680],
    [536, 864, 340],
  ]
  for (const [from, to, y] of spans) {
    let d = ""
    for (let x = from; x + 8 <= to; x += 16) d += `M${x} ${y} v-8 h8 v8 `
    const path = inkPath(d.trim())
    spreadDraw(path, 0.3, 0.5)
    merlons.append(path)
  }
}

function buildHatch(): void {
  const hatch = group("hatch")
  if (!hatch) return
  let d = ""
  for (let y = 378; y < 466; y += 10) d += `M732 ${y} l12 12 `
  for (let y = 574; y < 606; y += 8) d += `M598 ${y} l12 10 M856 ${y} l12 10 `
  hatch.append(inkPath(d.trim()))
}

function buildBoard(): void {
  const board = group("board")
  if (!board) return
  let grid = ""
  for (let i = 0; i <= 8; i += 1) {
    const x = BOARD_X + i * SQUARE
    const y = BOARD_Y + i * SQUARE
    grid += `M${x} ${BOARD_Y} v${SQUARE * 8} M${BOARD_X} ${y} h${SQUARE * 8} `
  }
  const gridPath = inkPath(grid.trim())
  spreadDraw(gridPath, 0.5, 0.64)
  board.append(gridPath)

  let dark = ""
  for (let rank = 0; rank < 8; rank += 1) {
    for (let file = 0; file < 8; file += 1) {
      if ((rank + file) % 2 === 0) continue
      const x = BOARD_X + file * SQUARE
      const y = BOARD_Y + rank * SQUARE
      dark += `M${x} ${y + 7} l7 -7 M${x} ${y + 14} l14 -14 M${x + 7} ${y + 20} l13 -13 M${x + 14} ${y + 20} l6 -6 `
    }
  }
  const darkPath = inkPath(dark.trim(), "hatch")
  spreadDraw(darkPath, 0.6, 0.76)
  board.append(darkPath)
}

function buildForest(): void {
  const forest = group("forest")
  if (!forest) return
  const random = makeRandom(8)
  const total = 72
  for (let i = 0; i < total; i += 1) {
    const x = 960 + random() * 390
    const y = 390 + random() * 480
    if (y > 860 && x < 1120) continue
    const pine = random() > 0.55
    const scale = 0.8 + random() * 0.7
    const use = svgEl("use", {
      href: pine ? "#pine" : "#tree",
      transform: `translate(${x.toFixed(1)} ${y.toFixed(1)}) scale(${scale.toFixed(2)})`,
    })
    const start = 0.3 + (i / total) * 0.45
    spreadDraw(use, start, start + 0.08)
    forest.append(use)
  }
}

function buildScorch(): void {
  const scorch = group("scorch")
  if (!scorch) return
  const random = makeRandom(9)
  let d = ""
  for (let i = 0; i < 14; i += 1) {
    const angle = (i / 14) * Math.PI * 2 + random() * 0.3
    const r0 = 70 + random() * 8
    const r1 = r0 + 10 + random() * 14
    const cx = 400
    const cy = 430
    const ky = 0.56
    d += `M${(cx + Math.cos(angle) * r0).toFixed(1)} ${(cy + Math.sin(angle) * r0 * ky).toFixed(1)} L${(cx + Math.cos(angle) * r1).toFixed(1)} ${(cy + Math.sin(angle) * r1 * ky).toFixed(1)} `
  }
  scorch.append(inkPath(d.trim()))
}

function easeOut(t: number): number {
  return 1 - Math.pow(1 - t, 3)
}

function startInkDraw(): void {
  const root = document.documentElement
  if (reducedMotion) {
    root.style.setProperty("--p", "1")
    return
  }
  const began = performance.now()
  let scrollPart = 0
  let timePart = 0
  let queued = false

  const apply = (): void => {
    queued = false
    root.style.setProperty("--p", Math.max(scrollPart, timePart).toFixed(4))
  }
  const queue = (): void => {
    if (queued) return
    queued = true
    window.requestAnimationFrame(apply)
  }
  const onScroll = (): void => {
    const range = Math.max(1, (root.scrollHeight - window.innerHeight) * SCROLL_DRAW_SPAN)
    scrollPart = Math.min(1, window.scrollY / range)
    queue()
  }
  const tick = (now: number): void => {
    const t = Math.min(1, (now - began) / INK_DRAW_MS)
    timePart = easeOut(t) * INK_DRAW_TARGET
    queue()
    if (t < 1) window.requestAnimationFrame(tick)
  }
  window.addEventListener("scroll", onScroll, { passive: true })
  window.addEventListener("resize", onScroll)
  onScroll()
  window.requestAnimationFrame(tick)
}

type Focus = { x: number; y: number; scale: number }

const FOCUS: Record<string, { wide: Focus; narrow: Focus }> = {
  hero: { wide: { x: 560, y: 520, scale: 1 }, narrow: { x: 700, y: 440, scale: 1.1 } },
  armies: { wide: { x: 440, y: 560, scale: 1.5 }, narrow: { x: 700, y: 560, scale: 1.4 } },
  towers: { wide: { x: 900, y: 360, scale: 1.5 }, narrow: { x: 760, y: 360, scale: 1.3 } },
  field: { wide: { x: 480, y: 440, scale: 1.8 }, narrow: { x: 400, y: 440, scale: 1.6 } },
  board: { wide: { x: 540, y: 580, scale: 3.2 }, narrow: { x: 700, y: 690, scale: 2.4 } },
}

function worldTransform(focus: Focus): string {
  return `translate(${VIEW_W / 2}px, ${VIEW_H / 2}px) scale(${focus.scale}) translate(${-focus.x}px, ${-focus.y}px)`
}

function startFocus(): void {
  const world = group("world")
  if (!world) return
  let current = "hero"
  const apply = (): void => {
    const target = FOCUS[current]
    if (!target) return
    world.style.setProperty("--world", worldTransform(narrow.matches ? target.narrow : target.wide))
  }
  const sections = document.querySelectorAll<HTMLElement>("[data-focus]")
  const observer = new IntersectionObserver(
    (entries) => {
      let best: IntersectionObserverEntry | null = null
      for (const entry of entries) {
        if (!entry.isIntersecting) continue
        if (!best || entry.intersectionRatio > best.intersectionRatio) best = entry
      }
      if (!best) return
      const name = (best.target as HTMLElement).dataset.focus
      if (!name || name === current) return
      current = name
      apply()
    },
    { threshold: [0.25, 0.5, 0.75] },
  )
  for (const section of sections) observer.observe(section)
  narrow.addEventListener("change", apply)
  apply()
}

function startFolds(): void {
  const leaves = document.querySelectorAll<HTMLElement>(".fold")
  if (reducedMotion) {
    for (const leaf of leaves) leaf.classList.add("is-open")
    return
  }
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue
        entry.target.classList.add("is-open")
        observer.unobserve(entry.target)
      }
    },
    { threshold: 0.18, rootMargin: "0px 0px -8% 0px" },
  )
  for (const leaf of leaves) observer.observe(leaf)
}

type Ply = { from: string; to: string; label: string; side: "gold" | "frost" }

const OPENING: ReadonlyArray<Ply> = [
  { from: "e2", to: "e4", label: "e4", side: "gold" },
  { from: "e7", to: "e5", label: "e5", side: "frost" },
  { from: "g1", to: "f3", label: "Nf3", side: "gold" },
  { from: "b8", to: "c6", label: "Nc6", side: "frost" },
  { from: "f1", to: "c4", label: "Bc4", side: "gold" },
  { from: "f8", to: "c5", label: "Bc5", side: "frost" },
  { from: "c2", to: "c3", label: "c3", side: "gold" },
  { from: "g8", to: "f6", label: "Nf6", side: "frost" },
  { from: "d2", to: "d4", label: "d4", side: "gold" },
  { from: "e5", to: "d4", label: "exd4", side: "frost" },
  { from: "c3", to: "d4", label: "cxd4", side: "gold" },
  { from: "c5", to: "b4", label: "Bb4+", side: "frost" },
  { from: "b1", to: "c3", label: "Nc3", side: "gold" },
  { from: "f6", to: "e4", label: "Nxe4", side: "frost" },
  { from: "e1", to: "g1", label: "O-O", side: "gold" },
  { from: "b4", to: "c3", label: "Bxc3", side: "frost" },
  { from: "d4", to: "d5", label: "d5", side: "gold" },
  { from: "c3", to: "f6", label: "Bf6", side: "frost" },
]

const INK_BY_SIDE: Record<Ply["side"], string> = {
  gold: "#7a2e1a",
  frost: "#2d4a7a",
}

function squareCenter(square: string): { x: number; y: number } | null {
  const file = square.charCodeAt(0) - 97
  const rank = Number(square[1])
  if (file < 0 || file > 7 || !(rank >= 1 && rank <= 8)) return null
  return {
    x: BOARD_X + file * SQUARE + SQUARE / 2,
    y: BOARD_Y + (8 - rank) * SQUARE + SQUARE / 2,
  }
}

function fadeInOut(node: Element, delayMs: number, holdMs: number, scale: number): void {
  const animation = node.animate(
    [
      { opacity: 0, transform: `scale(${scale * 0.4})`, offset: 0 },
      { opacity: 0.92, transform: `scale(${scale})`, offset: 0.08 },
      { opacity: 0.92, transform: `scale(${scale})`, offset: 0.55 },
      { opacity: 0, transform: `scale(${scale})`, offset: 1 },
    ],
    { duration: holdMs, delay: delayMs, easing: "ease-out", fill: "forwards" },
  )
  animation.addEventListener("finish", () => node.remove())
}

function stampPrints(
  layer: SVGGElement,
  from: { x: number; y: number },
  to: { x: number; y: number },
  color: string,
  count: number,
  scale: number,
  stepMs: number,
  holdMs: number,
): void {
  const dx = to.x - from.x
  const dy = to.y - from.y
  const angle = (Math.atan2(dy, dx) * 180) / Math.PI + 90
  const nx = -dy
  const ny = dx
  const len = Math.hypot(nx, ny) || 1
  for (let i = 1; i <= count; i += 1) {
    const t = i / count
    const side = i % 2 === 0 ? 1 : -1
    const offset = 1.6 * scale * side
    const x = from.x + dx * t + (nx / len) * offset
    const y = from.y + dy * t + (ny / len) * offset
    const print = svgEl("use", { href: "#print" })
    print.style.setProperty("--print", color)
    print.style.transformBox = "fill-box"
    print.style.transformOrigin = "center"
    print.setAttribute("transform", `translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${angle.toFixed(1)})`)
    layer.append(print)
    fadeInOut(print, i * stepMs, holdMs, scale)
  }
}

function startBoardWalk(): void {
  const layer = group("prints")
  if (!layer || reducedMotion) return
  let index = 0
  const step = (): void => {
    const ply = OPENING[index % OPENING.length]
    index += 1
    if (!ply) return
    const from = squareCenter(ply.from)
    const to = squareCenter(ply.to)
    if (from && to) {
      const color = INK_BY_SIDE[ply.side]
      const hops = Math.max(2, Math.round(Math.hypot(to.x - from.x, to.y - from.y) / 7))
      stampPrints(layer, from, to, color, hops, 0.55, 110, 3200)
      const label = svgEl("text", {
        x: (to.x + 6).toFixed(1),
        y: (to.y - 5).toFixed(1),
      })
      label.textContent = ply.label
      label.style.setProperty("--print", color)
      layer.append(label)
      fadeInOut(label, hops * 110 + 80, 2600, 1)
    }
    window.setTimeout(step, 1500)
  }
  window.setTimeout(step, 1800)
}

function startRoadWalk(): void {
  const layer = group("trail")
  const road = document.querySelector<SVGPathElement>("#road-mid")
  if (!layer || !road || reducedMotion) return
  const length = road.getTotalLength()
  const stride = 1 / 34
  const walk = (): void => {
    for (let t = 0; t <= 1; t += stride) {
      const a = road.getPointAtLength(length * Math.max(0, t - 0.004))
      const b = road.getPointAtLength(length * Math.min(1, t + 0.004))
      const angle = (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI + 90
      const print = svgEl("use", { href: "#print" })
      print.style.setProperty("--print", "rgba(43, 26, 14, 0.75)")
      print.style.transformBox = "fill-box"
      print.style.transformOrigin = "center"
      const side = Math.round(t / stride) % 2 === 0 ? 2.2 : -2.2
      print.setAttribute("transform", `translate(${(a.x + side).toFixed(1)} ${a.y.toFixed(1)}) rotate(${angle.toFixed(1)})`)
      layer.append(print)
      fadeInOut(print, t * 2600, 3400, 0.9)
    }
    window.setTimeout(walk, 9000)
  }
  window.setTimeout(walk, 900)
}

type Blot = {
  x: number
  y: number
  radius: number
  born: number
  life: number
  lobes: number
  phase: number
  wobble: number
}

function startBlots(): void {
  const canvas = document.querySelector<HTMLCanvasElement>("#blots")
  if (!canvas || reducedMotion) return
  const context = canvas.getContext("2d")
  if (!context) return
  const fine = window.matchMedia("(pointer: fine)").matches
  const blots: Blot[] = []
  const random = makeRandom(4)
  let dpr = 1
  let width = 0
  let height = 0
  let running = false
  let lastX = -1000
  let lastY = -1000

  const resize = (): void => {
    dpr = Math.min(window.devicePixelRatio || 1, DPR_CAP)
    width = window.innerWidth
    height = window.innerHeight
    canvas.width = Math.round(width * dpr)
    canvas.height = Math.round(height * dpr)
    context.setTransform(dpr, 0, 0, dpr, 0, 0)
  }

  const drawBlot = (blot: Blot, now: number): boolean => {
    const age = now - blot.born
    if (age > blot.life) return false
    const grow = easeOut(Math.min(1, age / 520))
    const fade = age < blot.life * 0.3 ? 1 : 1 - (age - blot.life * 0.3) / (blot.life * 0.7)
    const r = blot.radius * grow
    context.beginPath()
    const steps = 28
    for (let i = 0; i <= steps; i += 1) {
      const a = (i / steps) * Math.PI * 2
      const wobble = 1 + blot.wobble * Math.sin(a * blot.lobes + blot.phase) + 0.12 * Math.sin(a * 7 + blot.phase * 2)
      const px = blot.x + Math.cos(a) * r * wobble
      const py = blot.y + Math.sin(a) * r * wobble
      if (i === 0) context.moveTo(px, py)
      else context.lineTo(px, py)
    }
    context.closePath()
    context.fillStyle = `rgba(43, 26, 14, ${(0.42 * fade).toFixed(3)})`
    context.fill()
    return true
  }

  const frame = (now: number): void => {
    context.clearRect(0, 0, width, height)
    for (let i = blots.length - 1; i >= 0; i -= 1) {
      const blot = blots[i]
      if (!blot || !drawBlot(blot, now)) blots.splice(i, 1)
    }
    if (blots.length > 0) window.requestAnimationFrame(frame)
    else running = false
  }

  const spawn = (x: number, y: number, radius: number): void => {
    blots.push({
      x,
      y,
      radius,
      born: performance.now(),
      life: 2200 + random() * 900,
      lobes: 3 + Math.floor(random() * 3),
      phase: random() * Math.PI * 2,
      wobble: 0.18 + random() * 0.14,
    })
    if (blots.length > 28) blots.shift()
    if (!running) {
      running = true
      window.requestAnimationFrame(frame)
    }
  }

  window.addEventListener("resize", resize)
  resize()

  if (fine) {
    window.addEventListener(
      "pointermove",
      (event) => {
        const dx = event.clientX - lastX
        const dy = event.clientY - lastY
        if (dx * dx + dy * dy < 48 * 48) return
        lastX = event.clientX
        lastY = event.clientY
        spawn(event.clientX, event.clientY, 7 + random() * 9)
      },
      { passive: true },
    )
  }
  window.addEventListener(
    "pointerdown",
    (event) => {
      spawn(event.clientX, event.clientY, 18 + random() * 14)
      for (let i = 0; i < 4; i += 1) {
        const a = random() * Math.PI * 2
        const d = 22 + random() * 26
        spawn(event.clientX + Math.cos(a) * d, event.clientY + Math.sin(a) * d, 2 + random() * 4)
      }
    },
    { passive: true },
  )
}

buildWater()
buildGrass()
buildMerlons()
buildHatch()
buildBoard()
buildForest()
buildScorch()
startInkDraw()
startFocus()
startFolds()
startBoardWalk()
startRoadWalk()
startBlots()

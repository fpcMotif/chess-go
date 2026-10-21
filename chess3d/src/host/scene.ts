import * as THREE from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls.js"
import type { Color, PieceSymbol, Square } from "../sim/rules.ts"
import { buildCharacter, disposeCharacter } from "./characters.ts"

export const SQUARE = 1
const FILES = "abcdefgh"

export const squarePosition = (square: Square): THREE.Vector3 => {
  const file = FILES.indexOf(square.charAt(0))
  const rank = Number(square.charAt(1)) - 1
  return new THREE.Vector3((file - 3.5) * SQUARE, 0, (3.5 - rank) * SQUARE)
}

export const squareOf = (file: number, rank: number): Square => `${FILES.charAt(file)}${rank + 1}` as Square

const PALETTE = {
  light: 0xe8dcc4,
  dark: 0x7a5c3e,
  select: 0x4a9eff,
  legal: 0x7ddc6a,
  capture: 0xff6b6b,
  last: 0xffd166
} as const

export interface Scene {
  readonly renderer: THREE.WebGLRenderer
  readonly scene: THREE.Scene
  readonly camera: THREE.PerspectiveCamera
  readonly controls: OrbitControls
  readonly board: THREE.Group
  readonly squares: ReadonlyMap<Square, THREE.Mesh<THREE.BoxGeometry, THREE.MeshStandardMaterial>>
  readonly markers: THREE.Group
  makePiece(color: Color, kind: PieceSymbol): THREE.Group
  setPieceKind(figure: THREE.Group, color: Color, kind: PieceSymbol): void
  highlight(options: { readonly selected: Square | null; readonly legal: ReadonlyArray<Square>; readonly captures: ReadonlyArray<Square>; readonly last: ReadonlyArray<Square> }): void
  pick(clientX: number, clientY: number): Square | null
  render(): void
  resize(): void
}

export const makeScene = (canvas: HTMLCanvasElement): Scene => {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap
  renderer.toneMapping = THREE.ACESFilmicToneMapping

  const scene = new THREE.Scene()
  scene.background = new THREE.Color(0x1a1b22)
  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 100)
  camera.position.set(0, 10, 10.5)
  const controls = new OrbitControls(camera, canvas)
  controls.enableDamping = true
  controls.maxPolarAngle = Math.PI / 2.2
  controls.minDistance = 5
  controls.maxDistance = 20
  controls.target.set(0, 0, 0)

  scene.add(new THREE.HemisphereLight(0xffffff, 0x444466, 0.9))
  const sun = new THREE.DirectionalLight(0xffffff, 2.2)
  sun.position.set(5, 10, 4)
  sun.castShadow = true
  sun.shadow.mapSize.set(2048, 2048)
  sun.shadow.camera.left = sun.shadow.camera.bottom = -6
  sun.shadow.camera.right = sun.shadow.camera.top = 6
  scene.add(sun)

  const board = new THREE.Group()
  const frame = new THREE.Mesh(new THREE.BoxGeometry(8.6, 0.3, 8.6), new THREE.MeshStandardMaterial({ color: 0x3b2a1c, roughness: 0.7 }))
  frame.position.y = -0.2
  frame.receiveShadow = true
  board.add(frame)
  const squares = new Map<Square, THREE.Mesh<THREE.BoxGeometry, THREE.MeshStandardMaterial>>()
  const squareGeometry = new THREE.BoxGeometry(SQUARE, 0.1, SQUARE)
  for (let file = 0; file < 8; file++) {
    for (let rank = 0; rank < 8; rank++) {
      const square = squareOf(file, rank)
      const tile = new THREE.Mesh(squareGeometry, new THREE.MeshStandardMaterial({ color: (file + rank) % 2 === 0 ? PALETTE.dark : PALETTE.light, roughness: 0.55 }))
      tile.position.copy(squarePosition(square))
      tile.receiveShadow = true
      tile.userData = { square }
      squares.set(square, tile)
      board.add(tile)
    }
  }
  scene.add(board)
  const markers = new THREE.Group()
  scene.add(markers)

  const raycaster = new THREE.Raycaster()
  const pointer = new THREE.Vector2()
  const ring = new THREE.RingGeometry(0.16, 0.24, 32)
  const dot = new THREE.CircleGeometry(0.14, 24)

  const api: Scene = {
    renderer,
    scene,
    camera,
    controls,
    board,
    squares,
    markers,
    makePiece(color, kind) {
      const figure = new THREE.Group()
      figure.add(buildCharacter(color, kind))
      figure.position.y = 0.05
      return figure
    },
    setPieceKind(figure, color, kind) {
      disposeCharacter(figure)
      figure.clear()
      figure.add(buildCharacter(color, kind))
    },
    highlight({ selected, legal, captures, last }) {
      for (const [square, tile] of squares) {
        const file = FILES.indexOf(square.charAt(0))
        const rank = Number(square.charAt(1)) - 1
        tile.material.color.setHex((file + rank) % 2 === 0 ? PALETTE.dark : PALETTE.light)
        tile.material.emissive.setHex(0)
        if (last.includes(square)) tile.material.emissive.setHex(PALETTE.last).multiplyScalar(0.25)
        if (square === selected) tile.material.emissive.setHex(PALETTE.select).multiplyScalar(0.45)
      }
      markers.clear()
      for (const square of legal) {
        const marker = new THREE.Mesh(captures.includes(square) ? ring : dot, new THREE.MeshBasicMaterial({ color: captures.includes(square) ? PALETTE.capture : PALETTE.legal, transparent: true, opacity: 0.85 }))
        marker.rotation.x = -Math.PI / 2
        marker.position.copy(squarePosition(square)).setY(0.06)
        markers.add(marker)
      }
    },
    pick(clientX, clientY) {
      const bounds = canvas.getBoundingClientRect()
      pointer.set(((clientX - bounds.left) / bounds.width) * 2 - 1, -((clientY - bounds.top) / bounds.height) * 2 + 1)
      raycaster.setFromCamera(pointer, camera)
      const hit = raycaster.intersectObjects([...squares.values()], false)[0]
      if (hit === undefined) return null
      const square: unknown = hit.object.userData["square"]
      return typeof square === "string" ? (square as Square) : null
    },
    render() {
      controls.update()
      renderer.render(scene, camera)
    },
    resize() {
      const width = canvas.clientWidth
      const height = canvas.clientHeight
      renderer.setSize(width, height, false)
      camera.aspect = width / height
      camera.updateProjectionMatrix()
    }
  }
  api.resize()
  return api
}

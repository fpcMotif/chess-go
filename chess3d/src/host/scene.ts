import * as THREE from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls.js"
import type { Color, PieceSymbol, Square } from "../sim/rules.ts"
import { buildCharacter, disposeCharacter } from "./characters.ts"
import { makeHall } from "./hall.ts"
import { runeTexture } from "./rune.ts"

export const SQUARE = 1
const FILES = "abcdefgh"

export const squarePosition = (square: Square): THREE.Vector3 => {
  const file = FILES.indexOf(square.charAt(0))
  const rank = Number(square.charAt(1)) - 1
  return new THREE.Vector3((file - 3.5) * SQUARE, 0, (3.5 - rank) * SQUARE)
}

export const squareOf = (file: number, rank: number): Square => `${FILES.charAt(file)}${rank + 1}` as Square

const PALETTE = {
  light: 0xd8c3a0,
  dark: 0x3e2a1a,
  frame: 0x2a1b10,
  trim: 0xb8862b,
  select: 0xf59e0b,
  legal: 0x10b981,
  capture: 0xef4444,
  last: 0xffb95f
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
  scene.background = new THREE.Color(0x0d0e14)
  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 100)
  camera.position.set(0, 9.5, 10.5)
  const controls = new OrbitControls(camera, canvas)
  controls.enableDamping = true
  controls.maxPolarAngle = Math.PI / 2.2
  controls.minDistance = 5
  controls.maxDistance = 20
  controls.target.set(0, 0, 0)

  scene.add(new THREE.HemisphereLight(0xffe2b8, 0x1a1428, 0.35))
  const key = new THREE.SpotLight(0xffc98a, 180, 40, Math.PI / 5, 0.6, 1.6)
  key.position.set(4, 11, 5)
  key.castShadow = true
  key.shadow.mapSize.set(2048, 2048)
  key.shadow.bias = -0.0005
  scene.add(key, key.target)
  const rim = new THREE.DirectionalLight(0x6f86d6, 0.8)
  rim.position.set(-6, 6, -8)
  scene.add(rim)
  const hall = makeHall(scene)

  const board = new THREE.Group()
  const frame = new THREE.Mesh(new THREE.BoxGeometry(9, 0.5, 9), new THREE.MeshStandardMaterial({ color: PALETTE.frame, roughness: 0.55, metalness: 0.1 }))
  frame.position.y = -0.3
  frame.receiveShadow = true
  frame.castShadow = true
  board.add(frame)
  const trim = new THREE.Mesh(new THREE.BoxGeometry(8.3, 0.02, 8.3), new THREE.MeshStandardMaterial({ color: PALETTE.trim, roughness: 0.35, metalness: 0.7 }))
  trim.position.y = -0.045
  board.add(trim)
  const plinth = new THREE.Mesh(new THREE.BoxGeometry(5, 2.6, 5), new THREE.MeshStandardMaterial({ color: PALETTE.frame, roughness: 0.7 }))
  plinth.position.y = -1.85
  board.add(plinth)
  const squares = new Map<Square, THREE.Mesh<THREE.BoxGeometry, THREE.MeshStandardMaterial>>()
  const squareGeometry = new THREE.BoxGeometry(SQUARE, 0.1, SQUARE)
  for (let file = 0; file < 8; file++) {
    for (let rank = 0; rank < 8; rank++) {
      const square = squareOf(file, rank)
      const tile = new THREE.Mesh(squareGeometry, new THREE.MeshStandardMaterial({ color: (file + rank) % 2 === 0 ? PALETTE.dark : PALETTE.light, roughness: 0.3, metalness: 0.05 }))
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
  const ring = new THREE.RingGeometry(0.36, 0.44, 48)
  const dot = new THREE.CircleGeometry(0.12, 24)
  const dotHalo = new THREE.CircleGeometry(0.26, 24)
  const rune = new THREE.Mesh(new THREE.PlaneGeometry(0.96, 0.96), new THREE.MeshBasicMaterial({ map: runeTexture(), transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }))
  rune.rotation.x = -Math.PI / 2
  rune.visible = false
  scene.add(rune)
  const runeLight = new THREE.PointLight(PALETTE.select, 0, 3, 2)
  runeLight.position.y = 0.4
  rune.add(runeLight)
  const clock = new THREE.Clock()

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
        if (last.includes(square)) tile.material.emissive.setHex(PALETTE.last).multiplyScalar(0.18)
      }
      rune.visible = selected !== null
      runeLight.intensity = selected === null ? 0 : 4
      if (selected !== null) rune.position.copy(squarePosition(selected)).setY(0.062)
      markers.clear()
      for (const square of legal) {
        const capture = captures.includes(square)
        const marker = new THREE.Mesh(capture ? ring : dot, new THREE.MeshBasicMaterial({ color: capture ? PALETTE.capture : PALETTE.legal, transparent: true, opacity: 0.95, depthWrite: false }))
        marker.rotation.x = -Math.PI / 2
        marker.position.copy(squarePosition(square)).setY(0.06)
        const halo = new THREE.Mesh(capture ? new THREE.RingGeometry(0.3, 0.5, 48) : dotHalo, new THREE.MeshBasicMaterial({ color: capture ? PALETTE.capture : PALETTE.legal, transparent: true, opacity: 0.28, depthWrite: false, blending: THREE.AdditiveBlending }))
        halo.rotation.x = -Math.PI / 2
        halo.position.copy(marker.position)
        markers.add(halo, marker)
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
      const time = clock.getElapsedTime()
      controls.update()
      hall.update(time)
      rune.rotation.z = time * 0.4
      runeLight.intensity = rune.visible ? 3.5 + Math.sin(time * 5) * 0.8 : 0
      for (const marker of markers.children) marker.scale.setScalar(1 + Math.sin(time * 4) * 0.06)
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

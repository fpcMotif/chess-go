import * as THREE from "three"

const GLYPHS = "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ"

export const runeTexture = (): THREE.CanvasTexture => {
  const size = 256
  const canvas = document.createElement("canvas")
  canvas.width = canvas.height = size
  const context = canvas.getContext("2d")
  if (context !== null) {
    const center = size / 2
    context.strokeStyle = "#ffd27a"
    context.fillStyle = "#ffd27a"
    context.lineWidth = 4
    context.beginPath()
    context.arc(center, center, 112, 0, Math.PI * 2)
    context.stroke()
    context.lineWidth = 2
    context.beginPath()
    context.arc(center, center, 84, 0, Math.PI * 2)
    context.stroke()
    context.beginPath()
    for (let index = 0; index < 6; index++) {
      const angle = (index / 6) * Math.PI * 2 - Math.PI / 2
      const x = center + Math.cos(angle) * 84
      const y = center + Math.sin(angle) * 84
      if (index === 0) context.moveTo(x, y)
      else context.lineTo(x, y)
    }
    context.closePath()
    context.stroke()
    context.font = "20px serif"
    context.textAlign = "center"
    context.textBaseline = "middle"
    for (let index = 0; index < 16; index++) {
      const angle = (index / 16) * Math.PI * 2
      context.save()
      context.translate(center + Math.cos(angle) * 98, center + Math.sin(angle) * 98)
      context.rotate(angle + Math.PI / 2)
      context.fillText(GLYPHS.charAt(index % GLYPHS.length), 0, 0)
      context.restore()
    }
  }
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  return texture
}

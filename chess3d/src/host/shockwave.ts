import * as THREE from "three"
import gsap from "gsap"
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js"
import { OutputPass } from "three/addons/postprocessing/OutputPass.js"
import { RenderPass } from "three/addons/postprocessing/RenderPass.js"
import { ShaderPass } from "three/addons/postprocessing/ShaderPass.js"

const SHOCKWAVE_SECONDS = 0.55

const shader = {
  uniforms: {
    tDiffuse: { value: null },
    uCenter: { value: new THREE.Vector2(0.5, 0.5) },
    uProgress: { value: 1 },
    uAspect: { value: 1 },
    uStrength: { value: 0.6 },
    uSplit: { value: 0.7 },
    uBand: { value: 0.06 },
    uRim: { value: new THREE.Color(1, 0.82, 0.4) }
  },
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }`,
  fragmentShader: `
    uniform sampler2D tDiffuse;
    uniform vec2 uCenter;
    uniform float uProgress;
    uniform float uAspect;
    uniform float uStrength;
    uniform float uSplit;
    uniform float uBand;
    uniform vec3 uRim;
    varying vec2 vUv;
    void main() {
      vec2 delta = vec2((vUv.x - uCenter.x) * uAspect, vUv.y - uCenter.y);
      float dist = length(delta);
      vec2 heading = delta / max(dist, 0.00001);
      vec2 along = vec2(heading.x / uAspect, heading.y);
      float offsetRing = (dist - uProgress * 0.8) / uBand;
      float ring = exp(-offsetRing * offsetRing) * (1.0 - uProgress);
      vec2 base = clamp(vUv - along * uStrength * ring * 0.08, 0.0, 1.0);
      vec2 fringe = along * uSplit * ring * 0.025;
      vec4 green = texture2D(tDiffuse, base);
      float red = texture2D(tDiffuse, clamp(base + fringe, 0.0, 1.0)).r;
      float blue = texture2D(tDiffuse, clamp(base - fringe, 0.0, 1.0)).b;
      gl_FragColor = vec4(vec3(red, green.g, blue) + uRim * ring * 0.28, green.a);
    }`
}

export interface Shockwave {
  burst(at: THREE.Vector3): gsap.core.Timeline
  render(): boolean
  resize(width: number, height: number): void
}

export const makeShockwave = (renderer: THREE.WebGLRenderer, scene: THREE.Scene, camera: THREE.PerspectiveCamera): Shockwave => {
  const composer = new EffectComposer(renderer)
  composer.addPass(new RenderPass(scene, camera))
  const pass = new ShaderPass(shader)
  composer.addPass(pass)
  composer.addPass(new OutputPass())
  const uniforms = pass.uniforms as typeof shader.uniforms
  const projected = new THREE.Vector3()
  let active = 0
  let compiled = false
  return {
    burst(at) {
      projected.copy(at).project(camera)
      uniforms.uCenter.value.set(projected.x * 0.5 + 0.5, projected.y * 0.5 + 0.5)
      active += 1
      return gsap.timeline({ onComplete: () => void (active -= 1) }).fromTo(uniforms.uProgress, { value: 0 }, { value: 1, duration: SHOCKWAVE_SECONDS, ease: "power2.out" })
    },
    render() {
      if (active === 0 && compiled) return false
      composer.render()
      compiled = true
      return true
    },
    resize(width, height) {
      composer.setPixelRatio(renderer.getPixelRatio())
      composer.setSize(width, height)
      uniforms.uAspect.value = width / Math.max(height, 1)
    }
  }
}

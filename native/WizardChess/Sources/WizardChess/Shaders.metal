#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

static float hash3(float3 p) {
  p = fract(p * 0.3183099 + 0.1);
  p *= 17.0;
  return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

static float noise3(float3 x) {
  float3 i = floor(x);
  float3 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
      mix(mix(hash3(i), hash3(i + float3(1, 0, 0)), f.x),
          mix(hash3(i + float3(0, 1, 0)), hash3(i + float3(1, 1, 0)), f.x), f.y),
      mix(mix(hash3(i + float3(0, 0, 1)), hash3(i + float3(1, 0, 1)), f.x),
          mix(hash3(i + float3(0, 1, 1)), hash3(i + float3(1, 1, 1)), f.x), f.y),
      f.z);
}

[[visible]]
void wizardSurface(realitykit::surface_parameters params) {
  constexpr sampler s(address::repeat, filter::linear, mip_filter::linear);
  auto mat = params.material_constants();
  auto tex = params.textures();
  float2 uv = params.geometry().uv0();
  uv.y = 1.0 - uv.y;

  float4 custom = params.uniforms().custom_parameter();
  float dissolve = custom.x;
  float aura = custom.y;
  float t = params.uniforms().time();
  float3 p = params.geometry().model_position();

  float n = noise3(p * 9.0) * 0.6 + noise3(p * 23.0) * 0.4;
  if (n < dissolve) {
    discard_fragment();
  }
  float edge = dissolve > 0.001 ? saturate(1.0 - (n - dissolve) / 0.09) : 0.0;

  float3 v = normalize(params.geometry().view_direction());
  float3 nrmW = normalize(params.geometry().normal());
  float rim = pow(1.0 - saturate(abs(dot(nrmW, v))), 3.0);
  float veins = smoothstep(0.62, 0.68, noise3(p * 7.0 + float3(0.0, -t * 0.9, 0.0)));

  half3 base = half3(mat.base_color_tint()) * tex.base_color().sample(s, uv).rgb;
  half3 glow = half3(mat.emissive_color()) * half(aura * (rim * 1.8 + veins * 0.7) + edge * 5.0);

  params.surface().set_base_color(base);
  params.surface().set_emissive_color(glow);
  params.surface().set_roughness(half(mat.roughness_scale()));
  params.surface().set_metallic(half(mat.metallic_scale()));
  params.surface().set_clearcoat(half(mat.clearcoat_scale()));
  half3 tn = realitykit::unpack_normal(tex.normal().sample(s, uv).rgb);
  params.surface().set_normal(float3(tn));
}

static float fbm(float3 p) {
  float f = 0.0, a = 0.5;
  for (int i = 0; i < 5; i++) {
    f += a * noise3(p);
    p = p * 2.03 + float3(1.7, 9.2, 4.1);
    a *= 0.5;
  }
  return f;
}

[[visible]]
void abyssSurface(realitykit::surface_parameters params) {
  auto mat = params.material_constants();
  float4 custom = params.uniforms().custom_parameter();
  float style = custom.x;
  float t = params.uniforms().time() * custom.y;
  float2 uv = params.geometry().uv0() * 5.0;
  float3 dark = float3(mat.base_color_tint());
  float3 bright = float3(mat.emissive_color());

  float3 q = float3(uv, t * 0.12);
  float flow = fbm(q + float3(fbm(q * 0.7 + t * 0.05), 0.0, 0.0) * 1.5);
  float curl = fbm(q * 2.1 - float3(t * 0.09, t * 0.04, 0.0));
  float glow;
  float3 color;
  if (style < 0.5) {
    float bolt = pow(saturate(1.0 - abs(curl - 0.52) * 18.0), 3.0);
    float strike = step(0.93, hash3(float3(floor(t * 5.0), 1.0, 7.0)));
    glow = smoothstep(0.42, 0.78, flow);
    color = mix(dark, bright, glow) + bright * bolt * (0.25 + strike * 2.5);
  } else if (style < 1.5) {
    float ember = pow(noise3(float3(uv * 9.0, t * 0.6)), 14.0) * 4.0;
    float wave = smoothstep(0.35, 0.8, flow + 0.08 * sin(uv.x * 6.0 + t));
    color = mix(dark, bright, wave) + float3(1.0, 0.45, 0.1) * ember;
    glow = wave;
  } else {
    float2 drift = uv + float2(t * 0.25, 0.0);
    float star = pow(hash3(float3(floor(drift * 24.0), 3.0)), 60.0) * 3.0;
    float twinkle = 0.6 + 0.4 * sin(t * 4.0 + hash3(float3(floor(drift * 24.0), 9.0)) * 40.0);
    float river = smoothstep(0.3, 0.85, flow * (1.0 - abs(params.geometry().uv0().y - 0.5) * 1.3));
    color = mix(dark, bright, river) + bright * star * twinkle;
    glow = river;
  }
  float3 centerFade = float3(1.0 - 0.6 * smoothstep(0.0, 0.5, length(params.geometry().uv0() - 0.5)));
  params.surface().set_base_color(half3(color * centerFade));
  params.surface().set_emissive_color(half3(color * centerFade * (0.6 + glow)));
  params.surface().set_roughness(1.0h);
}

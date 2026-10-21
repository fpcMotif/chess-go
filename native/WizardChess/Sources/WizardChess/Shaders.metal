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

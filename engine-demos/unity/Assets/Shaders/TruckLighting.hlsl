#ifndef TRUCK_LIGHTING_INCLUDED
#define TRUCK_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _BaseColor;
    float4 _EmissionColor;
    float _Metallic;
    float _Roughness;
    float _Clearcoat;
    float _ClearcoatRoughness;
    float _EmissionStrength;
    float _Alpha;
CBUFFER_END

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
    float fogFactor : TEXCOORD3;
};

Varyings vert(Attributes input)
{
    Varyings output;
    VertexPositionInputs pos = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs nrm = GetVertexNormalInputs(input.normalOS);
    output.positionCS = pos.positionCS;
    output.positionWS = pos.positionWS;
    output.normalWS = nrm.normalWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.fogFactor = ComputeFogFactor(pos.positionCS.z);
    return output;
}

float D_GGX(float NoH, float a)
{
    float a2 = a * a;
    float d = (NoH * NoH) * (a2 - 1.0) + 1.0;
    return a2 / max(PI * d * d, 1e-5);
}

float V_Smith(float NoV, float NoL, float a)
{
    float a2 = a * a;
    float gv = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float gl = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / max(gv + gl, 1e-5);
}

float3 F_Schlick(float VoH, float3 f0)
{
    return f0 + (1.0 - f0) * pow(1.0 - VoH, 5.0);
}

float3 EnvReflection(float3 dir, float roughness)
{
    float mip = roughness * (1.7 - 0.7 * roughness) * 6.0;
    float4 encoded = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, dir, mip);
    return encoded.rgb * unity_SpecCube0_HDR.x;
}

float3 Shade(float3 albedo, float3 n, float3 v, Light light)
{
    float3 l = light.direction;
    float NoL = saturate(dot(n, l));
    float NoV = saturate(dot(n, v));
    float3 h = normalize(l + v);
    float NoH = saturate(dot(n, h));
    float VoH = saturate(dot(v, h));
    float rough = max(_Roughness, 0.045);
    float a = rough * rough;
    float3 f0 = lerp(float3(0.04, 0.04, 0.04), albedo, _Metallic);
    float3 F = F_Schlick(VoH, f0);
    float3 spec = D_GGX(NoH, a) * V_Smith(NoV, NoL, a) * F;
    float3 kd = (1.0 - F) * (1.0 - _Metallic);
    float3 direct = (kd * albedo / PI + spec) * light.color * (light.distanceAttenuation * light.shadowAttenuation) * NoL;

    float coat = saturate(_Clearcoat);
    if (coat > 0.001)
    {
        float ca = max(_ClearcoatRoughness, 0.04);
        ca = ca * ca;
        float3 coatF = F_Schlick(VoH, float3(0.04, 0.04, 0.04));
        float3 coatSpec = D_GGX(NoH, ca) * V_Smith(NoV, NoL, ca) * coatF;
        direct *= (1.0 - coat * coatF);
        direct += coatSpec * light.color * (light.distanceAttenuation * light.shadowAttenuation) * NoL * coat;
    }
    return direct;
}

float4 frag(Varyings input) : SV_Target
{
    float3 n = normalize(input.normalWS);
    float3 v = normalize(GetWorldSpaceViewDir(input.positionWS));
    float4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    float3 albedo = _BaseColor.rgb * tex.rgb;
    float alpha = _Alpha * tex.a * _BaseColor.a;

    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord);
    float3 color = Shade(albedo, n, v, mainLight);

    uint count = GetAdditionalLightsCount();
    for (uint i = 0u; i < count; i++)
    {
        Light light = GetAdditionalLight(i, input.positionWS);
        color += Shade(albedo, n, v, light);
    }

    float3 ambient = SampleSH(n) * albedo * (1.0 - _Metallic * 0.85);
    float3 refl = reflect(-v, n);
    float3 f0 = lerp(float3(0.04, 0.04, 0.04), albedo, _Metallic);
    float NoV = saturate(dot(n, v));
    float3 env = EnvReflection(refl, _Roughness) * F_Schlick(NoV, f0);
    color += ambient + env * (1.0 - _Roughness * 0.65);
    if (_Clearcoat > 0.001)
    {
        color += EnvReflection(refl, _ClearcoatRoughness) * 0.04 * _Clearcoat;
    }
    color += _EmissionColor.rgb * _EmissionStrength;
    color = MixFog(color, input.fogFactor);
    return float4(color, alpha);
}

#endif

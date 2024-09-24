#ifndef UNIVERSAL_DEPTH_NORMALS_PASS_INCLUDED
#define UNIVERSAL_DEPTH_NORMALS_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Attributes
{
    float4 positionOS     : POSITION;
    float4 tangentOS      : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float3 normal       : NORMAL;
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float2 uv           : TEXCOORD1;
    float3 normalWS     : TEXCOORD2;
    float3 tangenWS     : TEXCOORD3;
    float3 bitangentWS  : TEXCOORD4;

};

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    output.uv         = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normal, input.tangentOS);
    output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    output.tangenWS = normalInput.tangentWS;
    output.bitangentWS = normalInput.bitangentWS;

    return output;
}

half4 DepthNormalsFragment(Varyings input) : SV_TARGET
{

    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);

    float3 normalWS = input.normalWS;
    #if _NORMALMAP
    float3 nomralTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    float3x3 tbn = float3x3(input.tangentWS, input.bitangentWS, input.normalWS);
    normalWS = normalize(mul(normalTS, tbn));
    #endif

    //移动端API使用压缩，使法线压缩到R8G8B8A8
    #if SHADER_API_MOBILE
    float2 octNormalWS = saturate(PackNormalOctQuadEncode(normalWS) * 0.5 + 0.5);
    half3 packedNormalWS = PackFloat2To888(octNormalWS);
    return half4(packedNormalWS, 0.0);
    #else
    //PC端直接输出
    return half4(NormalizeNormalPerPixel(normalWS), 0.0);
    #endif
}
#endif

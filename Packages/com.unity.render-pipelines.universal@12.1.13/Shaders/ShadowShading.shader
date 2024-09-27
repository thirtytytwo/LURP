Shader "Hidden/Universal Render Pipeline/ShadowShading"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Blend Off
        ZWrite Off
        Cull Off
        ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float3 positionOS: POSITION;
            };

            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            half4 _ShadowColor;
            float _SoftShadowArea;

            TEXTURE2D(_SourceTex);
            SAMPLER(sampler_SourceTex);
            TEXTURE2D(_ShadowCombineTexture);
            SAMPLER(sampler_ShadowCombineTexture);

            Varyings Vert(Attributes i)
            {
                Varyings o;
                o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                o.uv = i.positionOS.xy * 0.5f + 0.5f;
                #if UNITY_UV_STARTS_AT_TOP
                o.uv.y = 1.0f - o.uv.y;
                #endif
                return o;
            }

            half4 Frag(Varyings i) : SV_Target
            {
                half shadowVal = SAMPLE_TEXTURE2D(_ShadowCombineTexture, sampler_ShadowCombineTexture, i.uv).r;  
                half softShadowVal = step(max(shadowVal - _SoftShadowArea, 0.0), 0);
                half3 softShadowColor = _ShadowColor.rgb * softShadowVal;
                half4 sourceColor = SAMPLE_TEXTURE2D(_SourceTex, sampler_SourceTex, i.uv);
                return half4(sourceColor.rgb * softShadowColor * shadowVal, sourceColor.a);
            }
            ENDHLSL
        }
    }
}

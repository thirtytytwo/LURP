Shader "Unlit/Test"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct a2v
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_ShadowCombineTexture);
            SAMPLER(sampler_ShadowCombineTexture);

            v2f vert(a2v i)
            {
                v2f o ;
                o.positionCS = TransformObjectToHClip(i.positionOS);
                o.uv = i.uv;
                return o;
            }

            half4 frag(v2f i) :SV_TARGET
            {
                half4 color = SAMPLE_TEXTURE2D(_ShadowCombineTexture, sampler_ShadowCombineTexture, i.uv);
                return color;
            }
            
            ENDHLSL
        }
    }
}

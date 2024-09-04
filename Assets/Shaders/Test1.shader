Shader "Unlit/Test1"
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

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                //o.positionCS = TransformObjectToHClip(i.positionOS);
                //o.uv = i.uv;
                o.uv = i.positionOS.xy * 0.5f + 0.5f;
                return o;
            }

            half4 frag(v2f i) :SV_TARGET
            {
                return half4(1,1,1,1);
            }
            
            ENDHLSL
        }
    }
}

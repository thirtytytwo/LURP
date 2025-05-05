Shader "Hidden/LURP/Feature/LAnitiAliasing"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite Off
        ZTest Always
        Cull Off
        
        // FXAA Pass
        Pass
        {
            Name "FXAA"
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex FXAAVert
            #pragma fragment FXAAFrag

            #pragma multi_compile QUALITY_LOW QUALITY_MEDIUM QUALITY_HIGH
            #pragma multi_compile _ COMPUTE_FAST
            
            #include"LAntiAliasing.hlsl"

            struct a2v
            {
                float3 positionOS : POSITION;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f FXAAVert(a2v i)
            {
                v2f o;
                o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                float u = i.positionOS.x * 0.5f + 0.5f;
                float v = i.positionOS.y * 0.5f + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                v = 1.0f - v;
                #endif
                o.uv = float2(u,v);
                return o;
            }

            half4 FXAAFrag(v2f input) : SV_Target
            {
                return half4(FXAAPixelShader(input.uv), 1);
            }
            ENDHLSL
        }

        // TAA
        Pass
        {
            Name "TAA"
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex TAAVert
            #pragma fragment TAAFrag

            #include "LAntiAliasing.hlsl"

            struct a2v
            {
                float3 positionOS : POSITION;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f TAAVert(a2v i)
            {
                v2f o;
                o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                float u = i.positionOS.x * 0.5f + 0.5f;
                float v = i.positionOS.y * 0.5f + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                v = 1.0f - v;
                #endif
                o.uv = float2(u,v);
                return o;
            }

            half4 TAAFrag(v2f input) : SV_Target
            {
                half3 color = TAAPixelShader(input.uv);
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}

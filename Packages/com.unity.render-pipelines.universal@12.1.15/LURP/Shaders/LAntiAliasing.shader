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
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex AAVert
            #pragma fragment AAFrag

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
            

            TEXTURE2D(_CameraColorTexture);
            TEXTURE2D(_MotionVectorTexture);
            float4 SourceSize;
            float4 AAParams;
            

            v2f AAVert(a2v i)
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

            half4 AAFrag(v2f input) : SV_Target
            {
                half3 result = half3(1.0, 1.0, 1.0);
                result = FXAADesktopPixelShader(_CameraColorTexture, input.uv, SourceSize, AAParams);
                //result = SAMPLE_TEXTURE2D(_MotionVectorTexture, sampler_LinearClamp, input.uv);
                return half4(result, 1);
            }
            ENDHLSL
        }
    }
}

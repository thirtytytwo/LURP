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
            

            TEXTURE2D(_CameraColorTexture);
            float4 _CameraColorSize;
            float4 _FXAAParams;
            

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
                half3 result = half3(1.0, 1.0, 1.0);
                result = FXAADesktopPixelShader(_CameraColorTexture, input.uv, _CameraColorSize, _FXAAParams);
                return half4(result, 1);
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

            float4 _Jitter;
            TEXTURE2D(_CameraColorTexture);
            TEXTURE2D(_LMotionVectorTexture);
            TEXTURE2D(_LLastFrame);

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
                //历史帧没有数据，直接返回当前未加Jitter的颜色
                if (_Jitter.z == 0)
                {
                    half4 curFrameNoJitter = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, input.uv);
                    return curFrameNoJitter;
                }
                float2 jitterUV = input.uv + _Jitter.xy;
                half4 curFrameJitter = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, jitterUV);
                float2 delta = SAMPLE_TEXTURE2D(_LMotionVectorTexture, sampler_PointClamp, input.uv).xy;
                float2 motion = MotionVectorDecode(delta);
                float2 lastFrameUV = input.uv + motion;
                half4 lastFrame = SAMPLE_TEXTURE2D(_LLastFrame, sampler_LinearClamp, lastFrameUV);
                return lerp(lastFrame, curFrameJitter, 0.1);
            }
            ENDHLSL
        }
    }
}

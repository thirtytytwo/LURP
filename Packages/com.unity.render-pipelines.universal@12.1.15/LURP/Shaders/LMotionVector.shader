Shader "Hidden/LURP/Feature/LMotionVector"
{
    SubShader
    {
        Pass
        {
            Name "LMotionVectorObject"
            Tags { "LightMode" = "LMotionVectors" }
            HLSLPROGRAM

            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct a2v
            {
                float4 positionOS : POSITION;
                
            };
            struct v2f
            {
                float4 positionCS : SV_POSITION;
            };

            struct FragOutput
            {
                float4 vectorOutput : SV_Target0;
                float4 idOutput     : SV_Target1;
            };

            v2f Vert(a2v input)
            {
                v2f output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }
            FragOutput Frag(v2f input)
            {
                FragOutput output;
                output.vectorOutput = float4(1, 1, 1, 1);
                output.idOutput     = float4(1, 0, 0, 1);
                return output;
            }
            ENDHLSL
        }
        Pass
        {
            Name "LMotionVectorCamera"
            ZWrite Off
            ZTest Always
            Cull Off
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            
            #pragma vertex Vert
            #pragma fragment Frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            
            float4x4 PrevViewProjMatrix;
            float4   ScreenSize;

            struct a2v
            {
                float4 positionOS : POSITION;
            };
            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct FragmentOutput
            {
                float4 vectorOutput : SV_Target0;
                float4 idOutput     : SV_Target1;
            };

            v2f Vert(a2v input)
            {
                v2f o;
                o.positionCS = float4(input.positionOS.x, input.positionOS.y, 0.0f, 1.0f);
                o.uv = input.positionOS.xy * 0.5f + 0.5f;
                #if UNITY_UV_STARTS_AT_TOP
                o.uv.y = 1.0f - o.uv.y;
                #endif
                return o;
            }
            FragmentOutput Frag(v2f input)
            {
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv).r;
                float3 positionWS = mul(UNITY_MATRIX_I_VP, float4(input.positionCS.xy * ScreenSize.zw, depth, 1.0));

                float4 previousPositionVP = mul(PrevViewProjMatrix, float4(positionWS, 1.0));
                float4 positionVP = mul(UNITY_MATRIX_VP, float4(positionWS, 1.0));

                float2 previousPositionNDC = previousPositionVP.xy / previousPositionVP.w;
                float2 positionNDC = positionVP.xy / positionVP.w;

                float2 delta = previousPositionNDC - positionNDC;
                #if UNITY_UV_STARTS_AT_TOP
                delta.y = -delta.y;
                #endif

                float2 motion = float2(0.5, 0.5) + delta * 0.5;
                FragmentOutput output;
                output.vectorOutput = float4(motion, 0, 1);
                output.idOutput     = float4(0, 0, 0, 1);
                return output;
            }
            ENDHLSL
        }
    }
}

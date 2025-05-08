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

            #include "LAntiAliasing.hlsl"
            

            struct a2v
            {
                float4 positionOS : POSITION;
                float3 positionOld : TEXCOORD4;
                
            };
            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float4 positionVP : TEXCOORD0;
                float4 prevPositionVP : TEXCOORD1;
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

                output.positionVP = mul(UNITY_MATRIX_VP, mul(UNITY_MATRIX_M, input.positionOS));

                const float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(input.positionOld, 1.0) : input.positionOS;
                output.prevPositionVP = mul(_PrevViewProjMatrix, mul(unity_MatrixPreviousM, prevPos));
                return output;
            }
            FragOutput Frag(v2f input)
            {
                FragOutput output;
                bool forceNoMotion = unity_MotionVectorsParams.y == 0;
                if (forceNoMotion)
                {
                    output.vectorOutput = float4(0.5, 0.5, 0, 0);
                    output.idOutput = float4(0, 0, 0, 0);
                    return output;
                }

                float2 curPos = input.positionVP.xy / input.positionVP.w;
                float2 prevPos = input.prevPositionVP.xy / input.prevPositionVP.w;
                float2 delta = prevPos - curPos;
                //相当于把prevPos和curPos都映射到[0,1]的范围内
                delta *= 0.5f;

                float2 velocity = MotionVectorEncode(delta);
                velocity = velocity * 0.5f + 0.5f;

                #if UNITY_UV_STARTS_AT_TOP
                velocity.y = 1.0 - velocity.y;
                #endif

                output.vectorOutput = float4(velocity, 0, 1);
                output.idOutput = float4(0.2, 0, 0, 1);
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

            #include "LAntiAliasing.hlsl"
            

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
                #if UNITY_REVERSED_Z
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, input.uv.xy);
                #else
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, input.uv.xy);
                deviceDepth = deviceDepth * 2.0 - 1.0;
                #endif
                float3 positionWS = ComputeWorldSpacePosition(input.uv.xy, deviceDepth, UNITY_MATRIX_I_VP);

                float4 previousPositionVP = mul(_PrevViewProjMatrix, float4(positionWS, 1.0));
                float4 positionVP = mul(UNITY_MATRIX_VP, float4(positionWS, 1.0));

                float2 prevPos = previousPositionVP.xy / previousPositionVP.w;
                float2 curPos = positionVP.xy / positionVP.w;
                float2 delta = prevPos - curPos;
                //相当于把prevPos和curPos都映射到[0,1]的范围内
                delta *= 0.5f;
                
                float2 velocity = MotionVectorEncode(delta);
                velocity = velocity * 0.5f + 0.5f;

                #if UNITY_UV_STARTS_AT_TOP
                velocity.y = 1.0 - velocity.y;
                #endif
                
                FragmentOutput output;
                output.vectorOutput = float4(velocity, 0, 1);
                output.idOutput     = float4(0, 0, 0, 1);
                return output;
            }
            ENDHLSL
        }
    }
}

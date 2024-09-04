Shader "Hidden/Universal Render Pipeline/ShadowCombine"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        Blend Off
        ZWrite Off
        Cull Off
        ZTest Always
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float3 positionOS: POSITION;
                float2 uv        : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float2 uv        : TEXCOORD0;
            };
            

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            
            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                //o.positionCS = TransformObjectToHClip(i.positionOS);
                //o.uv = i.uv;
                o.uv = i.positionOS.xy * 0.5f + 0.5f;
                #if UNITY_UV_STARTS_AT_TOP
                o.uv.y = 1.0f - o.uv.y;
                #endif
                return o;
            }

            half4 Frag(Varyings i) : SV_Target
            {
                //采样深度图还原对应Z坐标
            #if UNITY_REVERSED_Z
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv.xy);
            #else
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv.xy);
                deviceDepth = deviceDepth * 2.0 - 1.0;
            #endif
                
                //重构世界坐标
                float3 positionWS = ComputeWorldSpacePosition(i.uv.xy, deviceDepth, unity_MatrixInvVP);
                //转成shadowmap空间
                float3 shadowCoord = TransformWorldToShadowCoord(positionWS.xyz).xyz;
                //处理shadowmap空间坐标，准备软阴影
                float2 sampleScreenUV = floor(shadowCoord.xy * _MainLightShadowmapSize.zw + 0.5) - 0.5;
                float2 coordScreenFrac = frac(shadowCoord.xy * _MainLightShadowmapSize.zw + 0.5);

                float2 offset0, offset1;
                offset0 = 3.0 - coordScreenFrac * 2.0;
                offset1 = coordScreenFrac * 2.0 + 1.0;

                float4 sampleUVOffset = float4((2.0 - coordScreenFrac) / offset0 - 1.0, coordScreenFrac / offset1 + 1.0).xzyw * _MainLightShadowmapSize.xxyy;
                
                float4 sampleUV0 = sampleScreenUV.xyxy * _MainLightShadowmapSize.xyxy + sampleUVOffset.xzyz;
                float4 sampleUV1 = sampleScreenUV.xyxy * _MainLightShadowmapSize.xyxy + sampleUVOffset.xwyw;

                //sample shadowmap 4x
                float depthVal = shadowCoord.z - 0.00001;
                half shadow0 = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV0.xy, depthVal));
                half shadow1 = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV0.zw, depthVal));
                half shadow2 = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV1.xy, depthVal));
                half shadow3 = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV1.zw, depthVal));
                
                //combine result
                half result;
                result =  offset0.x * offset0.y * shadow0;
                result += offset1.x * offset0.y * shadow1;
                result += offset0.x * offset1.y * shadow2;
                result += offset1.x * offset1.y * shadow3;

                result *= 0.0625;
                
                
                return half4(result, 0.0, 0.0, 1.0);
            }
            ENDHLSL
        }
    }        
}

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

            #pragma vertex Vert
            #pragma fragment Frag

            #define _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float3 positionOS: POSITION;
            };

            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float2 uv        : TEXCOORD0;
            };
            

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            
            real SampleShadowmap(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float3 shadowCoord)
            {
                real attenuation;
            
                    // 1-tap hardware comparison
                    attenuation = real(SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord));
            
                // Shadow coords that fall out of the light frustum volume must always return attenuation 1.0
                // TODO: We could use branch here to save some perf on some platforms.
                return BEYOND_SHADOW_FAR(shadowCoord) ? 1.0 : attenuation;
            }
            
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
                float4 shadowCoord = TransformWorldToShadowCoord(positionWS.xyz);
                //处理shadowmap空间坐标，准备软阴影
                //floor操作是确保了现在所以的像素点都落在对应的纹素上，-0.5回到像素中心
                float2 sampleScreenUV = floor(shadowCoord.xy * _MainLightShadowmapSize.zw + 0.5f) - 0.5f;
                float2 offset = frac(shadowCoord.xy * _MainLightShadowmapSize.zw + 0.5f);

                //因为offset是一个连续的值，所以不存在离散的filter，直接用函数图像做卷积
                float2 fetchWeightUV0, fetchWeightUV1;
                fetchWeightUV0 = 3.0f - offset * 2.0f;
                fetchWeightUV1 = offset * 2.0f + 1.0f;

                float2 fetchOffsetU, fetchOffsetV;
                
                //利用权重倒推出相对offset，加固定值得出绝对offset
                //offset -1/3 ~ 4/3 中心点则是(-1/4. 5/4)
                fetchOffsetU = float2((2.0f - offset.x) / fetchWeightUV0.x, offset.x / fetchWeightUV1.x) + float2(-1.0f, 1.0f);
                fetchOffsetV = float2((2.0f - offset.y) / fetchWeightUV0.y, offset.y / fetchWeightUV1.y) + float2(-1.0f, 1.0f);
                float4 sampleUVOffset = float4(fetchOffsetU, fetchOffsetV) * _MainLightShadowmapSize.xxyy;
                
                float4 sampleUV0 = sampleScreenUV.xyxy * _MainLightShadowmapSize.xyxy + sampleUVOffset.xzyz;
                float4 sampleUV1 = sampleScreenUV.xyxy * _MainLightShadowmapSize.xyxy + sampleUVOffset.xwyw;

                //sample shadowmap 4x
                float depthVal = shadowCoord.z + 0.0001f;
                half shadow0 = SampleShadowmap(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV0.xy, depthVal));
                half shadow1 = SampleShadowmap(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV0.zw, depthVal));
                half shadow2 = SampleShadowmap(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV1.xy, depthVal));
                half shadow3 = SampleShadowmap(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, float3(sampleUV1.zw, depthVal));
                
                //根据横纵权重累加结果
                half result;
                result =  fetchWeightUV0.x * fetchWeightUV0.y * shadow0;
                result += fetchWeightUV1.x * fetchWeightUV0.y * shadow1;
                result += fetchWeightUV0.x * fetchWeightUV1.y * shadow2;
                result += fetchWeightUV1.x * fetchWeightUV1.y * shadow3;

                //因为采样方式是双线性插值，所以我们的四次采样，相当于16次，在这里归一化
                result *= 0.0625;
                
                
                //return half4(SampleShadowmap(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, shadowCoord), 0.0, 0.0, 1.0);
                return half4(result, 0, 0, 1);
            }
            ENDHLSL
        }
    }        
}

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
                //�������ͼ��ԭ��ӦZ����
            #if UNITY_REVERSED_Z
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv.xy);
            #else
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv.xy);
                deviceDepth = deviceDepth * 2.0 - 1.0;
            #endif
                //�ع���������
                float3 positionWS = ComputeWorldSpacePosition(i.uv.xy, deviceDepth, unity_MatrixInvVP);
                //ת��shadowmap�ռ�
                float4 shadowCoord = TransformWorldToShadowCoord(positionWS.xyz);
                //����shadowmap�ռ����꣬׼������Ӱ
                //floor������ȷ�����������Ե����ص㶼���ڶ�Ӧ�������ϣ�-0.5�ص���������
                float2 sampleScreenUV = floor(shadowCoord.xy * _MainLightShadowmapSize.zw + 0.5f) - 0.5f;
                float2 offset = frac(shadowCoord.xy * _MainLightShadowmapSize.zw + 0.5f);

                //��Ϊoffset��һ��������ֵ�����Բ�������ɢ��filter��ֱ���ú���ͼ�������
                float2 fetchWeightUV0, fetchWeightUV1;
                fetchWeightUV0 = 3.0f - offset * 2.0f;
                fetchWeightUV1 = offset * 2.0f + 1.0f;

                float2 fetchOffsetU, fetchOffsetV;
                
                //����Ȩ�ص��Ƴ����offset���ӹ̶�ֵ�ó�����offset
                //offset -1/3 ~ 4/3 ���ĵ�����(-1/4. 5/4)
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
                
                //���ݺ���Ȩ���ۼӽ��
                half result;
                result =  fetchWeightUV0.x * fetchWeightUV0.y * shadow0;
                result += fetchWeightUV1.x * fetchWeightUV0.y * shadow1;
                result += fetchWeightUV0.x * fetchWeightUV1.y * shadow2;
                result += fetchWeightUV1.x * fetchWeightUV1.y * shadow3;

                //��Ϊ������ʽ��˫���Բ�ֵ���������ǵ��Ĵβ������൱��16�Σ��������һ��
                result *= 0.0625;
                
                
                //return half4(SampleShadowmap(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, shadowCoord), 0.0, 0.0, 1.0);
                return half4(result, 0, 0, 1);
            }
            ENDHLSL
        }
    }        
}

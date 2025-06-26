Shader "LURP/Feature/LScreenShadow"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        Pass
        {
            Name "Screen Shadow"
            Blend Off
            ZWrite Off
            Cull Off
            ZTest Always
            
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
        
        Pass
        {
            Name"Per Character Shadow"
            ZWrite Off
            ZTest Always
            Cull Off
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attribute
            {
                float4 positionOS : POSITION;
            };

            struct Varying
            {
                float4 positionCS : SV_POSITION;
                float4 positionSS : TEXCOORD0;
            };
            TEXTURE2D(_CameraDepthTexture);
            TEXTURE2D(_CharacterShadowmap);
            SAMPLER(sampler_PointClamp);

            float4x4 _WorldToShadowMatrix[4];
            float4 _CharacterShadowmapSize;
            float _ShadowDepthBias;
            int _CharacterID;
            
            float3 TransformWorldToCharacterShadow(float3 positionWS)
            {
                return mul(_WorldToShadowMatrix[_CharacterID], float4(positionWS, 1.0f));
            }

            half SampleCharacterShadowmap(float3 pos)
            {
                half val = SAMPLE_TEXTURE2D(_CharacterShadowmap, sampler_PointClamp, float2(pos.xy)).r;
                half ret = smoothstep(0, 0.1f, pos.z - val);
                ret = step(0.99f, ret);
                return ret;
            }
            Varying vert(Attribute i)
            {
                Varying o;
                o.positionCS = TransformObjectToHClip(i.positionOS);
                o.positionSS = ComputeScreenPos(o.positionCS);
                return o;
            }
            half4 frag(Varying i):SV_Target
            {
                float3 pos = i.positionSS.xyw;

                float2 uv = pos.xy / pos.z;
                #if UNITY_REVERSED_Z
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, uv);
            #else
                float deviceDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, uv);
                deviceDepth = deviceDepth * 2.0 - 1.0;
            #endif

                float3 positionWS = ComputeWorldSpacePosition(uv, deviceDepth, unity_MatrixInvVP);
                
                float3 shadowCoord = TransformWorldToCharacterShadow(positionWS);
                // return half4(shadowCoord, 1.0f);
                float clampXMin = (_CharacterID % 2) == 0 ? 0 : 0.5;
                float clampXMax = (_CharacterID % 2) == 0 ? 0.5 : 1;
                float clampYMin = (_CharacterID / 2) == 0 ? 0 : 0.5;
                float clampYMax = (_CharacterID / 2) == 0 ? 0.5 : 1;
                float clampZMin = 0;
                float clampZMax = 1;
                bool flag = (shadowCoord.x >= clampXMin && shadowCoord.x <= clampXMax) &&
                    (shadowCoord.y >= clampYMin && shadowCoord.y <= clampYMax);
                if (!flag) return half4(1,0,0,1);

                //处理shadowmap空间坐标，准备软阴影
                //floor操作是确保了现在所以的像素点都落在对应的纹素上，-0.5回到像素中心
                float2 sampleScreenUV = floor(shadowCoord.xy * _CharacterShadowmapSize.zw + 0.5f) - 0.5f;
                float2 offset = frac(shadowCoord.xy * _CharacterShadowmapSize.zw + 0.5f);

                //因为offset是一个连续的值，所以不存在离散的filter，直接用函数图像做卷积
                float2 fetchWeightUV0, fetchWeightUV1;
                fetchWeightUV0 = 3.0f - offset * 2.0f;
                fetchWeightUV1 = offset * 2.0f + 1.0f;

                float2 fetchOffsetU, fetchOffsetV;
                
                //利用权重倒推出相对offset，加固定值得出绝对offset
                //offset -1/3 ~ 4/3 中心点则是(-1/4. 5/4)
                fetchOffsetU = float2((2.0f - offset.x) / fetchWeightUV0.x, offset.x / fetchWeightUV1.x) + float2(-1.0f, 1.0f);
                fetchOffsetV = float2((2.0f - offset.y) / fetchWeightUV0.y, offset.y / fetchWeightUV1.y) + float2(-1.0f, 1.0f);
                float4 sampleUVOffset = float4(fetchOffsetU, fetchOffsetV) * _CharacterShadowmapSize.xxyy;
                
                float4 sampleUV0 = sampleScreenUV.xyxy * _CharacterShadowmapSize.xyxy + sampleUVOffset.xzyz;
                float4 sampleUV1 = sampleScreenUV.xyxy * _CharacterShadowmapSize.xyxy + sampleUVOffset.xwyw;

                //sample shadowmap 4x
                float depthVal = shadowCoord.z + _ShadowDepthBias;
                half shadow0 = SampleCharacterShadowmap(float3(sampleUV0.xy, depthVal));
                half shadow1 = SampleCharacterShadowmap(float3(sampleUV0.zw, depthVal));
                half shadow2 = SampleCharacterShadowmap(float3(sampleUV1.xy, depthVal));
                half shadow3 = SampleCharacterShadowmap(float3(sampleUV1.zw, depthVal));
                
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

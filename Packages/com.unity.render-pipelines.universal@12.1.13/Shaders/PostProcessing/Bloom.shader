Shader "Hidden/Universal Render Pipeline/Bloom"
{
    HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
    

        TEXTURE2D_X(_SourceTex);
        float2 _SourceTex_TexelSize;
    
        //Struct
        struct a2v
        {
            float4 positionOS:POSITION;
            float2 uv:TEXCOORD0;
        };
        struct v2f_single
        {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0;
        };
        struct v2f_multi
        {
            float4 positionCS:SV_POSITION;
            float4 texcoord0 :TEXCOORD0;
            float4 texcoord1 :TEXCOORD1;
        };
    
    ENDHLSL
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZTest Always Cull Off ZWrite Off Blend Off
        LOD 100
        

        Pass
        {
            Name "Bloom_Prefilter"
            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment Frag

            float4 _PreFilterParam;
            #define SCATTER _PreFilterParam.x
            #define CLAMP _PreFilterParam.y
            #define THRESHOLD _PreFilterParam.z
            #define THRESHOLDKNEE _PreFilterParam.w


            v2f_single Vert(a2v i)
            {
                v2f_single o;
                o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                float u = i.positionOS.x * 0.5f + 0.5f;
                float v = i.positionOS.y * 0.5f + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                v = 1.0f - v;
                #endif
                o.uv = float2(u,v);
                return o;
            }

            half4 Frag(v2f_single i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, i.uv);
                col = min(CLAMP, col);

                //thresholding
                half brightness = Max3(col.r, col.g, col.b);
                half softness = clamp(brightness - THRESHOLD + THRESHOLDKNEE, 0.0, 2.0 * THRESHOLDKNEE);
                softness = (softness * softness) / (4.0 * THRESHOLDKNEE + 1e-4);
                half multiplier = max(brightness - THRESHOLD, softness) / max(brightness, 1e-4);
                col *= multiplier;
                col = max(col,0); 
                return col;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name"Bloom_DownSample"
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag
            
            v2f_multi Vert(a2v i)
            {
                v2f_multi o;
                o.positionCS = o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                float u = i.positionOS.x * 0.5f + 0.5f;
                float v = i.positionOS.y * 0.5f + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                v = 1.0f - v;
                #endif
                float2 uv = float2(u,v);
                o.texcoord0 = _SourceTex_TexelSize.xyxy * float4(-0.5, 0.5,-0.5,-0.5) + uv.xyxy;
                o.texcoord1 = _SourceTex_TexelSize.xyxy * float4(0.5, -0.5, 0.5, 0.5) + uv.xyxy;
                return o;
            }

            half4 Frag(v2f_multi input) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, input.texcoord0.xy);
                col += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, input.texcoord0.zw);
                col += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, input.texcoord1.xy);
                col += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, input.texcoord1.zw);
                col *= 0.25;
                return col;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "Bloom_Atlas Combine And Blur Horizontal"
            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment Frag

            CBUFFER_START(UnityBloomAltlasParam)
            int    _LoopTime;
            float4 _ScaleXYAndBlurKernals[16];
            CBUFFER_END

            v2f_single Vert(a2v i)
            {
                v2f_single o;
                o.positionCS = o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                float u = i.positionOS.x * 0.5f + 0.5f;
                float v = i.positionOS.y * 0.5f + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                v = 1.0f - v;
                #endif
                o.uv = float2(u,v);

                return o;
            }

            half4 Frag(v2f_single input):SV_Target
            {
                half4 col = 0;
                float2 newUV;
                for (int i = 0; i <_LoopTime; i++)
                {
                    newUV = _ScaleXYAndBlurKernals[i].xy * float2(1,0) + input.uv;
                    col += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, newUV) * _ScaleXYAndBlurKernals[i].z;
                }
                //TODO:是否还需要一个整体的调整参数col *= 
                return col;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name"Bloom_Atlas Combine And Blur Vertical"
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            CBUFFER_START(UnityBloomAltlasParam)
            int    _LoopTime;
            float4 _ScaleXYAndBlurKernals[16];
            float4 _SampleEdge;
            float4 _UVScaleAndOffsetFrag;
            CBUFFER_END

            v2f_single Vert(a2v i)
            {
                v2f_single o;
                o.positionCS = o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                float u = i.positionOS.x * 0.5f + 0.5f;
                float v = i.positionOS.y * 0.5f + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                v = 1.0f - v;
                #endif
                o.uv = float2(u,v);

                return o;
            }

            half4 Frag(v2f_single input):SV_Target
            {
                half4 col = 0;
                float2 newUV = input.uv * _UVScaleAndOffsetFrag.xy + _UVScaleAndOffsetFrag.zw;
                float2 sampleUV;
                for (int i = 0; i <_LoopTime; i++)
                {
                    sampleUV = _ScaleXYAndBlurKernals[i].xy * float2(0,1)+ newUV;
                    sampleUV = max(sampleUV, _SampleEdge.xy);
                    sampleUV = min(sampleUV, _SampleEdge.zw);
                    col += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, sampleUV) * _ScaleXYAndBlurKernals[i].z;
                }
                //TODO:是否还需要一个整体的调整参数col *= 
                return col;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name"Bloom_Final Combine"
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            CBUFFER_START(UnityBloomAltlasParam)
            float4 _SampleScaleAndOffset[4];
            CBUFFER_END

            v2f_single Vert(a2v i)
            {
                v2f_single o;
                o.positionCS = o.positionCS = float4(i.positionOS.x, i.positionOS.y, 0.0f, 1.0f);
                float u = i.positionOS.x * 0.5f + 0.5f;
                float v = i.positionOS.y * 0.5f + 0.5f;
                #if UNITY_UV_STARTS_AT_TOP
                v = 1.0f - v;
                #endif
                o.uv = float2(u,v);

                return o;
            }

            
            half4 Frag(v2f_single input):SV_Target
            {
                half4 col = 0;
                float2 newUV;
                UNITY_UNROLL
                for (int i = 0; i < 4; i++)
                {
                    newUV = _SampleScaleAndOffset[i].xy * input.uv + _SampleScaleAndOffset[i].zw;
                    col += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, newUV)  ;
                }
                //TODO:是否还需要一个整体的调整参数col *= 
                return col;
            }
            
            ENDHLSL
        }
    }
}

Shader "Shader_yc/GbsPostProcess"
{
    Properties
    {
        _NoiseTex("噪声贴图", 2D) = "white"{}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Overlay" }
        
        Blend Off
        ZWrite Off
        Cull Back
        ZTest Always
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #pragma multi_compile_fragment _ _ENABLE_BLACKWHITEFLASH
            #pragma multi_compile_fragment _ _ENABLE_SCATTERBLUR

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _CameraColorTexture_ST;
            float4 _ScatterBlurOffsetScale;
            float4 _BlackWhiteFlashProp;
            float4 _SketchPointOffsetAndScale;
            float4 _SketchXYSpeedAndTimeScale;
            half4 _BrightPartColor;
            half4 _DarkPartColor;
            CBUFFER_END

            TEXTURE2D(_CameraColorTexture);
            SAMPLER(sampler_CameraColorTexture);
            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            float2 UV2PolarCoordinate(float2 uv, float2 center, float radiusScale, float lengthScale)
            {
                float2 delta = uv - center;
                float radius = length(delta) * 2.0 * radiusScale;
                float angle = atan2(delta.x, delta.y) * (1 / TWO_PI) * lengthScale;
                return float2(radius, angle);
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _CameraColorTexture);
                return o;
            }

            half4 frag (v2f input) : SV_Target
            {
                //Init Param
                half3 resultCol = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, input.uv).rgb;
                
                #ifdef _ENABLE_SCATTERBLUR
                //放射模糊
                {
                    //Init Param
                    float2 uv2Center = (input.uv - float2(0.5 - _ScatterBlurOffsetScale.x,0.5 - _ScatterBlurOffsetScale.y)) * _ScatterBlurOffsetScale.w * _ScatterBlurOffsetScale.zz;
                    float2 uvSubContainer = input.uv - uv2Center;

                    //Logic
                    UNITY_UNROLL
                    for (int i = 0; i < 9; i++)
                    {
                        uvSubContainer -= uv2Center;
                        resultCol += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSubContainer).rgb;
                    }
                    resultCol *= 0.1f;
                }
                #endif
                
                #ifdef _ENABLE_BLACKWHITEFLASH
                //黑白闪
                {
                    //Init Param
                    float2 polarUV = UV2PolarCoordinate(input.uv, float2(0.5f,0.5f) - _SketchPointOffsetAndScale.xy, _SketchPointOffsetAndScale.z, _SketchPointOffsetAndScale.w);
                    //Logic
                    polarUV += float2(_Time.y * _SketchXYSpeedAndTimeScale.x, _Time.y * _SketchXYSpeedAndTimeScale.y) + _SketchXYSpeedAndTimeScale.zw;
                    float desaturateVal = dot(resultCol, float3( 0.299, 0.587, 0.114 ));//Desaturate dot(resultCol, float3( 0.299, 0.587, 0.114 )
                    desaturateVal = lerp(desaturateVal, SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, polarUV).r, _BlackWhiteFlashProp.z);
                    float blackWhiteVal = smoothstep(_BlackWhiteFlashProp.x, _BlackWhiteFlashProp.x + _BlackWhiteFlashProp.y,desaturateVal);
                    resultCol = lerp(_DarkPartColor.rgb, _BrightPartColor.rgb, lerp(blackWhiteVal, 1 - blackWhiteVal, _BlackWhiteFlashProp.w));
                }
                #endif
                 
                return half4(resultCol, 1.);
            }
            ENDHLSL
        }
    }
}

Shader "LURP/LTransparentWithMotion"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
        Pass
        {
            Name "TransparentTest"
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            struct a2v
            {
                float4 positionOS : POSITION;
                float2 uv        : TEXCOORD0;
            };
            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv        : TEXCOORD0;
            };
            v2f Vert(a2v input)
            {
                v2f output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }
            half4 Frag(v2f input) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
            }
            ENDHLSL
        }
        Pass
        {
            Name"LMotionVectorObject"
            Tags { "LightMode" = "LMotionVectors" }
            ZWrite Off
            ZTest LEqual
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

            v2f Vert(a2v input)
            {
                v2f output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }
            half4 Frag(v2f input) : SV_Target1
            {
                return half4(10,1,1,1);
            }
            ENDHLSL
        }
    }
}

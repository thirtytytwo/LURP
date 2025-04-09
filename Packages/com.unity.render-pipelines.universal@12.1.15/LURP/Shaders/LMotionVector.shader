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
                FragmentOutput output;
                output.vectorOutput = float4(0, 0, 0, 1);
                output.idOutput     = float4(0, 0, 0, 1);
                return output;
            }
            ENDHLSL
        }
    }
}

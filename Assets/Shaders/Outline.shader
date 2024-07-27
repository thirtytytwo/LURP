Shader "Unlit/Outline"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Outline("Outline", Range(0, 10)) = 0.05
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite On
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 Tangent : TANGENT;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Outline;

            float3 Unpack(float2 input)
            {
                float2 i = float2(input.x * 2.0 - 1.0, input.y * 2.0 - 1.0);
                float3 output = float3(i.x, i.y, 1 - abs(i.x) - abs(i.y));
                if (output.z < 0)
                {
                    float temp = output.x;
                    output.x = (1 - abs(output.y)) * sign(output.x);
                    output.y = (1 - abs(temp)) * sign(output.y);
                }
                return output;
            }
            v2f vert (appdata v)
            {
                v2f o;
                float3 packNormal = Unpack(v.uv2);
                float3 bitangent = cross(v.normal, v.Tangent.xyz) * v.Tangent.w;
                float4x4 tbn = float4x4(
                               float4(v.Tangent), 
                               float4(bitangent, 0), 
                               float4(v.normal, 0), 
                               float4(0, 0, 0, 0));
                float3 resultNormal = mul(packNormal, tbn);
                float3 vertPos = v.vertex.xyz + packNormal * _Outline * 0.01;
                o.vertex = TransformObjectToHClip(vertPos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                half4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDHLSL
        }
    }
}

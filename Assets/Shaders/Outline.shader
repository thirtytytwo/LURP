Shader "Unlit/Outline"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Outline("Outline", Range(0, 10)) = 0.05
    }
    SubShader
    {
        LOD 100
        Pass
        {
            Tags { "RenderType"="Opaque" "LightMode" = "UniversalForward" "Queue" = "Geometry"}
            ZWrite On
            Cull Back
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Outline;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half3 color = tex2D(_MainTex, i.uv).rgb;
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.vertex.xyz);
                float NdotL = dot(i.normal, lightDir) * 0.5 + 0.5;
                float3 diffuse = NdotL  * _MainLightColor.rgb;
                return half4(diffuse, 1);
            }
            ENDHLSL
        }
        Pass
        {
            Tags { "RenderType"="Opaque" "Queue" = "Geometry - 10"}
            ZWrite On
            Cull Front
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
                float2 uv2 : TEXCOORD2;
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
                float3x3 tbn = float3x3(v.Tangent.xyz, bitangent, v.normal);
                float3 resultNormal = mul(packNormal, tbn);
                float3 vertPos = v.vertex.xyz + resultNormal * _Outline * 0.0001;
                o.vertex = TransformObjectToHClip(vertPos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                return half4(0,0,0,1);
            }
            ENDHLSL
        }
    }
}

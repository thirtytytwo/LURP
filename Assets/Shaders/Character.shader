Shader "LURP/Character"
{
    Properties
    {
        _BaseMap("BaseMap", 2D) = "white" {}
        _Outline("Outline", Range(0, 10)) = 0.01
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

       Pass
        {
            Name "Forward"
            Tags {"LightMode" = "UniversalForward" "Queue" = "Geometry"}
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
            Name "ShadowCaster"
            Tags {"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Outline"
            Tags {"Queue" = "Geometry + 10"}
            
            Cull Front
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vertex
            #pragma fragment Fragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float3 positionOS: POSITION;
                float4 tangent : TANGENT;
                float3 normalOS: NORMAL;
                float2 outlineUV: TEXCOORD2;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

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

            Varyings Vertex(Attributes i)
            {
                Varyings o;
                float3 packNormal = Unpack(i.outlineUV);
                float3 bitangent = cross(i.normalOS, i.tangent.xyz) * i.tangent.w;
                float3x3 tbn = float3x3(i.tangent.xyz, bitangent, i.normalOS);
                float3 resultNormal = mul(packNormal, tbn);
                float3 vertPos = i.positionOS + resultNormal * _Outline * 0.1;
                o.positionCS = TransformObjectToHClip(vertPos);
                return o;
            }

            half4 Fragment(Varyings i) : SV_Target
            {
                return half4(0, 0, 0, 1);
            }
            ENDHLSL
        }
    }
}

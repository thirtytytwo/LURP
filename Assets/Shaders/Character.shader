Shader "LURP/Character"
{
    Properties
    {
        _BaseMap("BaseMap", 2D) = "white" {}
        _Outline("Outline", Range(0, 10)) = 0.01
        _ReceiveShadow("ReceiveShadow", Int) = 1
        _Stencil("Stencil", Int) = 0
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
            Stencil
            {
                Ref [_Stencil]
                Comp Always
                Pass Replace
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 positionCS : SV_POSITION;
            };
            float _Outline;
            int _ReceiveShadow;

            TEXTURE2D(_CharacterShadowmap);
            SAMPLER(sampler_PointClamp);
            SAMPLER_CMP(sampler_CharacterShadowmap);
            int _CharacterCount;
            float4x4 _WorldToShadowMatrix[4];
            float _ShadowDepthBias;
            
            
            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.positionWS = TransformObjectToWorld(v.positionOS);
                return o;
            }
            

            half SampleCharacterShadow(float3 positionWS)
            {
                for (int i = 0; i < _CharacterCount; i++)
                {
                    float4 shadowCoord = mul(_WorldToShadowMatrix[i], float4(positionWS, 1.0));
                    float clampXMin = (i % 2) == 0 ? 0 : 0.5;
                    float clampXMax = (i % 2) == 0 ? 0.5 : 1;
                    float clampYMin = (i / 2) == 0 ? 0 : 0.5;
                    float clampYMax = (i / 2) == 0 ? 0.5 : 1;
                    float clampZMin = 0;
                    float clampZMax = 1;
                    bool flag = (shadowCoord.x >= clampXMin && shadowCoord.x <= clampXMax) &&
                        (shadowCoord.y >= clampYMin && shadowCoord.y <= clampYMax) &&
                        (shadowCoord.z >= clampZMin && shadowCoord.z <= clampZMax);
                    if (flag)
                    {
                        float depthVal = shadowCoord.z + _ShadowDepthBias;
                        half val = SAMPLE_TEXTURE2D(_CharacterShadowmap, sampler_PointClamp, float2(shadowCoord.xy)).r;
                        half ret = smoothstep(0, 0.1f, depthVal - val);
                        ret = step(0.99f, ret);
                        return ret;
                    }
                }
                return 1;
            }
            

            half4 frag (v2f i) : SV_Target
            {
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionCS.xyz);
                float NdotL = dot(i.normal, lightDir) * 0.5 + 0.5;
                float3 diffuse = NdotL  * _MainLightColor.rgb;
                float3 ret = diffuse;
                
                return half4(ret , 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags {"LightMode" = "LShadowCaster"}

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
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Back
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}

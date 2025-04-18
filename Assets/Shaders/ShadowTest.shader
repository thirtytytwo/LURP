Shader "Shader_yc/ShadowTest"
{
    Properties
    {
        _BaseMap("BaseMap", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            struct Attributes
            {
                float3 position: POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
            };

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            TEXTURE2D(_LScreenShadowTexture);
            SAMPLER(sampler_LScreenShadowTexture);

            Varyings Vert(Attributes i)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(i.position);
                o.positionWS = TransformObjectToWorld(i.position);
                o.normalWS = TransformObjectToWorldNormal(i.normalOS);
                o.positionSS = ComputeScreenPos(o.positionCS);
                return o;
            }

            half4 Frag(Varyings i) : SV_Target
            {
                //�򵥵�bilin phong��ɫ
                half3 lightDir = normalize(_MainLightPosition.xyz);
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS);

                //diffuse
                half NdotL = saturate(dot(i.normalWS, lightDir));
                half3 diffuse = NdotL * _MainLightColor.rgb;

                //specular
                half3 halfDir = normalize(lightDir + viewDir);
                half NdotH = saturate(dot(i.normalWS, halfDir));
                half3 specular = pow(NdotH, 32) * _MainLightColor.rgb;

                half3 finalColor = diffuse + specular;
                //shadow
                
                half shadow = SAMPLE_TEXTURE2D(_LScreenShadowTexture, sampler_LScreenShadowTexture, i.positionSS.xy / i.positionSS.w).r;
                finalColor *= shadow;
                
                return half4(finalColor, 1);
            }
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

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}

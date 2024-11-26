Shader "Hidden/Universal Render Pipeline/UI/Default"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255

        _ColorMask ("Color Mask", Float) = 15

        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }
        
        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend One OneMinusSrcAlpha
        ColorMask [_ColorMask]
        LOD 100

        Pass
        {
            Name "GbsUIDefault"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include"Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include"Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            struct appdata
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID       
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                float4 color    : COLOR;
                float2 texcoord  : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
                half4  mask : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _MainTex_ST;
            CBUFFER_END

            float4 _TextureSampleAdd;
            float4 _ClipRect;
            float _UIMaskSoftnessX;
            float _UIMaskSoftnessY;
            half _IsInUICamera;
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.worldPosition = v.vertex;
                o.vertex = TransformObjectToHClip(v.vertex);
                float2 pixelSize = o.vertex.w;
                pixelSize /= 1 * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy));

                float4 clampRect = clamp(_ClipRect, -2e10, 2e10);
                float2 maskUV = (v.vertex.xy - clampRect.xy) / (clampRect.zw - clampRect.xy);
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.mask = half4(v.vertex.xy * 2 - clampRect.xy - clampRect.zw, 0.25 / (0.25 * half2(_UIMaskSoftnessX, _UIMaskSoftnessY) + abs(pixelSize)));
                o.color = v.color * _Color;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                //Round up the alpha color coming from the interpolator (to 1.0/256.0 steps)
                //The incoming alpha could have numerical instability, which makes it very sensible to
                //HDR color transparency blend, when it blends with the world's texture.
                const half alphaPrecision = half(0xff);
                const half invAlphaPrecision = half(1.0 / alphaPrecision);
                i.color.a = round(i.color.a * alphaPrecision) * invAlphaPrecision;

                half4 color;
                color = i.color * (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord) + _TextureSampleAdd);

#ifdef UNITY_UI_CLIP_RECT
                half2 m = saturate((_ClipRect.zw - _ClipRect.xy - abs(IN.mask.xy)) * IN.mask.zw);
                color.a *= m.x * m.y;
#endif

#ifdef UNITY_UI_ALPHACLIP
                clip (color.a - 0.001);
#endif

                // Guaranteeing that your UI texture is selected "sRGB (Color Texture)" in "(Texture 2D) Import Setting".
                color.rgb = lerp(color.rgb, LinearToSRGB(color.rgb), _IsInUICamera);

                // Guaranteeing that your UI shader is in mode of "One OneMinusSrcAlpha".
                color.rgb *= color.a;

                return color;
            }
            ENDHLSL
        }
    }
}

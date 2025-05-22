using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEngine.Rendering.Universal.Internal
{
    public class LCharacterMainLightShadowCasterPass : ScriptableRenderPass
    {
        private static readonly ShaderTagId mShaderTagId = new ShaderTagId("LCharacterShadowCaster");
        private static readonly ProfilingSampler mProfilingSampler = new ProfilingSampler("LCharacterShadowCaster");
        private static readonly uint[] mCharacterType = new uint[4]{0x10000, 0x100000, 0x1000000, 0x10000000};

        private RenderTexture mShadowMap;

        private ShadowSliceData[] mCharacterShadowDatas = new ShadowSliceData[4];

        public bool Setup(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!renderingData.shadowData.supportsMainLightShadows)
                return false;
            
            Clear();
            int shadowLightIndex = renderingData.lightData.mainLightIndex;
            if (shadowLightIndex == -1)
                return false;
            
            VisibleLight shadowLight = renderingData.lightData.visibleLights[shadowLightIndex];
            Light light = shadowLight.light;
            if (light.shadows == LightShadows.None)
                return false;

            if (shadowLight.lightType != LightType.Directional)
            {
                Debug.LogWarning("Only directional lights are supported as main light.");
            }

            //
            var camera = renderingData.cameraData.camera;
            if (!camera.TryGetCullingParameters(out var cullingParameters))
            {
                Debug.LogError("failed to get cull parameter from camera");
                return false;
            }
            
            //temporary set 4 characters straight forward
            for (int i = 0; i < 4; i++)
            {
                bool success = SetupShadowDataPerCharacter(context, cullingParameters, shadowLightIndex, i, 1024, light.shadowNearPlane, out mCharacterShadowDatas[i]);
                if (!success) return false;
            }

            return true;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, mProfilingSampler))
            {
                    
            }
        }

        private bool SetupShadowDataPerCharacter(ScriptableRenderContext context, ScriptableCullingParameters parameters, 
            int shadowLightIndex, int characterIndex, int resolution, float nearPlane,
            out ShadowSliceData shadowSliceData)
        {
            parameters.cullingMask = mCharacterType[characterIndex];
            
            CullingResults cullResults = context.Cull(ref parameters);

            bool success = cullResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(shadowLightIndex, characterIndex, 4, new Vector3(1, 0, 0), resolution, nearPlane,
                out shadowSliceData.viewMatrix, out shadowSliceData.projectionMatrix, out shadowSliceData.splitData);

            shadowSliceData.offsetX = (characterIndex % 2) * resolution;
            shadowSliceData.offsetY = (characterIndex / 2) * resolution;
            shadowSliceData.resolution = resolution;
            shadowSliceData.shadowTransform = Matrix4x4.identity;
            
            ApplyShadowTransform(ref shadowSliceData, resolution);
            
            return success;
        }

        private void ApplyShadowTransform(ref ShadowSliceData shadowSliceData, int resolution)
        {
            // Currently CullResults ComputeDirectionalShadowMatricesAndCullingPrimitives doesn't
            // apply z reversal to projection matrix. We need to do it manually here.
            var proj = shadowSliceData.projectionMatrix;
            var view = shadowSliceData.viewMatrix;
            if (SystemInfo.usesReversedZBuffer)
            {
                proj.m20 = -proj.m20;
                proj.m21 = -proj.m21;
                proj.m22 = -proj.m22;
                proj.m23 = -proj.m23;
            }

            //lu:apply shadow matrix
            Matrix4x4 worldToShadow = proj * view;

            var textureScaleAndBias = Matrix4x4.identity;
            textureScaleAndBias.m00 = 0.5f;
            textureScaleAndBias.m11 = 0.5f;
            textureScaleAndBias.m22 = 0.5f;
            textureScaleAndBias.m03 = 0.5f;
            textureScaleAndBias.m23 = 0.5f;
            textureScaleAndBias.m13 = 0.5f;
            // textureScaleAndBias maps texture space coordinates from [-1,1] to [0,1]

            // Apply texture scale and offset to save a MAD in shader.
            var shadowTransform = textureScaleAndBias * worldToShadow;
            
            //lu: apply slice transform
            Matrix4x4 sliceTransform = Matrix4x4.identity;
            float oneOverAtlasWidth = 1.0f / resolution;
            float oneOverAtlasHeight = 1.0f / resolution;
            sliceTransform.m00 = shadowSliceData.resolution * oneOverAtlasWidth;
            sliceTransform.m11 = shadowSliceData.resolution * oneOverAtlasHeight;
            sliceTransform.m03 = shadowSliceData.offsetX * oneOverAtlasWidth;
            sliceTransform.m13 = shadowSliceData.offsetY * oneOverAtlasHeight;
            
            shadowSliceData.shadowTransform = sliceTransform * shadowTransform;
        }

        private void Clear()
        {
            
        }
    }
    
}

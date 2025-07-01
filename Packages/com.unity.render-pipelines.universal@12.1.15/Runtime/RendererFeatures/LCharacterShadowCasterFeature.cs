using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


namespace UnityEngine.Rendering.Universal
{

    [Serializable]
    internal class LCharacterShadowSetting
    {
        internal enum Quality
        {
            LOW,
            MEDIUM,
            HIGH
        }

        [SerializeField] internal bool CharacterShadowSwitch = false;
        [SerializeField] internal bool SoftShadow = false;
        [SerializeField] internal Color ShadowColor = Color.black;
        [SerializeField][Range(0f, 1f)] internal float ShadowOpacity = 0.5f;
        [SerializeField] internal Quality ShadowQuality = Quality.LOW;
        [SerializeField][Range(0f, 1f)] internal float ShadowDepthBias = 0.5f;
    }
    internal class LCharacterShadowCasterFeature : ScriptableRendererFeature
    {
        [SerializeField] internal LCharacterShadowSetting mCharacterShadowSetting = new LCharacterShadowSetting();
        
        public Material ScreenSpaceShadowMaterial;
        private LCharacterShadowCasterPass mCharacterShadowCasterPass;
        private LSoftScreenShadowPass mSoftScreenShadowPass;
        public override void Create()
        {
            mCharacterShadowCasterPass = new LCharacterShadowCasterPass();
            mCharacterShadowCasterPass.renderPassEvent = RenderPassEvent.BeforeRendering;
            mSoftScreenShadowPass = new LSoftScreenShadowPass(ScreenSpaceShadowMaterial);
            mSoftScreenShadowPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            //if(renderingData.cameraData.cameraType != CameraType.Game) return;
            mCharacterShadowCasterPass.Setup(mCharacterShadowSetting);
            mSoftScreenShadowPass.Setup(mCharacterShadowSetting);
            renderer.EnqueuePass(mCharacterShadowCasterPass);
            renderer.EnqueuePass(mSoftScreenShadowPass);
        }
    
        public class LCharacterShadowCasterPass : ScriptableRenderPass
        {
            private RenderTargetHandle mCharacterShadowmap;
            private int mWorldToShadowMatrixID;
            private int mShadowDepthBiasID;

            private ShaderTagId mShaderTagId = new ShaderTagId("LShadowCaster");
            private ProfilingSampler mProfilingSampler = new ProfilingSampler("LCharacterShadowCasterPass");
        
            private Matrix4x4[] mCharacterShadowMatrices;

            private int mSize;
            private float mDepthBias;
            
            public LCharacterShadowCasterPass()
            {
                mCharacterShadowMatrices = new Matrix4x4[4];
                mCharacterShadowmap.Init("_CharacterShadowmap");
                
                mWorldToShadowMatrixID = Shader.PropertyToID("_WorldToShadowMatrix");
                mShadowDepthBiasID = Shader.PropertyToID("_ShadowDepthBias");
            }

            public void Setup(LCharacterShadowSetting setting)
            {
                switch (setting.ShadowQuality)
                {
                    case LCharacterShadowSetting.Quality.LOW:
                        mSize = 256;
                        break;
                    case LCharacterShadowSetting.Quality.MEDIUM:
                        mSize = 512;
                        break;
                    case LCharacterShadowSetting.Quality.HIGH:
                        mSize = 1024;
                        break;
                }
                
                mDepthBias = setting.ShadowDepthBias;
            }
            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                if (mSize == 0) return;
                RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
                descriptor.width = mSize;
                descriptor.height = mSize;
                descriptor.colorFormat = RenderTextureFormat.Depth;
                descriptor.depthBufferBits = 32;
            
                cmd.GetTemporaryRT(mCharacterShadowmap.id, descriptor);
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                ConfigureTarget(mCharacterShadowmap.Identifier(), mCharacterShadowmap.Identifier());
                ConfigureClear(ClearFlag.Depth, Color.clear);
            }
            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                var camera = renderingData.cameraData.camera;
                var data = CharacterShadowData.GetCharacterShadowData();
                if (data.Length == 0) return;
            
                int shadowLightIndex = renderingData.lightData.mainLightIndex;
                if (shadowLightIndex == -1) return;
                VisibleLight shadowLight = renderingData.lightData.visibleLights[shadowLightIndex];
            
                var cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, mProfilingSampler))
                {
                    for (int i = 0; i < data.Length; i++)
                    {
                        var filteringSetting = new FilteringSettings(RenderQueueRange.opaque, LayerMask.GetMask("Character"), data[i].characterID);
                        var drawingSettings = CreateDrawingSettings(mShaderTagId, ref renderingData, SortingCriteria.CommonOpaque);

                        float res = mSize / 2.0f;
                        float offsetX = (i % 2.0f) * res;
                        float offsetY = (i / 2.0f) * res;

                        mCharacterShadowMatrices[i] = GetWorldToShadowMatrix(data[i].viewMatrix, data[i].projectionMatrix, new Vector2(offsetX, offsetY), res, mSize);
                    
                        cmd.SetViewport(new Rect(offsetX, offsetY, res, res));
                        cmd.SetViewProjectionMatrices(data[i].viewMatrix, data[i].projectionMatrix);
                    
                        context.ExecuteCommandBuffer(cmd);
                        cmd.Clear();
                        context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSetting);
                        
                        cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);
                    }
                }
            
            
                cmd.SetGlobalTexture(mCharacterShadowmap.id, mCharacterShadowmap.Identifier());
                cmd.SetGlobalMatrixArray(mWorldToShadowMatrixID, mCharacterShadowMatrices);
                cmd.SetGlobalFloat(mShadowDepthBiasID, mDepthBias * 0.2f);
            
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(mCharacterShadowmap.id);
            }
        
            private Matrix4x4 GetWorldToShadowMatrix(Matrix4x4 view, Matrix4x4 proj, Vector2 offset, float resulution, float size)
            {
                if (SystemInfo.usesReversedZBuffer)
                {
                    proj.m20 = -proj.m20;
                    proj.m21 = -proj.m21;
                    proj.m22 = -proj.m22;
                    proj.m23 = -proj.m23;
                }
                Matrix4x4 matrix = proj * view;
            
                var textureScaleAndBias = Matrix4x4.identity;
                textureScaleAndBias.m00 = 0.5f;
                textureScaleAndBias.m11 = 0.5f;
                textureScaleAndBias.m22 = 0.5f;
                textureScaleAndBias.m03 = 0.5f;
                textureScaleAndBias.m23 = 0.5f;
                textureScaleAndBias.m13 = 0.5f;
            
                Matrix4x4 sliceTransform = Matrix4x4.identity;
                float oneOverAtlasWidth = 1.0f / size;
                float oneOverAtlasHeight = 1.0f / size;
                sliceTransform.m00 = resulution * oneOverAtlasWidth;
                sliceTransform.m11 = resulution * oneOverAtlasHeight;
                sliceTransform.m03 = offset.x * oneOverAtlasWidth;
                sliceTransform.m13 = offset.y * oneOverAtlasHeight;

                return sliceTransform * textureScaleAndBias * matrix;
            }
        }

        public class LSoftScreenShadowPass : ScriptableRenderPass
        {
            private ProfilingSampler mShadowCombineSampler = new ProfilingSampler("L Screen Shadow Pass");
            private Material mShadowCombineMaterial;
            //RenderTarget
            private RenderTargetHandle mTarget;
            private RenderTargetIdentifier mDepthHandler;

            private Mesh mQubeMesh;

            private int mCharacterID;
            private int mCharacterShadowmapSizeID;
            private int mShadowCombineParamID;
            
            private float mShadowDepthBias;
            private float mCharacterShadowmapSize;
            private float mShadowOpacity;
            private Color mShadowColor;

            public LSoftScreenShadowPass(Material mat)
            {
                mShadowCombineMaterial = mat;
                mTarget.Init("_LScreenShadowTexture");
                mCharacterID = Shader.PropertyToID("_CharacterID");
                mCharacterShadowmapSizeID = Shader.PropertyToID("_CharacterShadowmapSize");
                mShadowCombineParamID = Shader.PropertyToID("_ShadowCombineParam");
            }

            public void Setup(LCharacterShadowSetting setting)
            {
                switch (setting.ShadowQuality)
                {
                    case LCharacterShadowSetting.Quality.LOW:
                        mCharacterShadowmapSize = 256;
                        break;
                    case LCharacterShadowSetting.Quality.MEDIUM:
                        mCharacterShadowmapSize = 512;
                        break;
                    case LCharacterShadowSetting.Quality.HIGH:
                        mCharacterShadowmapSize = 1024;
                        break;
                }
                
                mShadowColor = setting.ShadowColor;
                mShadowOpacity = setting.ShadowOpacity;
            }
            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var desc = renderingData.cameraData.cameraTargetDescriptor;
                desc.depthBufferBits = 0;
                desc.msaaSamples = 1;
                desc.graphicsFormat = RenderingUtils.SupportsGraphicsFormat(GraphicsFormat.R8_UNorm, FormatUsage.Linear | FormatUsage.Render)
                    ? GraphicsFormat.R8_UNorm
                    : GraphicsFormat.B8G8R8A8_UNorm;
                cmd.GetTemporaryRT(mTarget.id, desc, FilterMode.Bilinear);
                mDepthHandler = renderingData.cameraData.renderer.cameraColorTarget;
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                ConfigureTarget(mTarget.Identifier(), mDepthHandler);
                ConfigureClear(ClearFlag.None, Color.clear);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (mQubeMesh == null) 
                    mQubeMesh = CreateQubeMesh();
                var cmd = CommandBufferPool.Get();
                var cameraData = renderingData.cameraData;
                var shadowData = CharacterShadowData.characterShadowList;
                var destination = renderingData.cameraData.renderer.GetCameraColorFrontBuffer(cmd);
                using (new ProfilingScope(cmd, mShadowCombineSampler))
                {
                    cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mShadowCombineMaterial,0, 0);
                    cmd.SetViewProjectionMatrices(cameraData.camera.worldToCameraMatrix, cameraData.camera.projectionMatrix);
                    for (int i = 0; i < shadowData.Count; i++)
                    {
                        var shadow = shadowData[i];
                        cmd.SetGlobalInt(mCharacterID, i);
                        cmd.SetGlobalVector(mCharacterShadowmapSizeID, new Vector4(mCharacterShadowmapSize, mCharacterShadowmapSize, 1.0f/mCharacterShadowmapSize, 1.0f/mCharacterShadowmapSize));
                        cmd.DrawMesh(mQubeMesh, shadow.worldMatrix, mShadowCombineMaterial, 0, 1);
                    }
                    
                    cmd.SetGlobalVector(mShadowCombineParamID, new Vector4(mShadowColor.r, mShadowColor.g, mShadowColor.b, mShadowOpacity));
                    cmd.SetRenderTarget(destination);
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mShadowCombineMaterial, 0, 2);
                    cameraData.renderer.SwapColorBuffer(cmd);
                }
                cmd.SetGlobalTexture(mTarget.id, mTarget.Identifier());
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(mTarget.id);
            }

            private Mesh CreateQubeMesh()
            {
                var mesh = new Mesh();
                Vector3[] vertices = {
                    // 前面
                    new Vector3(-0.5f, -0.5f,  0.5f),
                    new Vector3( 0.5f, -0.5f,  0.5f),
                    new Vector3( 0.5f,  0.5f,  0.5f),
                    new Vector3(-0.5f,  0.5f,  0.5f),
                    // 后面
                    new Vector3(-0.5f, -0.5f, -0.5f),
                    new Vector3( 0.5f, -0.5f, -0.5f),
                    new Vector3( 0.5f,  0.5f, -0.5f),
                    new Vector3(-0.5f,  0.5f, -0.5f),
                };
                int[] indices = {
                    // 前
                    0, 2, 1, 0, 3, 2,
                    // 右
                    1, 2, 6, 6, 5, 1,
                    // 后
                    5, 6, 7, 7, 4, 5,
                    // 左
                    4, 7, 3, 3, 0, 4,
                    // 上
                    3, 7, 6, 6, 2, 3,
                    // 下
                    4, 0, 1, 1, 5, 4
                };
                mesh.vertices = vertices;
                mesh.triangles = indices;
                return mesh;
            }
        }
    }
}

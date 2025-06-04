using System;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering.Universal.Internal;

namespace UnityEngine.Rendering.Universal
{
    [Serializable]
    internal class LAntiAliasingSettings
    {
        internal enum Type
        {
            FXAA = 0,
            TAA = 1,
            NONE = 2
        }
        internal enum Quality
        {
            LOW = 0,
            MEDIUM = 1,
            HIGH = 2
        }

        internal enum ComputeMode
        {
            FAST = 0,
            ACCURATE = 1
        }
        
        internal enum DepthTextureMode
        {
            AfterOpaque = 0,
            ForcePrepass = 1
        }
        
        [SerializeField]internal Type AAType = Type.NONE;
        //FXAA
        [SerializeField]internal Quality FXAAQuality = Quality.LOW;
        [SerializeField]internal ComputeMode FXAAComputeMode = ComputeMode.FAST;
        [SerializeField]internal float FXAAEdgeThresholdMin = 0.0625f;
        [SerializeField]internal float FXAAEdgeThreshold = 0.1875f;
        //TAA
        [SerializeField] internal DepthTextureMode TAADepthTextureMode;
    }
    internal class LAntiAliasing : ScriptableRendererFeature
    {
    
        [SerializeField]private LAntiAliasingSettings mSettings = new LAntiAliasingSettings();
        private Shader mAAShader;
        private Material mAAMaterial;
        //MotionVector Param
        private Shader mMotionVectorShader;
        private Material mMotionVectorMaterial;
        private FXAAPass mFXAAPass;
        private TAAPass mTAAPass;
        private MotionVectorPass mMotionVectorPass;

        public override void Create()
        {
            mFXAAPass = new FXAAPass();
            mFXAAPass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
            
            mTAAPass = new TAAPass();
            mTAAPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents+1;
            
            mMotionVectorPass = new MotionVectorPass();
            mMotionVectorPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
            
            GetMaterial();
            GetMotionVectorMaterial();
            ShaderConstents.FrameCount = 0;

        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!GetMaterial())
            {
                Debug.LogError("运行时找不到抗锯齿Shader，请检查资源或重编译Feature");
                return;
            }

            if (renderingData.cameraData.camera.cameraType != CameraType.Game) return;

            if (mSettings.AAType == LAntiAliasingSettings.Type.FXAA)
            {
                mFXAAPass.Setup(mSettings, mAAMaterial);
                renderer.EnqueuePass(mFXAAPass);
            }
            else if (mSettings.AAType == LAntiAliasingSettings.Type.TAA)
            {
                if (!GetMotionVectorMaterial())
                {
                    Debug.LogError("运行时找不到TAA所需的MotionVectorShader，请检查资源或重编译Feature");
                    return;
                }
                mMotionVectorPass.Setup(mMotionVectorMaterial, mSettings);
                renderer.EnqueuePass(mMotionVectorPass);
                mTAAPass.Setup(mAAMaterial);
                renderer.EnqueuePass(mTAAPass);
            }
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(mAAMaterial);
            CoreUtils.Destroy(mMotionVectorMaterial);
            mTAAPass.CleanLastFrame();
            mMotionVectorPass.CleanupObjectIDTextures();
        }
        

        private bool GetMaterial()
        {
            if (mAAMaterial != null)
            {
                return true;
            }
            if (mAAShader == null)
            {
                mAAShader = Shader.Find("Hidden/LURP/Feature/LAnitiAliasing");
                if (mAAShader == null)
                {
                    return false;
                }
            }
            
            mAAMaterial = CoreUtils.CreateEngineMaterial(mAAShader);
            return mAAMaterial != null;
        }
        
        private bool GetMotionVectorMaterial()
        {
            if (mMotionVectorMaterial != null)
            {
                return true;
            }

            if (mMotionVectorShader == null)
            {
                mMotionVectorShader = Shader.Find("Hidden/LURP/Feature/LMotionVector");
                if (mMotionVectorShader == null)
                {
                    Debug.LogError("找不到 Hidden/LURP/Feature/LMotionVector shader资源");
                    return false;
                }
            }
            
            mMotionVectorMaterial = CoreUtils.CreateEngineMaterial(mMotionVectorShader);
            return mMotionVectorMaterial != null;
        }
        
        internal class FXAAPass : ScriptableRenderPass
        {
            private ProfilingSampler mAntiAliasingSampler = new ProfilingSampler("FXAA Pass");
            
            private Material mMaterial;
            private int mQuality;
            private int mComputeMode;
            
            //vector
            private Vector4 mFXAAParams;
            
            public void Setup(LAntiAliasingSettings settings, Material material)
            {
                mMaterial = material;
                mQuality = (int)settings.FXAAQuality;
                mComputeMode = (int)settings.FXAAComputeMode;
                mFXAAParams = new Vector4(settings.FXAAEdgeThreshold, settings.FXAAEdgeThresholdMin, 0, 0);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                //获取当前渲染RT设置为source
                var cmd = CommandBufferPool.Get();
                var desc = renderingData.cameraData.cameraTargetDescriptor;
                int width = desc.width;
                int height = desc.height;
                var renderer = renderingData.cameraData.renderer;
                using (new ProfilingScope(cmd, mAntiAliasingSampler))
                {
                    SetGlobalConstents(cmd, width, height);
                    cmd.SetRenderTarget(renderer.GetCameraColorFrontBuffer(cmd));
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mMaterial,0,0);
                    renderer.SwapColorBuffer(cmd);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            private void SetGlobalConstents(CommandBuffer cmd, int width, int height)
            {

                switch (mQuality)
                {
                    case (int)LAntiAliasingSettings.Quality.LOW:
                        mMaterial.EnableKeyword("QUALITY_LOW");
                        mMaterial.DisableKeyword("QUALITY_MEDIUM");
                        mMaterial.DisableKeyword("QUALITY_HIGH");
                        break;
                    case (int)LAntiAliasingSettings.Quality.MEDIUM:
                        mMaterial.DisableKeyword("QUALITY_LOW");
                        mMaterial.EnableKeyword("QUALITY_MEDIUM");
                        mMaterial.DisableKeyword("QUALITY_HIGH");
                        break;
                    case (int)LAntiAliasingSettings.Quality.HIGH:
                        mMaterial.DisableKeyword("QUALITY_LOW");
                        mMaterial.DisableKeyword("QUALITY_MEDIUM");
                        mMaterial.EnableKeyword("QUALITY_HIGH");
                        break;
                }

                if (mComputeMode == 0)mMaterial.EnableKeyword("COMPUTE_FAST");
                else mMaterial.DisableKeyword("COMPUTE_FAST");
                
                cmd.SetGlobalVector(ShaderConstents.FXAAParamsId, mFXAAParams);
                cmd.SetGlobalVector(ShaderConstents.CameraColorSizeId, new Vector4(width, height,1.0f / width, 1.0f / height));
            }
            
        }

        internal class TAAPass : ScriptableRenderPass
        {
            private Material mTAAMaterial;
            
            private ProfilingSampler mAntiAliasingSampler = new ProfilingSampler("TAAPass");
            
            
            //上一帧RT
            private RenderTexture mLastFrame;
            public void Setup(Material mat)
            {
                mTAAMaterial = mat;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var desc = renderingData.cameraData.cameraTargetDescriptor;
                if (mLastFrame == null) mLastFrame = RenderTexture.GetTemporary(desc);
            }


            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                var renderer = renderingData.cameraData.renderer;
                var cameraData = renderingData.cameraData;
                //get halton sequence
                //we take x on base 2 and y on base 3
                // 8 frames for a loop
                int index = ShaderConstents.FrameCount % 7 + 1;
                float x = HaltonSequence.Get(index, 2);
                float y = HaltonSequence.Get(index, 3);

                x = (x - 0.5f) / cameraData.camera.pixelWidth;
                y = (y - 0.5f) / cameraData.camera.pixelHeight;
                
                var cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, mAntiAliasingSampler))
                {
                    var source = renderer.GetCameraColorFrontBuffer(cmd);
                    cmd.SetRenderTarget(source);
                    int flag = 0;
                    if (ShaderConstents.FrameCount > 0)
                    {
                        cmd.SetGlobalTexture(ShaderConstents.LastFrameId, mLastFrame);
                        flag = 1;
                    }
                    cmd.SetGlobalVector(ShaderConstents.JitterId, new Vector4(x, y, flag, 0));
                    cmd.SetGlobalVector(ShaderConstents.TAAParamsId, new Vector4(0.7f, 0.95f, 6000.0f, 0.3f));
                    
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mTAAMaterial,0,1);
                    cmd.Blit(source, mLastFrame);
                    
                    renderer.SwapColorBuffer(cmd);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
                
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                ShaderConstents.FrameCount++;
            }

            //清理持久化图片
            public void CleanLastFrame()
            {
                if (mLastFrame != null) RenderTexture.ReleaseTemporary(mLastFrame);
            }
        }

        internal class MotionVectorPass : ScriptableRenderPass
        {
            #region Fields

            static readonly string[] s_ShaderTags = new string[] { "LMotionVectors" };
            
            //ID图使用持久化 MotionVector为每帧生成
            private RenderTexture[] mObjectIDTextures = new RenderTexture[2];
            
            private RenderStateBlock m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
            private RenderTargetIdentifier m_DepthIdentifier;
            private Material mMaterial;

            private int mWidth = 0;
            private int mHeight = 0;
            
            PreviousFrameData m_MotionData;
            LAntiAliasingSettings m_Settings;
            ProfilingSampler m_ProfilingSampler = ProfilingSampler.Get(URPProfileId.MotionVectors);
            #endregion

            #region State
            internal void Setup(Material material, LAntiAliasingSettings settings)
            {
                mMaterial = material;
                m_Settings = settings;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var cameraData = renderingData.cameraData;
                var camera = cameraData.camera;
                
                //TODO: only base camera can draw
                SupportedRenderingFeatures.active.motionVectors = true;
                m_MotionData = MotionVectorRendering.instance.GetMotionDataForCamera(camera, cameraData);

                //if force prepass with no depth priming, the depth target is colortarget, no extra depthattachment
                if (m_Settings.TAADepthTextureMode == LAntiAliasingSettings.DepthTextureMode.ForcePrepass)
                {
                    m_DepthIdentifier = cameraData.renderer.cameraColorTarget;
                }
                else
                {
                    m_DepthIdentifier = cameraData.renderer.cameraDepthTarget;
                }

                //Setup DepthState if we write depth to depthbuffer already
                // if (cameraData.renderer.useDepthPriming)
                // {
                //     m_RenderStateBlock.depthState = new DepthState(false, CompareFunction.LessEqual);
                //     m_RenderStateBlock.mask |= RenderStateMask.Depth;
                // }
                // else
                // {
                //     m_RenderStateBlock.depthState = new DepthState(true, CompareFunction.LessEqual);
                //     m_RenderStateBlock.mask |= RenderStateMask.Depth;
                // }
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                //Init RT
                //decs0 -- motionvector decs1 -- objectID
                var desc0 = cameraTextureDescriptor;
                var desc1 = cameraTextureDescriptor;
                desc0.graphicsFormat = GraphicsFormat.R8G8_UNorm;
                desc1.graphicsFormat = GraphicsFormat.R8_UNorm;
                desc0.depthBufferBits = 0;
                desc1.depthBufferBits = 0;
                desc0.depthStencilFormat = GraphicsFormat.None;
                desc1.depthStencilFormat = GraphicsFormat.None;
            
                GenerateObjectIDTextures(desc1);
                cmd.GetTemporaryRT(ShaderConstents.MotionVectorTextureId, desc0, FilterMode.Point);
                
                var motionVectorIdentifier = new RenderTargetIdentifier(ShaderConstents.MotionVectorTextureId);
                var ObjectIDIdentifier = mObjectIDTextures[ShaderConstents.FrameCount % 2];
                
                var identifiers = new RenderTargetIdentifier[] { motionVectorIdentifier, ObjectIDIdentifier };
                ConfigureTarget(identifiers, m_DepthIdentifier);
                // ConfigureClear(ClearFlag.None, Color.clear);
            }

            #endregion

            #region Execution

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                // Get data
                ref var cameraData = ref renderingData.cameraData;
                Camera camera = cameraData.camera;
                MotionVectorsPersistentData motionData = null;

                if (camera.TryGetComponent<UniversalAdditionalCameraData>(out var additionalCameraData))
                    motionData = additionalCameraData.motionVectorsPersistentData;

                if (motionData == null)
                    return;

                // Never draw in Preview
                if (camera.cameraType == CameraType.Preview)
                    return;

                // Profiling command
                CommandBuffer cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, m_ProfilingSampler))
                {
                    ExecuteCommand(context, cmd);
                    Shader.SetGlobalMatrix(ShaderConstents.PrevViewProjMatrixId, m_MotionData.previousViewProjectionMatrix);
                    cmd.SetGlobalVector(ShaderConstents.CameraColorSizeId, new Vector4(camera.pixelWidth, camera.pixelHeight, 1.0f / camera.pixelWidth, 1.0f / camera.pixelHeight));
                    
                    // These flags are still required in SRP or the engine won't compute previous model matrices...
                    // If the flag hasn't been set yet on this camera, motion vectors will skip a frame.
                    camera.depthTextureMode |= DepthTextureMode.MotionVectors | DepthTextureMode.Depth;

                    // TODO: add option to only draw either one?
                    DrawCameraMotionVectors(context, cmd, camera);
                    DrawObjectMotionVectors(context, ref renderingData, camera);
                    
                    cmd.SetGlobalTexture(ShaderConstents.lastObjectIDTextureId, mObjectIDTextures[ShaderConstents.FrameCount % 2]);
                    cmd.SetGlobalTexture(ShaderConstents.curObjectIDTextureId, mObjectIDTextures[(ShaderConstents.FrameCount + 1) % 2]);

                }
                ExecuteCommand(context, cmd);
                CommandBufferPool.Release(cmd);
            }

            DrawingSettings GetOpaqueDrawingSettings(ref RenderingData renderingData)
            {
                var camera = renderingData.cameraData.camera;
                var sortingSettings = new SortingSettings(camera) { criteria = SortingCriteria.CommonOpaque };
                var drawingSettings = new DrawingSettings(ShaderTagId.none, sortingSettings)
                {
                    perObjectData = PerObjectData.MotionVectors,
                    enableDynamicBatching = renderingData.supportsDynamicBatching,
                    enableInstancing = true,
                };

                for (int i = 0; i < s_ShaderTags.Length; ++i)
                {
                    drawingSettings.SetShaderPassName(i, new ShaderTagId(s_ShaderTags[i]));
                }

                // Material that will be used if shader tags cannot be found
                drawingSettings.fallbackMaterial = mMaterial;

                return drawingSettings;
            }

            DrawingSettings GetTransparentDrawingSettings(ref RenderingData renderingData)
            {
                var camera = renderingData.cameraData.camera;
                var sortingSettings = new SortingSettings(camera) { criteria = SortingCriteria.CommonTransparent };
                var drawingSettings = new DrawingSettings(ShaderTagId.none, sortingSettings);

                for (int i = 0; i < s_ShaderTags.Length; ++i)
                {
                    drawingSettings.SetShaderPassName(i, new ShaderTagId(s_ShaderTags[i]));
                }

                drawingSettings.fallbackMaterial = mMaterial;

                return drawingSettings;
            }

            void DrawCameraMotionVectors(ScriptableRenderContext context, CommandBuffer cmd, Camera camera)
            {
                cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mMaterial,0,1);
                ExecuteCommand(context, cmd);
            }

            void DrawObjectMotionVectors(ScriptableRenderContext context, ref RenderingData renderingData, Camera camera)
            {
                var opaqueDrawing = GetOpaqueDrawingSettings(ref renderingData);
                var opauqeFilter = new FilteringSettings(RenderQueueRange.opaque, camera.cullingMask);

                var transDrawing = GetTransparentDrawingSettings(ref renderingData);
                var transFilter = new FilteringSettings(RenderQueueRange.transparent, camera.cullingMask);
                var renderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
                // Draw Renderers 
                //opaque
                context.DrawRenderers(renderingData.cullResults, ref opaqueDrawing, ref opauqeFilter, ref renderStateBlock);
                //transparent
                context.DrawRenderers(renderingData.cullResults, ref transDrawing, ref transFilter, ref renderStateBlock);
            }

            #endregion

            #region RTLifeCycle

            public override void FrameCleanup(CommandBuffer cmd)
            {
                if (cmd == null)
                    throw new ArgumentNullException("cmd");
                
                cmd.ReleaseTemporaryRT(ShaderConstents.MotionVectorTextureId);
            }

            private void GenerateObjectIDTextures(RenderTextureDescriptor desc)
            {
                if(mObjectIDTextures[0] == null) mObjectIDTextures[0] = RenderTexture.GetTemporary(desc);
                if(mObjectIDTextures[1] == null) mObjectIDTextures[1] = RenderTexture.GetTemporary(desc);

                if (mWidth != desc.width || mHeight != desc.height)
                {
                    mWidth = desc.width;
                    mHeight = desc.height;
                    
                    RenderTexture.ReleaseTemporary(mObjectIDTextures[0]);
                    RenderTexture.ReleaseTemporary(mObjectIDTextures[1]);

                    mObjectIDTextures[0] = RenderTexture.GetTemporary(desc);
                    mObjectIDTextures[1] = RenderTexture.GetTemporary(desc);                    
                }
            }

            public void CleanupObjectIDTextures()
            {
                RenderTexture.ReleaseTemporary(mObjectIDTextures[0]);
                RenderTexture.ReleaseTemporary(mObjectIDTextures[1]);
                mObjectIDTextures[0] = null;
                mObjectIDTextures[1] = null;
            }

            #endregion

            #region CommandBufer
            void ExecuteCommand(ScriptableRenderContext context, CommandBuffer cmd)
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            }

            #endregion
        }
        
        internal static class ShaderConstents
        {
            //RT
            public static readonly int curObjectIDTextureId = Shader.PropertyToID("_LCurrentObjectIDTexture");
            public static readonly int lastObjectIDTextureId = Shader.PropertyToID("_LLastObjectIDTexture");
            public static readonly int LastFrameId = Shader.PropertyToID("_LLastFrame");
            public static readonly int MotionVectorTextureId = Shader.PropertyToID("_LMotionVectorTexture");
            
            //Param
            public static readonly int JitterId = Shader.PropertyToID("_Jitter");
            public static readonly int CameraColorSizeId = Shader.PropertyToID("_CameraColorSize");
            public static readonly int CameraDepthSizeId = Shader.PropertyToID("_CameraDepthSize");
            public static readonly int FXAAParamsId = Shader.PropertyToID("_FXAAParams");
            public static readonly int PrevViewProjMatrixId = Shader.PropertyToID("_PrevViewProjMatrix");
            public static readonly int TAAParamsId = Shader.PropertyToID("_TAAParams");

            public static int FrameCount;
        }
    }
}

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
        
        [SerializeField]internal Type AAType = Type.NONE;
        //FXAA
        [SerializeField]internal Quality FXAAQuality = Quality.LOW;
        [SerializeField]internal ComputeMode FXAAComputeMode = ComputeMode.FAST;
        [SerializeField]internal float FXAAEdgeThresholdMin = 0.0625f;
        [SerializeField]internal float FXAAEdgeThreshold = 0.1875f;
        //TAA
        [SerializeField]internal Quality TAAQuality = Quality.LOW;
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
            mMotionVectorPass = new MotionVectorPass();
            GetMaterial();
            GetMotionVectorMaterial();

        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!GetMaterial())
            {
                Debug.LogError("运行时找不到抗锯齿Shader，请检查资源或重编译Feature");
                return;
            }

            if (mSettings.AAType == LAntiAliasingSettings.Type.FXAA)
            {
                mFXAAPass.Setup(mSettings, mAAMaterial);
                renderer.EnqueuePass(mFXAAPass);
            }

            if (mSettings.AAType == LAntiAliasingSettings.Type.TAA)
            {
                if (!GetMotionVectorMaterial())
                {
                    Debug.LogError("运行时找不到TAA所需的MotionVectorShader，请检查资源或重编译Feature");
                    return;
                }
                mMotionVectorPass.Setup(mMotionVectorMaterial);
                renderer.EnqueuePass(mMotionVectorPass);
            }
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(mAAMaterial);
            CoreUtils.Destroy(mMotionVectorMaterial);
            
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
            private RenderTargetHandle mTarget;
            private int mQuality;
            private int mComputeMode;
            
            //Shader Property
            private int mSourceSizeId;
            private int mAAParamsId;
            
            //vector
            private Vector4 mAAParams;
            public FXAAPass()
            {
                mTarget.Init("FXAATexture");
                
                mSourceSizeId = Shader.PropertyToID("SourceSize");
                mAAParamsId = Shader.PropertyToID("FXAAParams");
            }

            public void Setup(LAntiAliasingSettings settings, Material material)
            {
                mMaterial = material;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var desc = renderingData.cameraData.cameraTargetDescriptor;
                cmd.GetTemporaryRT(mTarget.id, desc, FilterMode.Bilinear);
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                ConfigureTarget(mTarget.Identifier());
                ConfigureInput(ScriptableRenderPassInput.Motion);
                ConfigureClear(ClearFlag.None, Color.clear);
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
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mMaterial,0,0);
                    var destination = renderer.GetCameraColorFrontBuffer(cmd);
                    cmd.Blit(mTarget.Identifier(), destination);
                    renderer.SwapColorBuffer(cmd);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(mTarget.id);
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

                if (mComputeMode == 0)
                {
                    mMaterial.EnableKeyword("COMPUTE_FAST");
                }
                else
                {
                    mMaterial.DisableKeyword("COMPUTE_FAST");
                }
                cmd.SetGlobalVector(mAAParamsId, mAAParams);
                cmd.SetGlobalVector(mSourceSizeId, new Vector4(width, height,1.0f / width, 1.0f / height));
            }
            
        }

        internal class TAAPass : ScriptableRenderPass
        {
            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                throw new NotImplementedException();
            }
        }

        internal class MotionVectorPass : ScriptableRenderPass
        {
            #region Fields
            const string kMotionVectorTexture = "_MotionVectorTexture";
            const string kObjectIDTexture = "_ObjectIDTexture";

            static readonly string[] s_ShaderTags = new string[] { "LMotionVectors" };
            
            private RenderTargetIdentifier[] m_ColorIdentifiers = new RenderTargetIdentifier[2];
            private RenderTargetHandle[] m_Handles = new RenderTargetHandle[2];
            private RenderStateBlock m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
            private RenderTargetIdentifier m_DepthIdentifier;
            private Material mMaterial;

            private int mScreenSizeId;
            private int mPrevViewProjMatrixId;
            
            
            PreviousFrameData m_MotionData;
            ProfilingSampler m_ProfilingSampler = ProfilingSampler.Get(URPProfileId.MotionVectors);
            #endregion

            #region Constructors
            internal MotionVectorPass()
            {
                renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
                
                //Init RT Handle
                m_Handles[0].Init(kMotionVectorTexture);
                m_Handles[1].Init(kObjectIDTexture);
                m_ColorIdentifiers[0] = m_Handles[0].Identifier();
                m_ColorIdentifiers[1] = m_Handles[1].Identifier();

                mScreenSizeId = Shader.PropertyToID("ScreenSize");
                mPrevViewProjMatrixId = Shader.PropertyToID("PrevViewProjMatrix");
            }

            #endregion

            #region State
            internal void Setup(Material material)
            {
                mMaterial = material;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var cameraData = renderingData.cameraData;
                var camera = cameraData.camera;
                
                //TODO: only base camera can draw
                SupportedRenderingFeatures.active.motionVectors = true;
                m_MotionData = MotionVectorRendering.instance.GetMotionDataForCamera(camera, cameraData);
                m_DepthIdentifier = renderingData.cameraData.renderer.cameraDepthTarget;
                
                //Setup DepthState if we write depth to depthbuffer already
                if (cameraData.renderer.useDepthPriming)
                {
                    m_RenderStateBlock.depthState = new DepthState(false, CompareFunction.Equal);
                    m_RenderStateBlock.mask |= RenderStateMask.Depth;
                }
                else
                {
                    m_RenderStateBlock.depthState = new DepthState(true, CompareFunction.LessEqual);
                    m_RenderStateBlock.mask |= RenderStateMask.Depth;
                }
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                //Init RT
                var desc0 = cameraTextureDescriptor;
                var desc1 = cameraTextureDescriptor;
#if UNITY_STANDALONE || UNITY_EDITOR
                desc0.graphicsFormat = GraphicsFormat.R16G16_SFloat;
#elif UNITY_ANDROID || UNITY_IOS
                desc0.graphicsFormat = GraphicsFormat.R8G8_UNorm;
#endif
                desc1.graphicsFormat = GraphicsFormat.R8_UInt;
                desc0.depthBufferBits = 0;
                desc1.depthBufferBits = 0;
                desc0.depthStencilFormat = GraphicsFormat.None;
                desc1.depthStencilFormat = GraphicsFormat.None;
            
                cmd.GetTemporaryRT(m_Handles[0].id, desc0, FilterMode.Point);
                cmd.GetTemporaryRT(m_Handles[1].id, desc1, FilterMode.Point);
                ConfigureTarget(m_ColorIdentifiers, m_DepthIdentifier);
                ConfigureClear(ClearFlag.None, Color.black);
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
                    Shader.SetGlobalMatrix(mPrevViewProjMatrixId, m_MotionData.previousViewProjectionMatrix);
                    cmd.SetGlobalVector(mScreenSizeId, new Vector4(camera.pixelWidth, camera.pixelHeight, 1.0f / camera.pixelWidth, 1.0f / camera.pixelHeight));
                    
                    // These flags are still required in SRP or the engine won't compute previous model matrices...
                    // If the flag hasn't been set yet on this camera, motion vectors will skip a frame.
                    camera.depthTextureMode |= DepthTextureMode.MotionVectors | DepthTextureMode.Depth;

                    // TODO: add option to only draw either one?
                    DrawCameraMotionVectors(context, cmd, camera);
                    DrawObjectMotionVectors(context, ref renderingData, camera);
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
                // Draw fullscreen quad
                // cmd.DrawProcedural(Matrix4x4.identity, mMaterial, 1, MeshTopology.Triangles, 3, 1);
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
                context.DrawRenderers(renderingData.cullResults, ref opaqueDrawing, ref opauqeFilter, ref m_RenderStateBlock);
                //transparent
                context.DrawRenderers(renderingData.cullResults, ref transDrawing, ref transFilter, ref renderStateBlock);
            }

            #endregion

            #region Cleanup

            public override void FrameCleanup(CommandBuffer cmd)
            {
                if (cmd == null)
                    throw new ArgumentNullException("cmd");
                
                cmd.ReleaseTemporaryRT(m_Handles[0].id);
                cmd.ReleaseTemporaryRT(m_Handles[1].id);
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
    }
}

using System;

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

        internal class AntiAliasingPass : ScriptableRenderPass
        {
            private ProfilingSampler mAntiAliasingSampler = new ProfilingSampler("Anti Aliasing Pass");
            
            private Material mMaterial;
            private RenderTargetHandle mAntiAliasingTarget;
            private int mAAType;
            private int mQuality;
            private int mComputeMode;
            
            //Shader Property
            private int mSourceSizeId;
            private int mAAParamsId;
            
            //vector
            private Vector4 mAAParams;
            public AntiAliasingPass()
            {
                mAntiAliasingTarget.Init("AntiAliasingTexture");
                
                mSourceSizeId = Shader.PropertyToID("SourceSize");
                mAAParamsId = Shader.PropertyToID("AAParams");
            }

            public void Setup(LAntiAliasingSettings settings, Material material)
            {
                mMaterial = material;
                mAAType = (int)settings.AAType;
                switch (mAAType)
                {
                    case (int)LAntiAliasingSettings.Type.FXAA:
                        mQuality = (int)settings.FXAAQuality;
                        mComputeMode = (int)settings.FXAAComputeMode;
                        mAAParams = new Vector4(settings.FXAAEdgeThreshold, settings.FXAAEdgeThresholdMin,0.0f);
                        break;
                    case (int)LAntiAliasingSettings.Type.TAA:
                        mQuality = (int)settings.TAAQuality;
                        mComputeMode = -1;
                        mAAParams = new Vector4(0.0f,0.0f,0.0f,0.0f);
                        break;
                }
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var desc = renderingData.cameraData.cameraTargetDescriptor;
                cmd.GetTemporaryRT(mAntiAliasingTarget.id, desc, FilterMode.Bilinear);
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                ConfigureTarget(mAntiAliasingTarget.Identifier());
                ConfigureClear(ClearFlag.Color, Color.black);
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
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mMaterial, 0, mAAType);
                    var destination = renderer.GetCameraColorFrontBuffer(cmd);
                    cmd.Blit(mAntiAliasingTarget.Identifier(), destination);
                    renderer.SwapColorBuffer(cmd);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(mAntiAliasingTarget.id);
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
    
        [SerializeField]private LAntiAliasingSettings mSettings = new LAntiAliasingSettings();
        [SerializeField, HideInInspector] private Shader mAAShader;
        private Material mAAMaterial;
        private AntiAliasingPass mAAPass;

        public override void Create()
        {
            mAAPass = new AntiAliasingPass();
            mAAPass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
            GetMaterial();
            
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!GetMaterial())
            {
                Debug.LogError("运行时找不到抗锯齿Shader，请检查资源或重编译Feature");
                return;
            }

            if (mSettings.AAType != LAntiAliasingSettings.Type.NONE)
            {
                mAAPass.Setup(mSettings, mAAMaterial);
                renderer.EnqueuePass(mAAPass);
            }
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(mAAMaterial);
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
    }
}

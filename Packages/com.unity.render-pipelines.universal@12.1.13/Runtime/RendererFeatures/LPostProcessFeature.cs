
namespace UnityEngine.Rendering.Universal
{
    public class LPostProcessFeature : ScriptableRendererFeature
    {
        class PostProcessPass : ScriptableRenderPass
        {

            //profiling sampler
            private ProfilingSampler mPostProcessSampler     = new ProfilingSampler("Gbs PostProcess Pass");

            //shader keyword
            private const string mBlackWhiteFlashKeyword = "_ENABLE_BLACKWHITEFLASH";
            private const string mScatterBlurKeyword     = "_ENABLE_SCATTERBLUR";
            
            //shader properties
            private int mScatterBlurOffsetScale      = Shader.PropertyToID("_ScatterBlurOffsetScale");
            
            private int mBlackWhiteFlashPropID       = Shader.PropertyToID("_BlackWhiteFlashProp");
            private int mSketchPointOffsetAndScaleID = Shader.PropertyToID("_SketchPointOffsetAndScale");
            private int mSketchXYSpeedAndTimeScaleID = Shader.PropertyToID("_SketchXYSpeedAndTimeScale");
            private int mDarkPartColorID             = Shader.PropertyToID("_DarkPartColor");
            private int mBrightPartColorID           = Shader.PropertyToID("_BrightPartColor");


            //effect setting
            /*private GbsScatterBlur mScatterBlur;
            private GbsBlackWhiteFlash mBlackWhiteFlash;*/
            
            public PostProcessPass(Material postProcessMat)
            {
                
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                ClearShaderKeywords();
            }
            
            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                /*var cmd = CommandBufferPool.Get();
                var cameraData = renderingData.cameraData;
                var destination = cameraData.renderer.GetCameraColorFrontBuffer(cmd);
                
                var stack = VolumeManager.instance.stack;
                mBlackWhiteFlash = stack.GetComponent<GbsBlackWhiteFlash>();
                mScatterBlur = stack.GetComponent<GbsScatterBlur>();


                using (new ProfilingScope(cmd, mPostProcessSampler))
                {
                    if (mScatterBlur.IsActive())
                    {
                        SetupScatterBlur();
                        mPostProcessMaterial.EnableKeyword(mScatterBlurKeyword);
                    }
                    if (mBlackWhiteFlash.IsActive())
                    {
                        SetupBlackWhiteFlash();
                        mPostProcessMaterial.EnableKeyword(mBlackWhiteFlashKeyword);
                    }

                    if (mBlackWhiteFlash.IsActive() || mScatterBlur.IsActive())
                    {
                        cmd.Blit(null, destination, mPostProcessMaterial);
                        cameraData.renderer.SwapColorBuffer(cmd);
                    }
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);*/
            }
            
            public override void OnCameraCleanup(CommandBuffer cmd) { }

            private void SetupBlackWhiteFlash()
            {
                /*mPostProcessMaterial.SetVector(mBlackWhiteFlashPropID, new Vector4(mBlackWhiteFlash.BlackWhiteRange.value,
                                                                                        mBlackWhiteFlash.BlackToWhiteLerp.value,
                                                                                        mBlackWhiteFlash.SketchStrengh.value,
                                                                                        mBlackWhiteFlash.RevertBlackAndWhite.value));
                mPostProcessMaterial.SetVector(mSketchPointOffsetAndScaleID, mBlackWhiteFlash.SketchPointOffsetAndScale.value);
                mPostProcessMaterial.SetVector(mSketchXYSpeedAndTimeScaleID, mBlackWhiteFlash.SketchSpeedXYAndTimeScale.value);
                mPostProcessMaterial.SetColor (mDarkPartColorID, mBlackWhiteFlash.DarkPartColor.value);
                mPostProcessMaterial.SetColor (mBrightPartColorID, mBlackWhiteFlash.BrightPartColor.value);*/
            }

            private void SetupScatterBlur()
            {
                /*mPostProcessMaterial.SetVector(mScatterBlurOffsetScale, new Vector4(mScatterBlur.ScaterBlurCenterOffset.value.x, 
                                                                                         mScatterBlur.ScaterBlurCenterOffset.value.y, 
                                                                                       mScatterBlur.ScaterBlurStrengh.value, 
                                                                                       mScatterBlur.ScaterBlurScale.value));*/
            }

            private void ClearShaderKeywords()
            {
                /*mPostProcessMaterial.DisableKeyword(mScatterBlurKeyword);
                mPostProcessMaterial.DisableKeyword(mBlackWhiteFlashKeyword);*/
            }
        }

        PostProcessPass m_ScriptablePass;

        public override void Create()
        {
            // Configures where the render pass should be injected.
            m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        }
        
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            /*if (renderingData.cameraData.camera.gameObject.CompareTag("MainCamera") && PostProcessMaterial != null)
            {
                renderer.EnqueuePass(m_ScriptablePass);
            }*/
        }
    }
    
}



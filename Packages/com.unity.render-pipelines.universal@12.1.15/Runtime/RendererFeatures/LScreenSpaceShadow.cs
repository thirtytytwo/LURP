using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.Universal
{
    public class LScreenSpaceShadow : ScriptableRendererFeature
    {
        class ShadowCombinePass:ScriptableRenderPass
        {
            private ProfilingSampler mShadowCombineSampler = new ProfilingSampler("L Screen Shadow Pass");
            
            private Material mShadowCombineMaterial;

            //RenderTarget
            private RenderTargetHandle mTarget;

            public ShadowCombinePass(Material mat)
            {
                mShadowCombineMaterial = mat;
                mTarget.Init("_LScreenShadowTexture");
            }
            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var desc = renderingData.cameraData.cameraTargetDescriptor;
                desc.width >>= 1;
                desc.height >>= 1;
                desc.depthBufferBits = 0;
                desc.msaaSamples = 1;
                desc.graphicsFormat = RenderingUtils.SupportsGraphicsFormat(GraphicsFormat.R8_UNorm, FormatUsage.Linear | FormatUsage.Render)
                    ? GraphicsFormat.R8_UNorm
                    : GraphicsFormat.B8G8R8A8_UNorm;
                
                cmd.GetTemporaryRT(mTarget.id, desc, FilterMode.Bilinear);
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                ConfigureTarget(mTarget.Identifier());
                ConfigureClear(ClearFlag.Color, Color.black);
                ConfigureColorStoreAction(RenderBufferStoreAction.Store);
                ConfigureDepthStoreAction(RenderBufferStoreAction.DontCare);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                var cmd = CommandBufferPool.Get();
                var cameraData = renderingData.cameraData;
                using (new ProfilingScope(cmd, mShadowCombineSampler))
                {
                    cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, mShadowCombineMaterial);
                    cmd.SetViewProjectionMatrices(cameraData.camera.worldToCameraMatrix, cameraData.camera.projectionMatrix);
                    cmd.SetGlobalTexture(mTarget.id, mTarget.Identifier());
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(mTarget.id);
            }
        }
        
        private ShadowCombinePass mShadowCombinePass;
        [SerializeField] private Material m_ScreenSpaceShadowMaterial;
        public override void Create()
        {
            mShadowCombinePass = new ShadowCombinePass(m_ScreenSpaceShadowMaterial);
            mShadowCombinePass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses + 1;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(mShadowCombinePass);
        }

    }
    
}

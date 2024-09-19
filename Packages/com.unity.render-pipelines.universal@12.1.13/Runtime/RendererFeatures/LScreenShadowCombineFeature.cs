
using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.Universal
{
    public class LScreenShadowCombineFeature : ScriptableRendererFeature
    {
        class ShadowCombinePass:ScriptableRenderPass
        {
            private ProfilingSampler mShadowCombineSampler = new ProfilingSampler("Gbs Shadow Combine Pass");
            
            private Material mShadowCombineMaterial;
            //ShaderKeywords
            private const string mShadowCombineKeyword = "_ENABLE_SHADOWCOMBINE";

            //RenderTarget
            private RenderTargetHandle mTarget;

            public ShadowCombinePass()
            {
                mShadowCombineMaterial = new Material(Shader.Find("Hidden/Universal Render Pipeline/ShadowCombine"));
                mTarget.Init("_ShadowCombineTexture");
            }
            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                //RT 尺寸为 摄像机的 一半
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
                    cmd.EnableShaderKeyword(mShadowCombineKeyword);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(mTarget.id);
            }
        }

        class ShadowShadingPass : ScriptableRenderPass
        {
            private ProfilingSampler mShadowShadingSampler = new ProfilingSampler("Gbs Shadow Shading Pass");
            
            private static readonly int mShadowCombineTextureID = Shader.PropertyToID("_ShadowCombineTexture");
            
            private Material mShadowShadingMaterial;
            
            public ShadowShadingPass()
            {
                mShadowShadingMaterial = new Material(Shader.Find("Hidden/Universal Render Pipeline/ShadowShading"));
            }
            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                throw new System.NotImplementedException();
            }
        }
        
        private ShadowCombinePass mShadowCombinePass;
        private ShadowShadingPass mShadowShadingPass;
        public override void Create()
        {
            mShadowCombinePass = new ShadowCombinePass();
            mShadowCombinePass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;

        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(mShadowCombinePass);
        }

    }
    
}

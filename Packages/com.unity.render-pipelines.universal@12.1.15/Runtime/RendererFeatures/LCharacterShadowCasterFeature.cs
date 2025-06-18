using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class LCharacterShadowCasterFeature : ScriptableRendererFeature
{
    private LCharacterShadowCasterPass mCharacterShadowCasterPass;
    public override void Create()
    {
        mCharacterShadowCasterPass = new LCharacterShadowCasterPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(renderingData.cameraData.cameraType != CameraType.Game) return;
        renderer.EnqueuePass(mCharacterShadowCasterPass);
    }
    
    public class LCharacterShadowCasterPass : ScriptableRenderPass
    {
        private RenderTargetHandle mCharacterShadowmap;
        private int mWorldToShadowMatrix;
        private int mCharacterCount;
        private int mShadowParams;

        private ShaderTagId mShaderTagId = new ShaderTagId("LShadowCaster");
        private ProfilingSampler mProfilingSampler = new ProfilingSampler("LCharacterShadowCasterPass");
        
        private Matrix4x4[] mCharacterShadowMatrices;
        

        public LCharacterShadowCasterPass()
        {
            renderPassEvent = RenderPassEvent.BeforeRendering;

            mCharacterShadowMatrices = new Matrix4x4[4];
            mCharacterShadowmap.Init("_CharacterShadowmap");
            
            mCharacterCount = Shader.PropertyToID("_CharacterCount");
            mWorldToShadowMatrix = Shader.PropertyToID("_WorldToShadowMatrix");
            mShadowParams = Shader.PropertyToID("_ShadowParams");
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.width = 1024;
            descriptor.height = 1024;
            descriptor.colorFormat = RenderTextureFormat.Depth;
            
            cmd.GetTemporaryRT(mCharacterShadowmap.id, descriptor);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureTarget(mCharacterShadowmap.Identifier(), mCharacterShadowmap.Identifier());
            ConfigureClear(ClearFlag.Depth, Color.clear);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var data = CharacterShadowData.GetCharacterShadowData();
            if (data.Length == 0) return;
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, mProfilingSampler))
            {
                for (int i = 0; i < data.Length; i++)
                {
                    var filteringSetting = new FilteringSettings(RenderQueueRange.opaque, LayerMask.GetMask("Character"), data[i].characterID);
                    var drawingSettings = CreateDrawingSettings(mShaderTagId, ref renderingData, SortingCriteria.CommonOpaque);

                    float offsetX = (i % 2) * 512;
                    float offsetY = (i / 2) * 512;
                    
                    mCharacterShadowMatrices[i] = GetWorldToShadowMatrix(data[i].viewMatrix, data[i].projectionMatrix, new Vector2(offsetX, offsetY), 512, 1024);
                    
                    cmd.SetGlobalDepthBias(1.0f, 2.5f);
                    cmd.SetViewport(new Rect(offsetX, offsetY, 512, 512));
                    cmd.SetViewProjectionMatrices(data[i].viewMatrix, data[i].projectionMatrix);
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();
                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSetting);
                    cmd.SetGlobalDepthBias(0.0f, 0.0f);
                    
                }
            }
            
            
            cmd.SetGlobalTexture(mCharacterShadowmap.id, mCharacterShadowmap.Identifier());
            cmd.SetGlobalInt(mCharacterCount, data.Length);
            cmd.SetGlobalMatrixArray(mWorldToShadowMatrix, mCharacterShadowMatrices);
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
            
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(mCharacterShadowmap.id);
        }
        
        private Matrix4x4 GetWorldToShadowMatrix(Matrix4x4 view, Matrix4x4 proj, Vector2 offset, float resulution, float size)
        {
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
}

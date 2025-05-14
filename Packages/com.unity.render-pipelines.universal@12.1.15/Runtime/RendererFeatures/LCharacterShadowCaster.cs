using System;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering.Universal.Internal;

namespace UnityEngine.Rendering.Universal
{
    internal class LCharacterShadowCaster : ScriptableRendererFeature
    {
        public override void Create()
        {
            throw new NotImplementedException();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            throw new NotImplementedException();
        }
        
        //RenderPass
        class LCharacterShadowCasterPass : ScriptableRenderPass
        {
            private static readonly ShaderTagId mShaderTagId = new ShaderTagId("LCharacterShadowCaster");
            private static readonly ProfilingSampler mProfilingSampler = new ProfilingSampler("LCharacterShadowCaster");

            internal RenderTexture mShadowMap;

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                base.OnCameraSetup(cmd, ref renderingData);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                var cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, mProfilingSampler))
                {
                    
                }
            }

            private void RenderingCharacterShadow(ScriptableRenderContext context, ref RenderingData renderingData, int index)
            {
                var filteringSettings = new FilteringSettings(RenderQueueRange.opaque, LayerMask.GetMask("Character"), ShaderConstants.CharacterType[index]);
                var drawingSettings = CreateDrawingSettings(mShaderTagId, ref renderingData, SortingCriteria.CommonOpaque);
            }   
                
        }
        
        internal static class ShaderConstants
        {
            public static readonly uint[] CharacterType = new uint[4]{0x10000, 0x100000, 0x1000000, 0x10000000};
        }
    }
}

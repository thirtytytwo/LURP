
using UnityEngine.Experimental.Rendering;

// ReSharper disable once CheckNamespace
namespace UnityEngine.Rendering.Universal.Internal
{
    static class BloomFeature
    {
        internal static class ShaderConstants
        {
            public static readonly int[] _BloomPrefilterRTs  = new int[]
            {
                Shader.PropertyToID("_BloomPrefilterRT0"), Shader.PropertyToID("BloomPrefilterRT1")
            };
            public static readonly int[] _BloomDownSampleRTs = new int[]
            {
                Shader.PropertyToID("_BloomDownSampleRT0"), Shader.PropertyToID("_BloomDownSampleRT1"),
                Shader.PropertyToID("_BloomDownSampleRT2"), Shader.PropertyToID("_BloomDownSampleRT3")
            };
            public static readonly int[] _BloomAtlasRTs      = new int[]
            {
                Shader.PropertyToID("_BloomAtlasRT0"), Shader.PropertyToID("_BloomAtlasRT1")
            };
            public static readonly int _BloomCombineRT = Shader.PropertyToID("_BloomCombine");
            
            public static readonly int _BloomPrefilterParam = Shader.PropertyToID("_PreFilterParam");
            public static readonly int _BloomDownSampleBlurTime = Shader.PropertyToID("_LoopTime");
            public static readonly int _BloomScaleXYAndBlurKernals = Shader.PropertyToID("_ScaleXYAndBlurKernals");
            public static readonly int _BloomDownSampleBlurEdge = Shader.PropertyToID("_SampleEdge");
            public static readonly int _BloomDownSampleBlurScaleAndOffsetFrag = Shader.PropertyToID("_UVScaleAndOffsetFrag");
            public static readonly int _BloomCombineSOContainer = Shader.PropertyToID("_SampleScaleAndOffset");
            
            public static readonly int _Bloom_Params = Shader.PropertyToID("_Bloom_Params");
            public static readonly int _Bloom_Texture = Shader.PropertyToID("_Bloom_Texture");

            public static readonly int[] _BloomDownSampleWidth = new int[] { 342, 160, 72, 36 };
            public static readonly int[] _BloomDownSampleHeight = new int[] { 192, 90, 40, 20 };
            
            public static readonly int[] _BloomAtlasBlurLoop = new int[] { 2, 2, 3, 7 };

            public static readonly float[][] _BloomBlurKernals = new float[][]
            {
                new float[] { 0.31123f, 0.18877f },
                new float[] { 0.31123f, 0.18877f },
                new float[] { 0.23707f, 0.17215f, 0.09077f },
                new float[] { 0.1273f, 0.11532f, 0.09465f, 0.07038f, 0.04741f, 0.02893f, 0.016f }
            };

            public static readonly Vector4[] _BloomBlurContainer = new Vector4[16];
            public static readonly Vector4[] _BloomAtlasSOContainer = new Vector4[4];
        }
        
        internal static class ShaderKeywords
        {
            internal const string BloomDefaultKernal = "_DEFAULT_KERNAL";
            internal const string BloomActive = "_Bloom_Active";

        }

        private static readonly int atlasWidth = 503;
        private static readonly int atlasHeight = 192;

        internal static void ExecuteBloom(CommandBuffer cmd, RenderTargetIdentifier source, Material uberMat, Material bloomMat, Bloom bloomSetting, RenderTextureDescriptor descriptor, GraphicsFormat format)
        {
            using (new ProfilingScope(cmd, ProfilingSampler.Get(URPProfileId.Bloom)))
            {
                bool isDefaultKernal = bloomSetting.bloomDefaultKernal.value;
                CoreUtils.SetKeyword(bloomMat, ShaderKeywords.BloomDefaultKernal, isDefaultKernal);
                
                #region Init RT Pool

                int tw = descriptor.width;
                int th = descriptor.height;
                var desc = descriptor;
                desc.depthBufferBits = 0;
                desc.msaaSamples = 1;
                desc.width = tw;
                desc.height = th;
                desc.graphicsFormat = format;

                //prefilter
                for (int i = 0; i < 2; i++)
                {
                    tw >>= 1; 
                    th >>= 1;
                    desc.width = tw;
                    desc.height = th;
                    cmd.GetTemporaryRT(ShaderConstants._BloomPrefilterRTs[i], desc, FilterMode.Bilinear);
                }
                //downsample
                for (int i = 0; i < 4; i++)
                {
                    desc.width = ShaderConstants._BloomDownSampleWidth[i];
                    desc.height = ShaderConstants._BloomDownSampleHeight[i];
                    
                    cmd.GetTemporaryRT(ShaderConstants._BloomDownSampleRTs[i], desc, FilterMode.Bilinear);
                }
                
                //atlas blur
                for (int i = 0; i < 2; i++)
                {
                    desc.width = atlasWidth;
                    desc.height = atlasHeight;
                    
                    cmd.GetTemporaryRT(ShaderConstants._BloomAtlasRTs[i], desc, FilterMode.Bilinear);
                }
                //combine
                desc.width = ShaderConstants._BloomDownSampleWidth[0];
                desc.height = ShaderConstants._BloomDownSampleHeight[0];
                cmd.GetTemporaryRT(ShaderConstants._BloomCombineRT, desc, FilterMode.Bilinear);

                #endregion

                #region Prefilter

                float clamp = bloomSetting.clamp.value;
                float scatter = bloomSetting.scatter.value;
                float threshold = Mathf.GammaToLinearSpace(bloomSetting.threshold.value);
                float thresholdKnee = threshold * 0.5f;
                Vector4 pre_param = new Vector4(scatter, clamp, threshold, thresholdKnee);
                cmd.SetGlobalVector(ShaderConstants._BloomPrefilterParam, pre_param);
                cmd.SetGlobalTexture("_SourceTex", source);
                cmd.SetRenderTarget(ShaderConstants._BloomPrefilterRTs[0], RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, bloomMat, 0,0);

                cmd.SetGlobalTexture("_SourceTex", ShaderConstants._BloomPrefilterRTs[0]);
                cmd.SetRenderTarget(ShaderConstants._BloomPrefilterRTs[1], RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, bloomMat, 0,1);
                
                #endregion

                #region Atlas DownSample

                var rt = ShaderConstants._BloomPrefilterRTs[1];
                for (int i = 0; i < 4; i++)
                {
                    cmd.SetGlobalTexture("_SourceTex", rt);
                    cmd.SetRenderTarget(ShaderConstants._BloomDownSampleRTs[i], RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, bloomMat, 0, 1);
                    rt = ShaderConstants._BloomDownSampleRTs[i];
                }

                #endregion

                #region Atlas Combine And Blur

                float atlasPerPixelX, atlasPerPixelY;
                Vector2 offset = Vector2.zero, scale = Vector2.zero;
                
                //Horizontal
                cmd.SetRenderTarget(ShaderConstants._BloomAtlasRTs[0], RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.ClearRenderTarget(RTClearFlags.Color, Color.black, 0, 0);
                for (int i = 0; i < 4; i++)
                {
                    offset.x = (i == 0) ? 0 : (i % 2 == 0) ? offset.x : ShaderConstants._BloomDownSampleWidth[i - 1] + 1 + offset.x;
                    offset.y = (i == 0) ? 0 : (i % 2 != 0) ? offset.y : ShaderConstants._BloomDownSampleHeight[i - 1] + 1 + offset.y;
                    scale.x = ShaderConstants._BloomDownSampleWidth[i];
                    scale.y = ShaderConstants._BloomDownSampleHeight[i];
                    
                    cmd.SetGlobalTexture("_SourceTex", ShaderConstants._BloomDownSampleRTs[i]);
                    cmd.SetViewport(new Rect(offset, scale));
                    
                    //Blur
                    if (!isDefaultKernal) //默认核不需要计算这些
                    {
                        atlasPerPixelX = 1f / ShaderConstants._BloomDownSampleWidth[i];
                        atlasPerPixelY = 1f / ShaderConstants._BloomDownSampleHeight[i];
                        cmd.SetGlobalInt(ShaderConstants._BloomDownSampleBlurTime, ShaderConstants._BloomAtlasBlurLoop[i] * 2);
                        float footPrint = 0f;
                        for (int j = 0; j < ShaderConstants._BloomAtlasBlurLoop[i]; j++)
                        {
                            footPrint = 0.5f + (1.0f * j);
                            //positive
                            ShaderConstants._BloomBlurContainer[j * 2] = new Vector4(footPrint * atlasPerPixelX, footPrint * atlasPerPixelY, ShaderConstants._BloomBlurKernals[i][j],0);
                            //negative
                            ShaderConstants._BloomBlurContainer[j * 2 + 1] = new Vector4(-1 * footPrint * atlasPerPixelX, -1 * footPrint * atlasPerPixelY, ShaderConstants._BloomBlurKernals[i][j],0);
                        }
                        cmd.SetGlobalVectorArray(ShaderConstants._BloomScaleXYAndBlurKernals, ShaderConstants._BloomBlurContainer);
                    }
                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, bloomMat, 0, 2);
                }
                //Vertical
                cmd.SetRenderTarget(ShaderConstants._BloomAtlasRTs[1], RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.ClearRenderTarget(RTClearFlags.Color, Color.black, 0, 0);
                cmd.SetGlobalTexture("_SourceTex", ShaderConstants._BloomAtlasRTs[0]);

                atlasPerPixelX = 1f / atlasWidth;
                atlasPerPixelY = 1f / atlasHeight;
                for (int i = 0; i < 4; i++)
                {
                    offset.x = (i == 0) ? 0 : (i % 2 == 0) ? offset.x : ShaderConstants._BloomDownSampleWidth[i - 1] + 1 + offset.x;
                    offset.y = (i == 0) ? 0 : (i % 2 != 0) ? offset.y : ShaderConstants._BloomDownSampleHeight[i - 1] + 1 + offset.y;
                    scale.x = ShaderConstants._BloomDownSampleWidth[i];
                    scale.y = ShaderConstants._BloomDownSampleHeight[i];
                    
                    cmd.SetViewport(new Rect(offset, scale));
                    
                    //ScaleAndOffsetFrag
                    cmd.SetGlobalVector(ShaderConstants._BloomDownSampleBlurScaleAndOffsetFrag, new Vector4(scale.x / atlasWidth, scale.y / atlasHeight, offset.x / atlasWidth, offset.y / atlasHeight));
                    
                    //SampleEdge
                    Vector2 maxV = new Vector2((ShaderConstants._BloomDownSampleWidth[i] + offset.x - 0.5f) * atlasPerPixelX, (ShaderConstants._BloomDownSampleHeight[i] + offset.y - 0.5f) * atlasPerPixelY);
                    Vector2 minV = new Vector2((0.5f + offset.x) * atlasPerPixelX, (0.5f + offset.y) * atlasPerPixelY);
                    cmd.SetGlobalVector(ShaderConstants._BloomDownSampleBlurEdge, new Vector4(minV.x, minV.y, maxV.x, maxV.y));

                    if (!isDefaultKernal)
                    {
                        //Blur
                        cmd.SetGlobalInt(ShaderConstants._BloomDownSampleBlurTime, ShaderConstants._BloomAtlasBlurLoop[i] * 2);
                        float footPrint = 0f;
                        for (int j = 0; j < ShaderConstants._BloomAtlasBlurLoop[i]; j++)
                        {
                            footPrint = 0.5f + (1.0f * j);
                            //positive
                            ShaderConstants._BloomBlurContainer[j * 2] = new Vector4(footPrint * atlasPerPixelX, footPrint * atlasPerPixelY, ShaderConstants._BloomBlurKernals[i][j],0);
                            //negative
                            ShaderConstants._BloomBlurContainer[j * 2 + 1] = new Vector4(-1 * footPrint * atlasPerPixelX, -1 * footPrint * atlasPerPixelY, ShaderConstants._BloomBlurKernals[i][j],0);
                        }
                        cmd.SetGlobalVectorArray(ShaderConstants._BloomScaleXYAndBlurKernals, ShaderConstants._BloomBlurContainer);
                    }

                    cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, bloomMat, 0, 3);
                }
                #endregion

                #region Final Combine

                cmd.SetRenderTarget(ShaderConstants._BloomCombineRT, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.SetGlobalTexture("_SourceTex", ShaderConstants._BloomAtlasRTs[1]);
                for (int i = 0; i < 4; i++)
                {
                    offset.x = (i == 0) ? 0 : (i % 2 == 0) ? offset.x : ShaderConstants._BloomDownSampleWidth[i - 1] + 1 + offset.x;
                    offset.y = (i == 0) ? 0 : (i % 2 != 0) ? offset.y : ShaderConstants._BloomDownSampleHeight[i - 1] + 1 + offset.y;
                    scale.x = ShaderConstants._BloomDownSampleWidth[i];
                    scale.y = ShaderConstants._BloomDownSampleHeight[i];
                    ShaderConstants._BloomAtlasSOContainer[i] = new Vector4(scale.x / atlasWidth, scale.y / atlasHeight, offset.x / atlasWidth, offset.y / atlasHeight);
                }
                cmd.SetGlobalVectorArray(ShaderConstants._BloomCombineSOContainer, ShaderConstants._BloomAtlasSOContainer);
                cmd.DrawMesh(RenderingUtils.fastfullscreenMesh, Matrix4x4.identity, bloomMat, 0, 4);

                #endregion

                #region Connect to Uber
                
                cmd.SetGlobalTexture(ShaderConstants._Bloom_Texture, ShaderConstants._BloomCombineRT);
                cmd.SetGlobalVector(ShaderConstants._Bloom_Params, new Vector4(bloomSetting.intensity.value,0,0,0));
                uberMat.EnableKeyword(ShaderKeywords.BloomActive);

                #endregion

                #region Clean up

                for (int i = 0; i < 2; i++)
                {
                    cmd.ReleaseTemporaryRT(ShaderConstants._BloomPrefilterRTs[i]);
                }

                for (int i = 0; i < 4; i++)
                {
                    cmd.ReleaseTemporaryRT(ShaderConstants._BloomDownSampleRTs[i]);
                }

                for (int i = 0; i < 2; i++)
                {
                    cmd.ReleaseTemporaryRT(ShaderConstants._BloomAtlasRTs[i]);
                }

                #endregion
                
            }
        }
    }
}

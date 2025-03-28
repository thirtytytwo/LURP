#ifndef L_ANTIALIASING_INCLUDE
#define L_ANTIALIASING_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

/*-------------------------------------------------------------------------------------------*/
#if SHADER_API_DESKTOP
/*-------------------------------------------------------------------------------------------*/
#ifdef QUALITY_LOW
#define FXAA_SEARCH_STEPS 3
#define FXAA_SEARCH_S0 1.0
#define FXAA_SEARCH_S1 2.0
#define FXAA_SEARCH_S2 8.0
#endif
/*-------------------------------------------------------------------------------------------*/
#ifdef QUALITY_MEDIUM
#define FXAA_SEARCH_STEPS 6
#define FXAA_SEARCH_S0 1.0
#define FXAA_SEARCH_S1 1.0
#define FXAA_SEARCH_S2 2.0
#define FXAA_SEARCH_S3 2.0
#define FXAA_SEARCH_S4 2.0
#define FXAA_SEARCH_S5 8.0
#endif
/*-------------------------------------------------------------------------------------------*/
#ifdef QUALITY_HIGH
#define FXAA_SEARCH_STEPS 12
#define FXAA_SEARCH_S0 1.0
#define FXAA_SEARCH_S1 1.0
#define FXAA_SEARCH_S2 1.0
#define FXAA_SEARCH_S3 1.0
#define FXAA_SEARCH_S4 1.0
#define FXAA_SEARCH_S5 1.0
#define FXAA_SEARCH_S6 2.0
#define FXAA_SEARCH_S7 2.0
#define FXAA_SEARCH_S8 2.0
#define FXAA_SEARCH_S9 2.0
#define FXAA_SEARCH_S10 4.0
#define FXAA_SEARCH_S11 8.0
#endif
/*-------------------------------------------------------------------------------------------*/
#endif

/*-------------------------------------------------------------------------------------------*/
#if SHADER_API_MOBILE
/*-------------------------------------------------------------------------------------------*/
#ifdef QUALITY_LOW
#define FXAA_USE_CONSOLE 1
#endif
/*-------------------------------------------------------------------------------------------*/
#ifdef QUALITY_MEDIUM
#define FXAA_SEARCH_STEPS 3
#define FXAA_SEARCH_S0 1.0
#define FXAA_SEARCH_S1 2.0
#define FXAA_SEARCH_S2 8.0
#endif
/*-------------------------------------------------------------------------------------------*/
#ifdef QUALITY_HIGH
#define FXAA_SEARCH_STEPS 6
#define FXAA_SEARCH_S0 1.0
#define FXAA_SEARCH_S1 1.0
#define FXAA_SEARCH_S2 2.0
#define FXAA_SEARCH_S3 2.0
#define FXAA_SEARCH_S4 2.0
#define FXAA_SEARCH_S5 8.0
#endif
/*-------------------------------------------------------------------------------------------*/
#endif
/*-------------------------------------------------------------------------------------------*/
float GetLuminance(TEXTURE2D(inputTexture), float2 pos)
{
    #if COMPUTE_FAST
    return SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, pos).g;
    #else
    return Luminance(SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, pos));
    #endif
}
half3 FXAADesktopPixelShader(TEXTURE2D(inputTexture), float2 pos, float4 texSize, float4 params)
{
    #ifdef FXAA_USE_CONSOLE
    half3 col = SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, pos).rgb;
    float2 positionSS = pos * texSize.xy;
    float2 positionNDC = pos;
    half3 result = ApplyFXAA(col, positionNDC, positionSS, texSize, inputTexture);
    return result;
    #endif
    
    float2 posM;
    posM.x = pos.x;
    posM.y = pos.y;
    int2 posSS;
    posSS.x = pos.x * texSize.x;
    posSS.y = pos.y * texSize.y;

#if COMPUTE_FAST
    float4 luma4A = GATHER_GREEN_TEXTURE2D(inputTexture, sampler_PointClamp, posM);
    float4 luma4B = GATHER_GREEN_TEXTURE2D(inputTexture, sampler_PointClamp, posM - float2(texSize.z, texSize.w));

    float lumaM = luma4A.w;
    float lumaE = luma4A.z;
    float lumaN = luma4A.x;
    float lumaNE = luma4A.y;
    float lumaS = luma4B.z;
    float lumaW = luma4B.x;
    float lumaSW = luma4B.w;
#else
    float lumaM = Luminance(saturate(FXAALoad(posSS, 0, 0, texSize, inputTexture)));
    float lumaE = Luminance(saturate(FXAALoad(posSS, 1, 0, texSize, inputTexture)));
    float lumaN = Luminance(saturate(FXAALoad(posSS, 0, 1, texSize, inputTexture)));
    float lumaW = Luminance(saturate(FXAALoad(posSS, -1, 0, texSize, inputTexture)));
    float lumaS = Luminance(saturate(FXAALoad(posSS, 0, -1, texSize, inputTexture)));
#endif
    float lumaMaxSM = max(lumaS, lumaM);
    float lumaMinSM = min(lumaS, lumaM);
    float lumaMaxESM = max(lumaE, lumaMaxSM);
    float lumaMinESM = min(lumaE, lumaMinSM);
    float lumaMaxWN = max(lumaW, lumaN);
    float lumaMinWN = min(lumaW, lumaN);
    float rangeMax = max(lumaMaxESM, lumaMaxWN);
    float rangeMin = min(lumaMinESM, lumaMinWN);
    float range = rangeMax - rangeMin;
    float rangeMaxScaled = rangeMax * params.x;
    float rangeThreshold = max(params.y, rangeMaxScaled);
    bool needContinue = range > rangeThreshold;
    if (!needContinue)
    {
        return SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posM).xyz;
    }

#if COMPUTE_FAST
    float lumaNW = FXAALoad(posSS, -1, 1, texSize, inputTexture).g;
    float lumaSE = FXAALoad(posSS, 1, -1, texSize, inputTexture).g;
#else
    float lumaNE = Luminance(saturate(FXAALoad(posSS, 1, 1, texSize, inputTexture)));
    float lumaNW = Luminance(saturate(FXAALoad(posSS, -1, 1, texSize, inputTexture)));
    float lumaSE = Luminance(saturate(FXAALoad(posSS, 1, -1, texSize, inputTexture)));
    float lumaSW = Luminance(saturate(FXAALoad(posSS, -1, -1, texSize, inputTexture)));
#endif
    float lumaNS = lumaN + lumaS;
    float lumaWE = lumaW + lumaE;
    float subpixRangeRcp = 1.0 / range;
    float subpixNSWE = lumaNS + lumaWE;
    float edgeH1 = (-2.0 * lumaM) + lumaNS;
    float edgeV1 = (-2.0 * lumaM) + lumaWE;

    float lumaNESE = lumaNE + lumaSE;
    float lumaNWNE = lumaNW + lumaNE;
    float edgeH2 = (-2.0 * lumaE) + lumaNESE;
    float edgeV2 = (-2.0 * lumaN) + lumaNWNE;

    float lumaNWSW = lumaNW + lumaSW;
    float lumaSWSE = lumaSW + lumaSE;
    float edgeH3 = (-2.0 * lumaW) + lumaNWSW;
    float edgeV3 = (-2.0 * lumaS) + lumaSWSE;
    float edgeH4 = (abs(edgeH1) * 2.0) + abs(edgeH2);
    float edgeV4 = (abs(edgeV1) * 2.0) + abs(edgeV2);
    float edgeH = abs(edgeH3) + edgeH4;
    float edgeV = abs(edgeV3) + edgeV4;

    float subpixNESENWSW = lumaNESE + lumaNWSW;
    bool sampleVDir = (edgeH >= edgeV);
    float subpixA = subpixNSWE * 2.0 + subpixNESENWSW;
    
    float verticalStep = texSize.w;
    if (!sampleVDir) lumaN = lumaE;
    if (!sampleVDir) lumaS = lumaW;
    if (!sampleVDir) verticalStep = texSize.z;
    float subpixB = (subpixA * (1.0 / 12.0)) - lumaM;

    float positive = abs(lumaN - lumaM);
    float negative = abs(lumaS - lumaM);
    float subpixC = saturate(abs(subpixB) * subpixRangeRcp);
    bool samplePDir = positive >= negative;
    if (!samplePDir) verticalStep = -verticalStep;
    float gradient = samplePDir? positive : negative;
    float subpixD = ((-2.0) * subpixC) + 3.0;
    float oppsiteLum = samplePDir? lumaN : lumaS;

    float2 uvEdge = posM;
    if (!sampleVDir) uvEdge.x += verticalStep * 0.5f;
    if (sampleVDir)  uvEdge.y += verticalStep * 0.5f;
    float2 edgeStep = sampleVDir ? float2(texSize.z, 0) : float2(0, texSize.w);
    float subpixE = subpixC * subpixC;

    float2 posP;
    posP = uvEdge;
    float2 posN;
    posN = uvEdge;

    float edgeLuma = (lumaM + oppsiteLum) * 0.5f;
    float gradientThreshold = gradient * 0.25f;
    float subpixF = subpixD * subpixE;

    float pLumDelta, nLumDelta, pDistance, nDistance;
    
    posP += edgeStep * FXAA_SEARCH_S0;
    posN -= edgeStep * FXAA_SEARCH_S0;
    pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
    bool doneP = abs(pLumDelta) > gradientThreshold;
    nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
    bool doneN = abs(nLumDelta) > gradientThreshold;
    bool doneNP = doneP && doneN;
    if (!doneNP)
    {
        if (!doneP)posP += edgeStep * FXAA_SEARCH_S1;
        if (!doneN)posN -= edgeStep * FXAA_SEARCH_S1;
        if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
        doneP = abs(pLumDelta) > gradientThreshold;
        if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
        doneN = abs(nLumDelta) > gradientThreshold;
        doneNP = doneP && doneN;
        if (!doneNP)
        {
            if (!doneP)posP += edgeStep * FXAA_SEARCH_S2;
            if (!doneN)posN -= edgeStep * FXAA_SEARCH_S2;
            if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
            doneP = abs(pLumDelta) > gradientThreshold;
            if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
            doneN = abs(nLumDelta) > gradientThreshold;
            doneNP = doneP && doneN;
#if (FXAA_SEARCH_STEPS > 3)
            if (!doneNP)
            {
                if (!doneP)posP += edgeStep * FXAA_SEARCH_S3;
                if (!doneN)posN -= edgeStep * FXAA_SEARCH_S3;
                if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                doneP = abs(pLumDelta) > gradientThreshold;
                if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                doneN = abs(nLumDelta) > gradientThreshold;
                doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 4)
                if (!doneNP)
                {
                    if (!doneP)posP += edgeStep * FXAA_SEARCH_S4;
                    if (!doneN)posN -= edgeStep * FXAA_SEARCH_S4;
                    if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                    doneP = abs(pLumDelta) > gradientThreshold;
                    if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                    doneN = abs(nLumDelta) > gradientThreshold;
                    doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 5)
                    if (!doneNP)
                    {
                        if (!doneP)posP += edgeStep * FXAA_SEARCH_S5;
                        if (!doneN)posN -= edgeStep * FXAA_SEARCH_S5;
                        if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                        doneP = abs(pLumDelta) > gradientThreshold;
                        if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                        doneN = abs(nLumDelta) > gradientThreshold;
                        doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 6)
                        if (!doneNP)
                        {
                            if (!doneP)posP += edgeStep * FXAA_SEARCH_S6;
                            if (!doneN)posN -= edgeStep * FXAA_SEARCH_S6;
                            if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                            doneP = abs(pLumDelta) > gradientThreshold;
                            if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                            doneN = abs(nLumDelta) > gradientThreshold;
                            doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 7)
                            if (!doneNP)
                            {
                                if (!doneP)posP += edgeStep * FXAA_SEARCH_S7;
                                if (!doneN)posN -= edgeStep * FXAA_SEARCH_S7;
                                if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                                doneP = abs(pLumDelta) > gradientThreshold;
                                if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                                doneN = abs(nLumDelta) > gradientThreshold;
                                doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 8)
                                if (!doneNP)
                                {
                                    if (!doneP)posP += edgeStep * FXAA_SEARCH_S8;
                                    if (!doneN)posN -= edgeStep * FXAA_SEARCH_S8;
                                    if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                                    doneP = abs(pLumDelta) > gradientThreshold;
                                    if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                                    doneN = abs(nLumDelta) > gradientThreshold;
                                    doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 9)
                                    if (!doneNP)
                                    {
                                        if (!doneP)posP += edgeStep * FXAA_SEARCH_S9;
                                        if (!doneN)posN -= edgeStep * FXAA_SEARCH_S9;
                                        if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                                        doneP = abs(pLumDelta) > gradientThreshold;
                                        if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                                        doneN = abs(nLumDelta) > gradientThreshold;
                                        doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 10)
                                        if (!doneNP)
                                        {
                                            if (!doneP)posP += edgeStep * FXAA_SEARCH_S10;
                                            if (!doneN)posN -= edgeStep * FXAA_SEARCH_S10;
                                            if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                                            doneP = abs(pLumDelta) > gradientThreshold;
                                            if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                                            doneN = abs(nLumDelta) > gradientThreshold;
                                            doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 11)
                                            if (!doneNP)
                                            {
                                                if (!doneP)posP += edgeStep * FXAA_SEARCH_S11;
                                                if (!doneN)posN -= edgeStep * FXAA_SEARCH_S11;
                                                if (!doneP)pLumDelta = GetLuminance(inputTexture, posP) - edgeLuma;
                                                doneP = abs(pLumDelta) > gradientThreshold;
                                                if (!doneN)nLumDelta = GetLuminance(inputTexture, posN) - edgeLuma;
                                                doneN = abs(nLumDelta) > gradientThreshold;
                                                doneNP = doneP && doneN;
                                            }
#endif
                                        }
#endif
                                    }
#endif
                                }
#endif
                            }
#endif
                        }
#endif
                    }
#endif
                }
#endif
            }
#endif
        }
    }


    
    pDistance = posP.x - posM.x;
    nDistance = posM.x - posN.x;
    if (!sampleVDir) pDistance = posP.y - posM.y;
    if (!sampleVDir) nDistance = posM.y - posN.y;
    
    float subpixG = subpixF * subpixF;
    bool dstIsP = pDistance < nDistance;
    float dst = min(pDistance, nDistance);
    bool needToStepBlur = sign(pLumDelta) != sign(lumaM - edgeLuma);
    if (!dstIsP) needToStepBlur = sign(nLumDelta)!= sign(lumaM - edgeLuma);
    float edgeBlend = 0.0;
    if (needToStepBlur) edgeBlend = 0.5f - dst / (pDistance + nDistance);

    float finalBlend = max(subpixG,edgeBlend);

    float2 posF;
    posF.x = posM.x;
    posF.y = posM.y;
    if (sampleVDir) posF.y += finalBlend * verticalStep;
    if (!sampleVDir) posF.x += finalBlend * verticalStep;
    
    
    half3 result = SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posF).rgb;
                
    return result;

}
#endif
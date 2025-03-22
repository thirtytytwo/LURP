#ifndef L_ANTIALIASING_INCLUDE
#define L_ANTIALIASING_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

//0:LOW 1:MEDIUM 2:HIGH DEFAULT:LOW

#ifdef SHADER_API_DESKTOP
#if defined(QUALITY_LOW)
#define FXAA_USE_GREEN_TO_LUMA 1
#define FXAA_LOOP 3
#endif

#if defined(QUALITY_MEDIUM)
#define FXAA_USE_GREEN_TO_LUMA 1
#define FXAA_LOOP 6
#endif


#if defined(QUALITY_HIGH)
#define FXAA_USE_GREEN_TO_LUMA 0
#define FXAA_LOOP 12
#endif
#endif

#ifdef SHADER_API_MOBILE
#if defined(QUALITY_LOW)
#define FXAA_USE_GREEN_TO_LUMA 1
#define FXAA_LOOP 0
#define FXAA_USE_CONSOLE 1
#endif

#if defined(QUALITY_MEDIUM)
#define FXAA_USE_GREEN_TO_LUMA 1
#define FXAA_LOOP 3
#define FXAA_USE_CONSOLE 0
#endif


#if defined(QUALITY_HIGH)
#define FXAA_USE_GREEN_TO_LUMA 1
#define FXAA_LOOP 6
#define FXAA_USE_CONSOLE 0
#endif
#endif

half3 FXAADesktopPixelShader(TEXTURE2D(inputTexture), float2 pos, float4 texSize, float4 params)
{
    float2 posM;
    posM.x = pos.x;
    posM.y = pos.y;
    int2 posSS;
    posSS.x = pos.x * texSize.x;
    posSS.y = pos.y * texSize.y;

#if FXAA_USE_GREEN_TO_LUMA
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

#if FXAA_USE_GREEN_TO_LUMA
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
    if (!sampleVDir) verticalStep = texSize.z;
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

    float edgeLum = (lumaM + oppsiteLum) * 0.5f;
    float gradientThreshold = gradient * 0.25f;
    float subpixF = subpixD * subpixE;

    float pLumDelta, nLumDelta, pDistance, nDistance;

    posP += edgeStep;
    posN -= edgeStep;
    pLumDelta = Luminance(SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posP)) - edgeLum;
    bool doneP = abs(pLumDelta) > gradientThreshold;
    nLumDelta = Luminance(SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posN)) - edgeLum;
    bool doneN = abs(nLumDelta) > gradientThreshold;
    bool doneNP = doneP && doneN;
#if FXAA_USE_GREEN_TO_LUMA
    UNITY_UNROLL
    for (int i = 1; i < FXAA_LOOP; i++)
    {
        if (!doneNP)
        {
            if (!doneP) posP += edgeStep;
            if (!doneN) posN -= edgeStep;
            pLumDelta = SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posP).g - edgeLum;
            doneP = abs(pLumDelta) > gradientThreshold;
            nLumDelta = SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posN).g - edgeLum;
            doneN = abs(nLumDelta) > gradientThreshold;
            doneNP = doneP && doneN;
        }
    }
#else
    UNITY_UNROLL
    for (int i = 1; i < FXAA_LOOP; i++)
    {
        if (!doneNP)
        {
            if (!doneP) posP += edgeStep;
            if (!doneN) posN -= edgeStep;
            pLumDelta = Luminance(SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posP)) - edgeLum;
            doneP = abs(pLumDelta) > gradientThreshold;
            nLumDelta = Luminance(SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, posN)) - edgeLum;
            doneN = abs(nLumDelta) > gradientThreshold;
            doneNP = doneP && doneN;
        }
    }
#endif
    
    pDistance = posP.x - posM.x;
    nDistance = posM.x - posN.x;
    if (!sampleVDir) pDistance = posP.y - posM.y;
    if (!sampleVDir) nDistance = posM.y - posN.y;
    
    float subpixG = subpixF * subpixF;
    bool dstIsP = pDistance < nDistance;
    float dst = min(pDistance, nDistance);
    bool needToStepBlur = sign(pLumDelta) != sign(lumaM - edgeLum);
    if (!dstIsP) needToStepBlur = sign(nLumDelta)!= sign(lumaM - edgeLum);
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

half3 FXAAMobilePixelShader(TEXTURE2D(inputTexture), float2 pos, float4 texSize, float4 params)
{
    #ifdef FXAA_USE_CONSOLE
    half3 col = SAMPLE_TEXTURE2D(inputTexture, sampler_LinearClamp, pos).rgb;
    float2 positionSS = pos * texSize.xy;
    float2 positionNDC = pos;
    half3 result = ApplyFXAA(col, positionNDC, positionSS, texSize, inputTexture);
    return result;
    #endif
    return FXAADesktopPixelShader(inputTexture, pos, texSize, params);
}
#endif
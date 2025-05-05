#ifndef L_ANTIALIASING_INCLUDE
#define L_ANTIALIASING_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

/*-------------------------------------------------------------------------------------------*/
#if SHADER_API_DESKTOP
/*-------------------------------------------------------------------------------------------*/
#define FXAA_SEARCH_STEPS 0
#define FXAA_SEARCH_S0 0
#define FXAA_SEARCH_S1 0
#define FXAA_SEARCH_S2 0
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
#if defined(UNITY_REVERSED_Z)
    #define COMPARE_DEPTH(a, b) step(b, a)
#else
    #define COMPARE_DEPTH(a, b) step(a, b)
#endif

TEXTURE2D(_CameraDepthTexture);
TEXTURE2D(_CameraColorTexture);
float4 _CameraColorSize;
float4 _CameraDepthSize;

//
float4 _FXAAParams;

//
TEXTURE2D(_LMotionVectorTexture);
TEXTURE2D(_LCurrentObjectIDTexture);
TEXTURE2D(_LLastObjectIDTexture);
TEXTURE2D(_LLastFrame);
float4 _Jitter;
float4 _TAAParams;

float GetLuminance(float2 pos)
{
    #if COMPUTE_FAST
    return SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, pos).g;
    #else
    return Luminance(SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, pos));
    #endif
}
float2 MotionVectorEncode(float2 motion)
{
    float2 motionSign = sign(motion);
    //类似Gamma矫正，让小数据占有更多的范围
    //因为速度很少有从屏幕的一边移动屏幕一半的距离，所以大部分速度都集中来0-0.5这个范围，所以让0-0.5的范围占更多的范围
    //可以减少对贴图格式的依赖
    float2 data = sqrt(abs(motion));
    return motionSign * data;
}
float2 MotionVectorDecode(float2 motion)
{
    motion -= 0.5f;
    float2 motionSign = sign(motion);
    float2 data = motion + motion;
    data *= data;
    return motionSign * data;
}
half3 FXAAPixelShader(float2 pos)
{
    #ifdef FXAA_USE_CONSOLE
    half3 col = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, pos).rgb;
    float2 positionSS = pos * _CameraColorSize.xy;
    float2 positionNDC = pos;
    half3 result = ApplyFXAA(col, positionNDC, positionSS, _CameraColorSize, _CameraColorTexture);
    return result;
    #endif
    
    float2 posM;
    posM.x = pos.x;
    posM.y = pos.y;
    int2 posSS;
    posSS.x = pos.x * _CameraColorSize.x;
    posSS.y = pos.y * _CameraColorSize.y;

#if COMPUTE_FAST
    float4 luma4A = GATHER_GREEN_TEXTURE2D(_CameraColorTexture, sampler_PointClamp, posM);
    float4 luma4B = GATHER_GREEN_TEXTURE2D(_CameraColorTexture, sampler_PointClamp, posM - float2(texSize.z, texSize.w));

    float lumaM = luma4A.w;
    float lumaE = luma4A.z;
    float lumaN = luma4A.x;
    float lumaNE = luma4A.y;
    float lumaS = luma4B.z;
    float lumaW = luma4B.x;
    float lumaSW = luma4B.w;
#else
    float lumaM = Luminance(saturate(FXAALoad(posSS, 0, 0, _CameraColorSize, _CameraColorTexture)));
    float lumaE = Luminance(saturate(FXAALoad(posSS, 1, 0, _CameraColorSize, _CameraColorTexture)));
    float lumaN = Luminance(saturate(FXAALoad(posSS, 0, 1, _CameraColorSize, _CameraColorTexture)));
    float lumaW = Luminance(saturate(FXAALoad(posSS, -1, 0, _CameraColorSize, _CameraColorTexture)));
    float lumaS = Luminance(saturate(FXAALoad(posSS, 0, -1, _CameraColorSize, _CameraColorTexture)));
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
    float rangeMaxScaled = rangeMax * _FXAAParams.x;
    float rangeThreshold = max(_FXAAParams.y, rangeMaxScaled);
    bool needContinue = range > rangeThreshold;
    if (!needContinue)
    {
        return SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, posM).xyz;
    }

#if COMPUTE_FAST
    float lumaNW = FXAALoad(posSS, -1, 1, texSize, _CameraColorTexture).g;
    float lumaSE = FXAALoad(posSS, 1, -1, texSize, _CameraColorTexture).g;
#else
    float lumaNE = Luminance(saturate(FXAALoad(posSS, 1, 1, _CameraColorSize, _CameraColorTexture)));
    float lumaNW = Luminance(saturate(FXAALoad(posSS, -1, 1, _CameraColorSize, _CameraColorTexture)));
    float lumaSE = Luminance(saturate(FXAALoad(posSS, 1, -1, _CameraColorSize, _CameraColorTexture)));
    float lumaSW = Luminance(saturate(FXAALoad(posSS, -1, -1, _CameraColorSize, _CameraColorTexture)));
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
    
    float verticalStep = _CameraColorSize.w;
    if (!sampleVDir) lumaN = lumaE;
    if (!sampleVDir) lumaS = lumaW;
    if (!sampleVDir) verticalStep = _CameraColorSize.z;
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
    float2 edgeStep = sampleVDir ? float2(_CameraColorSize.z, 0) : float2(0, _CameraColorSize.w);
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
    pLumDelta = GetLuminance(posP) - edgeLuma;
    bool doneP = abs(pLumDelta) > gradientThreshold;
    nLumDelta = GetLuminance(posN) - edgeLuma;
    bool doneN = abs(nLumDelta) > gradientThreshold;
    bool doneNP = doneP && doneN;
    if (!doneNP)
    {
        if (!doneP)posP += edgeStep * FXAA_SEARCH_S1;
        if (!doneN)posN -= edgeStep * FXAA_SEARCH_S1;
        if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
        doneP = abs(pLumDelta) > gradientThreshold;
        if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
        doneN = abs(nLumDelta) > gradientThreshold;
        doneNP = doneP && doneN;
        if (!doneNP)
        {
            if (!doneP)posP += edgeStep * FXAA_SEARCH_S2;
            if (!doneN)posN -= edgeStep * FXAA_SEARCH_S2;
            if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
            doneP = abs(pLumDelta) > gradientThreshold;
            if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
            doneN = abs(nLumDelta) > gradientThreshold;
            doneNP = doneP && doneN;
#if (FXAA_SEARCH_STEPS > 3)
            if (!doneNP)
            {
                if (!doneP)posP += edgeStep * FXAA_SEARCH_S3;
                if (!doneN)posN -= edgeStep * FXAA_SEARCH_S3;
                if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                doneP = abs(pLumDelta) > gradientThreshold;
                if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                doneN = abs(nLumDelta) > gradientThreshold;
                doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 4)
                if (!doneNP)
                {
                    if (!doneP)posP += edgeStep * FXAA_SEARCH_S4;
                    if (!doneN)posN -= edgeStep * FXAA_SEARCH_S4;
                    if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                    doneP = abs(pLumDelta) > gradientThreshold;
                    if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                    doneN = abs(nLumDelta) > gradientThreshold;
                    doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 5)
                    if (!doneNP)
                    {
                        if (!doneP)posP += edgeStep * FXAA_SEARCH_S5;
                        if (!doneN)posN -= edgeStep * FXAA_SEARCH_S5;
                        if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                        doneP = abs(pLumDelta) > gradientThreshold;
                        if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                        doneN = abs(nLumDelta) > gradientThreshold;
                        doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 6)
                        if (!doneNP)
                        {
                            if (!doneP)posP += edgeStep * FXAA_SEARCH_S6;
                            if (!doneN)posN -= edgeStep * FXAA_SEARCH_S6;
                            if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                            doneP = abs(pLumDelta) > gradientThreshold;
                            if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                            doneN = abs(nLumDelta) > gradientThreshold;
                            doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 7)
                            if (!doneNP)
                            {
                                if (!doneP)posP += edgeStep * FXAA_SEARCH_S7;
                                if (!doneN)posN -= edgeStep * FXAA_SEARCH_S7;
                                if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                                doneP = abs(pLumDelta) > gradientThreshold;
                                if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                                doneN = abs(nLumDelta) > gradientThreshold;
                                doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 8)
                                if (!doneNP)
                                {
                                    if (!doneP)posP += edgeStep * FXAA_SEARCH_S8;
                                    if (!doneN)posN -= edgeStep * FXAA_SEARCH_S8;
                                    if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                                    doneP = abs(pLumDelta) > gradientThreshold;
                                    if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                                    doneN = abs(nLumDelta) > gradientThreshold;
                                    doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 9)
                                    if (!doneNP)
                                    {
                                        if (!doneP)posP += edgeStep * FXAA_SEARCH_S9;
                                        if (!doneN)posN -= edgeStep * FXAA_SEARCH_S9;
                                        if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                                        doneP = abs(pLumDelta) > gradientThreshold;
                                        if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                                        doneN = abs(nLumDelta) > gradientThreshold;
                                        doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 10)
                                        if (!doneNP)
                                        {
                                            if (!doneP)posP += edgeStep * FXAA_SEARCH_S10;
                                            if (!doneN)posN -= edgeStep * FXAA_SEARCH_S10;
                                            if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                                            doneP = abs(pLumDelta) > gradientThreshold;
                                            if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
                                            doneN = abs(nLumDelta) > gradientThreshold;
                                            doneNP = doneP && doneN;
#if(FXAA_SEARCH_STEPS > 11)
                                            if (!doneNP)
                                            {
                                                if (!doneP)posP += edgeStep * FXAA_SEARCH_S11;
                                                if (!doneN)posN -= edgeStep * FXAA_SEARCH_S11;
                                                if (!doneP)pLumDelta = GetLuminance(posP) - edgeLuma;
                                                doneP = abs(pLumDelta) > gradientThreshold;
                                                if (!doneN)nLumDelta = GetLuminance(posN) - edgeLuma;
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
    
    
    half3 result = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, posF).rgb;
                
    return result;

}

half3 TAAPixelShader(float2 pos)
{
    half3 curFrameColor = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, pos).rgb;
    if (_Jitter.z == 0)
    {
        return curFrameColor;
    }
    //depth compare
    float4 offsetNegetive = (_CameraDepthSize.zwzw * float4(0,-1,-1,0)) + pos.xyxy;
    float4 offsetPositive = (_CameraDepthSize.zwzw * float4(1,0,0,1)) + pos.xyxy;
    float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, offsetNegetive.xy);
    float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, offsetNegetive.zw);
    float3 compare = lerp(float3(0, -1, depth0), float3(-1, 0, depth1), COMPARE_DEPTH(depth1, depth0));
    depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, offsetPositive.xy);
    depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, offsetPositive.zw);
    compare = lerp(compare, float3(1, 0, depth0), COMPARE_DEPTH(depth0, compare.z));
    compare = lerp(compare, float3(0, 1, depth1), COMPARE_DEPTH(depth1, compare.z));
    depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, pos.xy);
    compare = lerp(compare, float3(0, 0, depth0), COMPARE_DEPTH(depth0, compare.z));
    float2 closetPos = pos.xy + compare.xy * _CameraColorSize.zw;
    
    float curObjectID = SAMPLE_DEPTH_TEXTURE(_LCurrentObjectIDTexture, sampler_PointClamp, closetPos);
    bool needToTAA = curObjectID <= 0.5f;
    UNITY_BRANCH
    if (needToTAA)
    {
        //motion vector
        float2 velocity = MotionVectorDecode(SAMPLE_TEXTURE2D(_LMotionVectorTexture, sampler_PointClamp, closetPos).xy);

        //cur frame jitter
        float2 jitterPos = pos.xy + _Jitter.xy;
        half3 curFrameColorJitter = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, jitterPos).rgb;

        //4 dir color
        offsetNegetive = (float4(-1, 0, 0, -1) * _CameraColorSize.zwzw) + pos.xyxy;
        offsetPositive = (float4(1, 0, 0, 1) * _CameraColorSize.zwzw) + pos.xyxy;
        half3 color0 = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, offsetNegetive.xy).rgb;
        half3 color1 = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, offsetNegetive.zw).rgb;
        half3 color2 = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, offsetPositive.xy).rgb;
        half3 color3 = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_LinearClamp, offsetPositive.zw).rgb;
        half3 addColor = (color0 + color1 + color2 + color3);
        //
        half3 addColor1 = curFrameColorJitter - addColor * 0.25f;
        half3 curframeFinalColor = addColor1 * _TAAParams.w * 2.71f + curFrameColorJitter;
        //现在先暂时不加深描边，直接输出jitter后的颜色
        curframeFinalColor = curFrameColorJitter;
        curframeFinalColor = max(curframeFinalColor, 0.f);
        curframeFinalColor = min(curframeFinalColor, 64500.f);

        //last frame id
        float lastFrameObjectID = SAMPLE_DEPTH_TEXTURE(_LLastObjectIDTexture, sampler_PointClamp, closetPos);
        bool isEdge = curObjectID < 0.1f && lastFrameObjectID > 0.1f;
        // return half3(isEdge,isEdge,isEdge);
        UNITY_BRANCH
        if (!isEdge)
        {
            float2 lastPos = pos + velocity;
            half3 lastFrameColor = SAMPLE_TEXTURE2D(_LLastFrame, sampler_LinearClamp, lastPos).rgb;
            //4 dir clamp
            half3 minColor = min(curFrameColor, color0);
            minColor = min(minColor, color1);
            minColor = min(minColor, color2);
            minColor = min(minColor, color3);
            half3 maxColor = max(curFrameColor, color0);
            maxColor = max(maxColor, color1);
            maxColor = max(maxColor, color2);
            maxColor = max(maxColor, color3);
            half3 lastFrameFinalColor = max(lastFrameColor, minColor);
            lastFrameFinalColor = min(lastFrameFinalColor, maxColor);
        
            //motion vector length for lerp
            float motionLength = length(velocity);
            float motionLengthClamp = clamp(motionLength * _TAAParams.z, 0.0, 1.0);
            float motionWeight = lerp(_TAAParams.x, _TAAParams.y, motionLengthClamp);
        
            half3 finalColor = lerp(curframeFinalColor, lastFrameFinalColor, motionWeight);
            finalColor = max(finalColor, 0.f);
            finalColor = min(finalColor, 64500.f);
            return finalColor;
        }
        else
        {
            half3 finalColor = curframeFinalColor + addColor;
            finalColor *= 0.2f;
            finalColor = max(finalColor, 0.f);
            finalColor = min(finalColor, 64500.f);
            return finalColor;
        }
        
    }
    else
    {
        return curFrameColor;
    }
}

#endif
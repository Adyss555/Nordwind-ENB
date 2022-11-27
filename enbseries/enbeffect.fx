//===================== V1.0 =======================//
//   _   _               _          _           _   //
//  | \ | | ___  _ __ __| |_      _(_)_ __   __| |  //
//  |  \| |/ _ \| '__/ _` \ \ /\ / / | '_ \ / _` |  //
//  | |\  | (_) | | | (_| |\ V  V /| | | | | (_| |  //
//  |_| \_|\___/|_|  \__,_| \_/\_/ |_|_| |_|\__,_|  //
//                                                  //
//        An ENB Preset by Guts and Adyss           //
//==================================================//
// Further shader credits:                          //
// Sandvich Maker: ReforgedUI, HLSL Graphing        //
// MartyMcFly: ADOF, Lens Distortion                //
// Ceejay.dk: Vibrance and Curve                    //
// Prod80: Color Isolation, Channel Saturation      //
// martinsh: Film grain                             //
// Krzysztof Narkowicz: ACES Tonemapping            //
// kingeric1992: some bits here and there           //
// TreyM: some helper functions and genral Advice   //
//==================================================//

//==================================================//
// Textures                                         //
//==================================================//
Texture2D TextureColor;         // HDR color
Texture2D TextureOriginal;      // color R16B16G16A16 64 bit hdr format
Texture2D TextureBloom;         // ENB bloom
Texture2D TextureLens;          // ENB lens fx
Texture2D TextureAdaptation;    // ENB adaptation
Texture2D TextureDepth;         // Scene depth
Texture2D TextureAperture;      // This frame aperture 1*1 R32F hdr red channel only . computed in depth of field shader file
Texture2D TexturePalette;       // enbpalette texture, if loaded and enabled in [colorcorrection].

//temporary textures which can be set as render target for techniques via annotations like <string RenderTarget="RenderTargetRGBA32";>
Texture2D RenderTargetRGBA32;   //R8G8B8A8 32 bit ldr format
Texture2D RenderTargetRGBA64;   //R16B16G16A16 64 bit ldr format
Texture2D RenderTargetRGBA64F;  //R16B16G16A16F 64 bit hdr format
Texture2D RenderTargetR16F;     //R16F 16 bit hdr format with red channel only
Texture2D RenderTargetR32F;     //R32F 32 bit hdr format with red channel only
Texture2D RenderTargetRGB32F;   //32 bit hdr format without alpha

//==================================================//
// Internals                                        //
//==================================================//
#include "Include/Shared/Globals.fxh"
#include "Include/Shared/ReforgedUI.fxh"
#include "Include/Shared/Conversions.fxh"
#include "Include/Shared/ictcp_colorspaces.fx"
#include "Include/Shared/BlendingModes.fxh"

//==================================================//
// UI                                               //
//==================================================//
UI_MESSAGE(m1,                      " \x95 Nordwind \x95 ")
UI_MESSAGE(m2,                      "An ENB Preset by Guts and Adyss")
UI_WHITESPACE(1)
#define UI_PREFIX_MODE PREFIX
#define UI_CATEGORY Color
UI_SEPARATOR
UI_FLOAT_DNI(Exposure,              " Exposure",            -3.0, 10.0, 0.0)
UI_FLOAT_DNI(Gamma,                 " Gamma",               0.1, 3.0, 1.0)
UI_FLOAT3_DNI(RGBGamma,             " RGB Gamma",           0.5, 0.5, 0.5)
UI_FLOAT_FINE_DNI(colorTempK,       " Color Temperature",   1000.0, 30000.0, 7000.0, 20.0)
UI_FLOAT_DNI(Desaturation,          " Desaturation",        0.0, 1.0, 0.0)
UI_FLOAT_DNI(Resaturation,          " Resaturation",        0.0, 2.0, 0.0)
UI_FLOAT(adaptImapct,               " Adaptation Impact",   0.0, 8.0, 1.0)
UI_WHITESPACE(2)
#define UI_CATEGORY Bloom
UI_SEPARATOR
UI_FLOAT_DNI(bloomIntensity,        " Intensity",           0.0, 3.0, 0.5)
UI_FLOAT_DNI(bloomDampening,        " Dampening",           0.0, 1.0, 0.5)
UI_FLOAT_DNI(softBloomIntensity,    " Soft Bloom Intensity",0.0, 3.0, 1.0)
UI_FLOAT_DNI(softBloomMix,          " Soft Bloom Mixing",   0.0, 1.0, 0.1)
UI_WHITESPACE(3)
#define UI_CATEGORY AISS
UI_SEPARATOR
UI_FLOAT(isSatImpact,               " Saturation Impact",   0.0, 3.0, 1.0)
UI_FLOAT(isMinSat,                  " Min Saturation",      0.0, 3.0, 0.0)
UI_FLOAT(isMaxSat,                  " Max Saturation",      0.0, 3.0, 1.0)
UI_FLOAT(isConImpact,               " Contrast Impact",     0.0, 3.0, 1.0)
UI_FLOAT(isMinCon,                  " Min Contrast",        0.0, 3.0, 0.0)
UI_FLOAT(isMaxCon,                  " Max Contrast",        0.0, 3.0, 1.0)
UI_FLOAT(isBriImpact,               " Brightness Impact",   0.0, 3.0, 1.0)
UI_FLOAT(isMinBri,                  " Min Brightness",      0.0, 3.0, 0.0)
UI_FLOAT(isMaxBri,                  " Max Brightness",      0.0, 3.0, 1.0)
UI_FLOAT(isMinTintCol,              " Min Tint Color",      0.0, 1.0, 0.0)
UI_FLOAT(isMaxTintCol,              " Max Tint Color",      0.0, 1.0, 1.0)
UI_FLOAT(isTintImpact,              " Tint Impact",         0.0, 3.0, 1.0)
UI_FLOAT(isMinTint,                 " Min Tint",            0.0, 3.0, 0.0)
UI_FLOAT(isMaxTint,                 " Max Tint",            0.0, 3.0, 1.0)
UI_WHITESPACE(4)
#define UI_CATEGORY Debug
UI_SEPARATOR
UI_BOOL(showBloom,                  " Show Bloom Texture",      false)
UI_BOOL(showLens,                   " Show Lens Texture",       false)
UI_BOOL(showAdapt,                  " Show Adaptation Level",   false)

//==================================================//
// Functions                                        //
//==================================================//

// Shorter version
float3 fujiFLog(float3 color)
{
    float a = 0.555556;
    float b = 0.009468;
    float c = 0.344676;
    float d = 0.790453;

    return c * log10(a * color + b) + d;
}

float3 ColorTemperatureToRGB(float temperatureInKelvins)
{
	float3 retColor;

    temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;

    if (temperatureInKelvins <= 66.0)
    {
        retColor.r = 1.0;
        retColor.g = saturate(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098);
    }
    else
    {
    	float t = temperatureInKelvins - 60.0;
        retColor.r = saturate(1.29293618606274509804 * pow(t, -0.1332047592));
        retColor.g = saturate(1.12989086089529411765 * pow(t, -0.0755148492));
    }

    if (temperatureInKelvins >= 66.0)
        retColor.b = 1.0;
    else if(temperatureInKelvins <= 19.0)
        retColor.b = 0.0;
    else
        retColor.b = saturate(0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914);

    return retColor;
}

// Apply wb lumapreserving
float3 whiteBalance(float3 color, float luma)
{
    color /= luma;
    color *= ColorTemperatureToRGB(colorTempK);
    return color * luma;
}


// Frostbyte style tonemap by Sandvich http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=6239&sid=affec87216d29e0bd1a04bc515552bc6
float3 frostbyteTonemap(float3 Color, float agcc_saturation)
{
    float3 ictcp        = rgb2ictcp(Color);
    float  saturation   = pow(smoothstep(1.0, 1.0 - Desaturation, ictcp.x), 1.3);
           Color        = ictcp2rgb(ictcp * float3(1.0, saturation.xx));
           Color        = fujiFLog(Color);
           Color        = rgb2ictcp(Color);
    float  satBoost     = Resaturation * smoothstep(1.0, 0.5, ictcp.x);
           Color.yz     = lerp(Color.yz, ictcp.yz * Color.x / max(1e-3, ictcp.x), satBoost);
           Color.yz    *= agcc_saturation;
           Color        = ictcp2rgb(Color);
    return saturate(Color);
}

//==================================================//
// Pixel Shaders                                    //
//==================================================//
float3	PS_Color(VS_OUTPUT IN) : SV_Target
{
    float2  coord        = IN.txcoord.xy;
    float3  Color        = TextureColor.Sample(PointSampler,  coord);
    float3  Bloom        = TextureBloom.Sample(LinearSampler, coord);
    float3  Lens         = TextureLens.Sample(LinearSampler, coord);
    float   Adapt        = TextureAdaptation.Load(int3(0, 0, 0));

            // Mix Bloom
    float3  sBloom       = Lens * ENBParams01.x * softBloomIntensity;
    float3  mBloom       = (Bloom * ENBParams01.x * bloomIntensity) + (Lens * softBloomMix); // Also mix a bit of soft bloom here
    float3  bColor       = max(Color, mBloom + sBloom);
            Color        = lerp(Color, sBloom, softBloomMix);
            Color       += mBloom / (1 + lerp(Color, bColor, bloomDampening));

            //Debug
            if(showBloom) return Bloom;
            if(showLens)  return Lens;
            if(showAdapt) return Adapt;

    // AISS (Ady's imagespace Spagetti. Ty Kitsuune for that name ;)
    // imagespace(is) values from weather
    float   isSat       = clamp(Params01[3].x * isSatImpact, isMinSat, isMaxSat);   // 0 == gray scale
    float   isCon       = clamp(Params01[3].z * isConImpact, isMinCon, isMaxCon);   // 0 == no contrast
    float   isBri       = clamp(Params01[3].w * isBriImpact, isMinBri, isMaxBri);   // intensity
    float3  isTintCol   = clamp(Params01[4].rgb, isMinTintCol, isMaxTintCol);       // tint color
    float   isTintUse   = clamp(Params01[4].w * isTintImpact, isMinTint, isMaxTint);// 0 == no tint
    float3  isFadeCol   = Params01[5].xyz;                                          // fade current scene to specified color, mostly used in special effects
    float   isFadeUse   = Params01[5].w;                                            // 0 == no fade

    // Color edits
            Color       = ldexp(Color, Exposure + isBri - (Adapt * adaptImapct)); // exposure
            Color       = frostbyteTonemap(Color, isSat);
            Color       = pow(Color, (Gamma - RGBGamma) + 0.5 + isCon);
    float   Luma        = saturate(GetLuma(Color, Rec709)); // saturate here cuz the WhiteBalance shader has issues with higher values than 1
            Color       = whiteBalance(Color, Luma);

            Color       = lerp(Color, Luma * isTintCol, isTintUse);
            Color       = lerp(Color, isFadeCol, isFadeUse);

    return saturate(Color + triDither(Color, coord, Timer.x, 16)) * 1.15;
}

//==================================================//
// Techniques                                       //
//==================================================//
technique11 Draw <string UIName="Nordwind";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Color()));
    }
}
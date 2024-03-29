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

static const float scale = 2.0; // Size of blur used for HDR and Fog shader. Range 0.0 - 3.0

//==================================================//
// Textures                                         //
//==================================================//
Texture2D   TextureOriginal;     // color R16B16G16A16 64 bit hdr format
Texture2D   TextureColor;        // color which is output of previous technique (except when drawed to temporary render target), R16B16G16A16 64 bit hdr format
Texture2D   TextureDepth;        // scene depth R32F 32 bit hdr format
Texture2D   TextureJitter;       // blue noise
Texture2D   TextureMask;         // alpha channel is mask for skinned objects (less than 1) and amount of sss
Texture2D   TextureNormal;       // Normal maps. Alpha seems to only effect a few selected objects (specular map i guess)

Texture2D   RenderTargetRGBA32;  // R8G8B8A8 32 bit ldr format
Texture2D   RenderTargetRGBA64;  // R16B16G16A16 64 bit ldr format
Texture2D   RenderTargetRGBA64F; // R16B16G16A16F 64 bit hdr format
Texture2D   RenderTargetR16F;    // R16F 16 bit hdr format with red channel only
Texture2D	RenderTargetR32F;    // R32F 32 bit hdr format with red channel only
Texture2D   RenderTargetRGB32F;  // 32 bit hdr format without alpha

//==================================================//
// Internals                                        //
//==================================================//
#include "Include/Shared/Globals.fxh"
#include "Include/Shared/ReforgedUI.fxh"
#include "Include/Shared/Conversions.fxh"
#include "Include/Shared/BlendingModes.fxh"

//==================================================//
// UI                                               //
//==================================================//
UI_MESSAGE(1,                   "|----- HDR -----")
UI_FLOAT(ShadowRange,           "|  Calibrate Shadow Range",    0.0, 1.0, 0.18)
UI_FLOAT(LiftShadows,           "|  Lighten Shadows",           0.0, 1.0, 0.2)
UI_FLOAT(hdrCurve,              "|  HDR Curve",                 0.0, 2.2, 1.0)
UI_FLOAT(hdrMix,                "|  HDR Balance",               0.0, 1.0, 0.5)
UI_FLOAT(hdrStrength,           "|  HDR Mix",                   0.0, 1.0, 0.0)
UI_WHITESPACE(1)
UI_MESSAGE(2,                   "|----- Atmosphere -----")
UI_BOOL(enableAtmosphere,       "| Enable Atmosphere",          false)
UI_FLOAT_EI(airDensity,         "|  Air Density",               0.0, 10.0, 0.0)
UI_FLOAT3_EI(airTint,           "|  Air Tint",                  1.0, 1.0, 1.0)
UI_FLOAT_EI(nearPlane,          "|  Air Distance",              0.0, 10.0, 1.0)
UI_FLOAT_EI(farPlane,           "|  Air Start",                 0.0, 10.0, 0.0)
UI_BOOL(showMask,               "|  Show mask",                 false)
UI_WHITESPACE(2)
UI_MESSAGE(3,                   "|----- Sharpening -----")
UI_BOOL(enableSharpening,       "| Enable Sharpening",          false)
UI_FLOAT(SharpenigOffset,       "|  Sharpening Offset",         0.2, 2.0, 1.0)
UI_FLOAT(SharpeningStrength,    "|  Sharpening Strength",      	0.2, 3.0, 1.0)
UI_FLOAT(SharpDistance,         "|  Sharpening Fadeout",        0.1, 15.0, 3.0)
UI_BOOL(ignoreSkin,             "|  Ignore Skin",               false)
UI_WHITESPACE(3)
UI_MESSAGE(4,                   "|----- Skin -----")
UI_BOOL(enableSkinEdit,         "| Enable Skin Edit",           false)
UI_FLOAT(skinGamma,             "|  Skin Gamma",			    0.2, 2.2, 1.0)
UI_INT(skinTone,                "|  Skin Tone",                 1.0, 100.0, 50.0)
UI_FLOAT3(skinTint,             "|  Skin Tint",                 0.5, 0.5, 0.5)
UI_FLOAT(skinCut,               "|  Effect fade distance",      0.0, 10.0, 1.0)
UI_WHITESPACE(4)
UI_MESSAGE(5,                   "|----- Sun -----")
UI_BOOL(enableSunGlow,          "| Enable Glow",                false)
UI_FLOAT(glowStrength,          "|  Glow Strength",             0.1, 3.0, 1.0)
UI_FLOAT(glowThreshold,         "|  Glow Threshold",            0.0, 1.0, 0.1)
UI_FLOAT(glowCurve,             "|  Glow Curve",                0.1, 3.0, 1.0)
UI_FLOAT3(glowTint,             "|  Glow Tint",                 0.5, 0.5, 0.5)
UI_FLOAT(sunDarkening,          "|  Darken around Sun",         0.0, 1.0, 0.0)
UI_WHITESPACE(5)
UI_MESSAGE(6,                   "|----- AA -----")
UI_BOOL(enableFxaa,             "| Enable FXAA",                false)
UI_FLOAT(fxaaEdgeThreshhold,    "|  FXAA Edge Threshhold ",	    0.0, 1.0, 0.0)
UI_FLOAT(fxaaEdgeThreshholdMin, "|  FXAA Edge Threshhold Min",	0.0, 1.0, 0.0)
UI_FLOAT(fxaaSubpixCap,         "|  FXAA Subpix Cap",	        0.0, 3.0, 0.75)
UI_FLOAT(fxaaSubpixTrim,        "|  FXAA Subpix Trim",	        0.0, 1.0, 0.12)


//==================================================//
// Functions                                		//
//==================================================//
#include "Include/Shaders/sharpening.fxh"
#include "Include/Shaders/SMAA/enbsmaa.fx"
#include "Include/Shaders/FXAA3.fxh"

float2 getSun()
{
    float3 Sundir       = SunDirection.xyz / SunDirection.w;
    float2 Suncoord     = Sundir.xy / Sundir.z;
           Suncoord     = Suncoord * float2(0.48, ScreenSize.z * 0.48) + 0.5;
           Suncoord.y   = 1.0 - Suncoord.y;
    return Suncoord;
}

float getGlow(float2 uv, float2 pos)
{
    return 1.0 / (length(uv - pos) * 16.0 + 1.0);
}

// Output is 1 if looking directly at the sun. As soon as you move away from it, it gets lower. If the sun is not on the screen the output is 0;
float getSunvisibility()
{
    return saturate(lerp(1, 0, distance(getSun(), float2(0.5, 0.5))));
}

//==================================================//
// Pixel Shaders                                    //
//==================================================//
float3	PS_Color(VS_OUTPUT IN) : SV_Target
{
    float2 coord        = IN.txcoord.xy;
    float3 blur         = TextureColor.Sample(LinearSampler, coord);
    float3 color        = TextureOriginal.Sample(PointSampler, coord);
    float4 ambient      = TextureMask.Sample(LinearSampler, coord);
    float  depth        = getLinearizedDepth(coord);
    float  skinned      = floor(1 - ambient.a) * saturate(1 - smoothstep(0.0, skinCut * 0.03, depth)); // Floor here gets rid of "skinned" objects and reveals only Skin for the most part
    float  sky          = floor(depth); // returns only the sky as pure white

    // Skin Color edits
    float3 skinColor    = color * skinned;
           skinColor    = lerp(pow(skinColor, float3(1.0, 0.95, 0.9)), pow(skinColor, float3(0.85, 0.9, 1.0)), skinTone *  0.01);
           skinColor    = pow(skinColor, skinGamma);
           skinColor    = skinColor * (0.5 + skinTint);
           color        = lerp(color, skinColor, skinned * enableSkinEdit);

    // HDR and shadowlifter
    float  Lo           = ShadowRange - saturate(min3(color));
           color        = lerp(color, lerp(color, max(color, ambient), Lo), LiftShadows);
    float  luma         = GetLuma(color, Rec709);
    float  blurLuma     = GetLuma(blur, Rec709);
    float  sqrtLum 	    = sqrt(luma);
    float  hdrLuma      = log(1.0 + sqrtLum + (ambient * luma * blurLuma));
    float3 contrast     = pow(color * hdrLuma, hdrCurve);
    float3 light        = pow(color / hdrLuma, hdrCurve);
           color        = lerp(color, max(lerp(light, contrast, hdrMix), 0.0), hdrStrength);

    // Atmosphere Shader by TreyM. Modified by Adyss
    float fogPlane      = (1 - saturate((depth - nearPlane) / (farPlane - nearPlane)));

          if(enableAtmosphere)
          color         = lerp(BlendScreenHDR(blur, airTint), color, exp(-airDensity * fogPlane));

          if(showMask)
          return fogPlane;

    // Sunglow Shader
    float2 sunPos       = getSun();
    float3 sunOpacity   = TextureColor.Sample(LinearSampler, sunPos);
    float  sunVis       = getSunvisibility();
    float  sunLuma      = max3(sunOpacity);
           sunOpacity   = max(0, sunLuma - glowThreshold);
           sunOpacity  /= max(sunLuma, 0.0001);
    float3 glow         = getGlow(float2(coord.x, coord.y * ScreenSize.w), float2(sunPos.x, sunPos.y * ScreenSize.w));
           glow         = pow(glow, glowCurve);
           glow        += triDither(glow, coord, Timer.x, 8); //clean up a bit

           if(enableSunGlow && !EInteriorFactor && SunDirection.z > 0.0)
           {
                color *= lerp(1, (1 - sunDarkening), sunVis * (sunVis * sunDarkening) - glow);
                color  = BlendScreenHDR(color, (glow * sunOpacity * glowStrength * glowTint));
           }

    return color;
}

// I prefer it having its own entire pass
float4 PS_FXAA(VS_OUTPUT IN) : SV_Target
{
    return enableFxaa ? FXAA(TextureColor, IN.txcoord.xy) : TextureColor.Sample(PointSampler, IN.txcoord.xy);
}

float3 PS_Test(VS_OUTPUT IN,  float4 v0 : SV_Position0) : SV_Target
{
    float2 coord    = IN.txcoord.xy;
    float4 ambient  = TextureMask.Sample(PointSampler, coord);
    float4 normals  = TextureNormal.Sample(LinearSampler, coord);


    // float  topLight     = dot(normals.y, lightTop);
    // float  botLight     = dot(1 - normals.y, lightBot);
    // float  rightLight   = dot(normals.x, lightRight);
    // float  leftLight    = dot(normals.z, lightLeft);


    return 0; //topLight + botLight + rightLight + leftLight;
}

// down and updsampling does wonders for Blurring
float3	PS_Resample(VS_OUTPUT IN, uniform bool upsample) : SV_Target
{
    float2 coord = upsample ? (IN.txcoord.xy - 0.5) / scale + 0.5 : (IN.txcoord.xy - 0.5) * scale + 0.5; // either up or down
    float3 Blur = 0.0;

    static const float2 Offsets[8]=
    {
        float2(0.7, 0.7),
        float2(0.7, -0.7),
        float2(-0.7, 0.7),
        float2(-0.7, -0.7),
        float2(0.0, 1.0),
        float2(-1.0, 0.0),
        float2(0.0, -1.0),
        float2(1.0, 0.0),
    };

    for (int i = 0; i < 8; i++)
    {
        Blur += TextureColor.Sample(BorderSampler, coord + Offsets[i] * PixelSize * scale, 0);
    }

    return Blur * 0.125;
}

//==================================================//
// Techniques                                       //
//==================================================//

technique11 pre <string UIName="Nordwind Prepass";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(false)));
    }
}

technique11 pre1
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(false)));
    }
}

technique11 pre2
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(false)));
    }
}

technique11 pre3
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(true)));
    }
}

technique11 pre4
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(true)));
    }
}

technique11 pre5
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(true)));
    }
}

technique11 pre6
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Color()));
    }
}

technique11 pre7
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_FXAA()));
    }
}

technique11 pre8
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Sharpening()));
    }
}


// SMAA pases
technique11 smaa <string UIName="Nordwind + SMAA";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(false)));
    }
}

technique11 smaa1
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(false)));
    }
}

technique11 smaa2
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(false)));
    }
}

technique11 smaa3
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(true)));
    }
}

technique11 smaa4
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(true)));
    }
}

technique11 smaa5
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Resample(true)));
    }
}

technique11 smaa6
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Color()));
    }
}

technique11 smaa7
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_FXAA()));
    }
}

technique11 smaa8
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader (CompileShader(ps_5_0, PS_Sharpening()));
    }
}

technique11 smaa9 <string RenderTarget= SMAA_STRING(SMAA_EDGE_TEX);>
{
    pass Clear
    {
        SetVertexShader(CompileShader(vs_5_0, VS_SMAAClear()));
        SetPixelShader (CompileShader(ps_5_0, PS_SMAAClear()));
    }

    pass EdgeDetection
    {
        SetVertexShader(CompileShader(vs_5_0, VS_SMAAEdgeDetection()));
        SetPixelShader (CompileShader(ps_5_0, PS_SMAAEdgeDetection()));
    }
}

technique11 smaa10 <string RenderTarget=SMAA_STRING(SMAA_BLEND_TEX);>
{
    pass Clear
    {
        SetVertexShader(CompileShader(vs_5_0, VS_SMAAClear()));
        SetPixelShader (CompileShader(ps_5_0, PS_SMAAClear()));
    }

    pass BlendingWeightCalculation
    {
        SetVertexShader(CompileShader(vs_5_0, VS_SMAABlendingWeightCalculation()));
        SetPixelShader (CompileShader(ps_5_0, PS_SMAABlendingWeightCalculation()));
    }
}

technique11 smaa11
{
    pass NeighborhoodBlending
    {
        SetVertexShader(CompileShader(vs_5_0, VS_SMAANeighborhoodBlending()));
        SetPixelShader (CompileShader(ps_5_0, PS_SMAANeighborhoodBlending()));
    }
}

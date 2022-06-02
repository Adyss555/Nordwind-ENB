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

#define scale 2.0 // Size of blur used in many effects in this file. Range 0.0 - 3.0

//==================================================//
// Textures                                         //
//==================================================//
Texture2D			TextureOriginal;     // color R16B16G16A16 64 bit hdr format
Texture2D			TextureColor;        // color which is output of previous technique (except when drawed to temporary render target), R16B16G16A16 64 bit hdr format
Texture2D			TextureDepth;        // scene depth R32F 32 bit hdr format
Texture2D			TextureJitter;       // blue noise
Texture2D			TextureMask;         // alpha channel is mask for skinned objects (less than 1) and amount of sss
Texture2D           TextureNormal;       // Normal maps. Alpha seems to only effect a few selected objects (specular map i guess)

Texture2D			RenderTargetRGBA32;  // R8G8B8A8 32 bit ldr format
Texture2D			RenderTargetRGBA64;  // R16B16G16A16 64 bit ldr format
Texture2D			RenderTargetRGBA64F; // R16B16G16A16F 64 bit hdr format
Texture2D			RenderTargetR16F;    // R16F 16 bit hdr format with red channel only
Texture2D			RenderTargetR32F;    // R32F 32 bit hdr format with red channel only
Texture2D			RenderTargetRGB32F;  // 32 bit hdr format without alpha

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
UI_MESSAGE(1,                   "|===== Fake HDR =====")
UI_FLOAT(ShadowRange,           "| Calibrate Shadow Range",     0.0, 1.0, 0.18)
UI_FLOAT(LiftShadows,           "| Lighten Shadows",            0.0, 1.0, 0.2)
UI_FLOAT(shadowBlur,            "| Blur Shadows",               0.0, 1.0, 0.1)
UI_FLOAT(HDRTone,               "| HDR Tone",                   0.0, 1.0, 0.0)
UI_WHITESPACE(1)
UI_MESSAGE(2,                   "|===== Atmosphere =====")
UI_BOOL(enableAtmosphere,       "| Enable Atmosphere",          false)
UI_FLOAT_EI(airDensity,         "| Air Density",                0.0, 10.0, 0.0)
UI_FLOAT3_EI(airTint,           "| Air Tint",                   1.0, 1.0, 1.0)
UI_FLOAT_EI(nearPlane,          "| Air Distance",               0.0, 10.0, 1.0)
UI_FLOAT_EI(farPlane,           "| Air Start",                  0.0, 10.0, 0.0)
UI_BOOL(showMask,               "| Show mask",                  false)
UI_WHITESPACE(2)
UI_MESSAGE(3,                   "|===== Sharpening =====")
UI_BOOL(enableSharpening,       "| Enable Sharpening",          false)
UI_FLOAT(SharpenigOffset,       "| Sharpening Offset",          0.2, 2.0, 1.0)
UI_FLOAT(SharpeningStrength,    "| Sharpening Strength",      	0.2, 3.0, 1.0)
UI_FLOAT(SharpDistance,         "| Sharpening Fadeout",			0.1, 15.0, 3.0)
UI_BOOL(ignoreSkin,             "| Ignore Skin",                false)


//==================================================//
// Functions                                		//
//==================================================//
#include "Include/Shaders/sharpening.fxh"

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

    // Calc Shadows and Hightlights and edit them
    float  Lo           = ShadowRange - saturate(min3(color));
           color        = lerp(color, lerp(color, max(color, ambient), Lo), LiftShadows);
           color        = lerp(color, blur, saturate(Lo * Lo * shadowBlur));

    // HDR Tone from Ansel
    float  luma         = GetLuma(color, Rec709);
    float  blurLuma     = GetLuma(blur, Rec709);
    float  sqrtLum 	    = sqrt(luma);
    float  HDRToning    = sqrtLum * lerp(sqrtLum * (2 * luma * blurLuma - luma - 2 * luma + 2.0), (2 * sqrtLum * blurLuma - 2 * blurLuma + 1), luma > 0.5); //modified soft light v1
      	   color        = color / (luma+1e-6) * lerp(luma, HDRToning, HDRTone);

    // Atmosphere Shader by TreyM
    float mip           = (1 - saturate((depth - nearPlane) / (farPlane - nearPlane)));

          if(enableAtmosphere)
          color         = lerp(BlendScreenHDR(blur, airTint), color, exp(-airDensity * mip));

          if(showMask)
          return mip;

    return color;
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
        SetPixelShader (CompileShader(ps_5_0, PS_Sharpening()));
    }
}

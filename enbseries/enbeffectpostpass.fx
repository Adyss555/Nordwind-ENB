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
// Textures                                 		//
//==================================================//
Texture2D		TextureOriginal;     //color R10B10G10A2 32 bit ldr format
Texture2D		TextureColor;        //color which is output of previous technique (except when drawed to temporary render target), R10B10G10A2 32 bit ldr format
Texture2D		TextureDepth;        //scene depth R32F 32 bit hdr format

Texture2D		RenderTargetRGBA32;  //R8G8B8A8 32 bit ldr format
Texture2D		RenderTargetRGBA64;  //R16B16G16A16 64 bit ldr format
Texture2D		RenderTargetRGBA64F; //R16B16G16A16F 64 bit hdr format
Texture2D		RenderTargetR16F;    //R16F 16 bit hdr format with red channel only
Texture2D		RenderTargetR32F;    //R32F 32 bit hdr format with red channel only
Texture2D		RenderTargetRGB32F;  //32 bit hdr format without alpha

//==================================================//
// Internals                                		//
//==================================================//
#include "Include/Shared/Globals.fxh"
#include "Include/Shared/ReforgedUI.fxh"
#include "Include/Shared/Conversions.fxh"
#include "Include/Shared/Blendmodes.fxh"

//==================================================//
// UI                                       		//
//==================================================//
UI_MESSAGE(m1,                      "=== Letterbox ===")
UI_BOOL(enableLetterbox,            "   Enable Letterbox",	    	false)
UI_FLOAT(hBoxSize,                  "   Horizontal Size",			-0.5, 0.5, 0.1)
UI_FLOAT(vBoxSize,                  "   Vertical Size",          	-0.5, 0.5, 0.0)
UI_FLOAT(BoxRotation,               "   Letterbox Rotation",	    0.0, 6.0, 0.0)
UI_FLOAT3(BoxColor,                 "   Letterbox Color",         	0.0, 0.0, 0.0)
UI_FLOAT(LetterboxDepth,            "   Letterbox Distance",      	0.0, 10.0, 0.0)
UI_WHITESPACE(1)
UI_MESSAGE(m2,                      "=== Color ===")
UI_MESSAGE(m3,                      " Image Saturation:")
UI_FLOAT(vibrance,                  "   Vibrance",              	-1.0, 1.0, 0.10)
UI_FLOAT3(vibranceRGBBalance,       "   RGB Vibrance",           	1.0, 1.0, 1.0)
UI_FLOAT(saturation,                "   Global Saturation",        	0.0, 2.0, 1.0)
UI_FLOAT(sat_r,                     "   Red Saturation",         	-3.0, 3.0, 0.0)
UI_FLOAT(sat_y,                     "   Yellow Saturation",    		-3.0, 3.0, 0.0)
UI_FLOAT(sat_g,                     "   Green Saturation",         	-3.0, 3.0, 0.0)
UI_FLOAT(sat_a,                     "   Aqua Saturation",        	-3.0, 3.0, 0.0)
UI_FLOAT(sat_b,                     "   Blue Saturation",          	-3.0, 3.0, 0.0)
UI_FLOAT(sat_p,                     "   Purple Saturation",        	-3.0, 3.0, 0.0)
UI_FLOAT(sat_m,                     "   Magenta Saturation",       	-3.0, 3.0, 0.0)
UI_WHITESPACE(2)
UI_MESSAGE(m4,                      " Image Luminance:")
UI_FLOAT(exposure,                  "   Exposure",                 	-2.0, 2.0, 0.0)
UI_FLOAT(contrast,                  "   Contrast",	             	-1.0, 1.0, 0.0)
UI_FLOAT(inputGamma,                "   Gamma",	             		0.0, 2.2, 1.0)
UI_FLOAT(inputWhitePoint,           "   Level Input Whitepoint",	0.0, 2.0, 1.0)
UI_FLOAT(inputBlackPoint,           "   Level Input Blackpoint",	0.0, 2.0, 0.0)
UI_FLOAT(outputWhitePoint,          "   Level Outout Whitepoint",	0.0, 2.0, 1.0)
UI_FLOAT(outputBlackPoint,          "   Level Output Blackpoint",	0.0, 2.0, 0.0)
UI_WHITESPACE(3)
UI_MESSAGE(m5,                      " Luminance Curve:")
UI_FLOAT(CurveBlendL,               "   Luma Curve Power",     		0.0, 1.0, 0.0)
UI_FLOAT(LSP,                       "   Luma Curve Startpoint",		0.0, 1.0, 0.0)
UI_FLOAT(LCP1,                      "   Luma Curve Point 1",  		0.0, 10.0, 0.5)
UI_FLOAT(LCP2,                      "   Luma Curve Point 2", 		0.0, 10.0, 0.5)
UI_FLOAT(LEP,                       "   Luma Curve End Point",    	0.0, 1.0, 1.0)
UI_WHITESPACE(4)
UI_MESSAGE(m6,                      " Red Curve:")
UI_FLOAT(CurveBlendR,               "   Red Curve Power",         	0.0, 1.0, 0.0)
UI_FLOAT(RSP,                       "   Red Curve Startpoint",   	0.0, 1.0, 0.0)
UI_FLOAT(RCP1,                      "   Red Curve Point 1", 		0.0, 10.0, 0.5)
UI_FLOAT(RCP2,                      "   Red Curve Point 2", 		0.0, 10.0, 0.5)
UI_FLOAT(REP,                       "   Red Curve End Point",     	0.0, 1.0, 1.0)
UI_WHITESPACE(5)
UI_MESSAGE(m7,                      " Green Curve:")
UI_FLOAT(CurveBlendG,               "   Green Curve Power",        	0.0, 1.0, 0.0)
UI_FLOAT(GSP,                       "   Green Curve Startpoint",  	0.0, 1.0, 0.0)
UI_FLOAT(GCP1,                      "   Green Curve Point 1",   	0.0, 10.0, 0.5)
UI_FLOAT(GCP2,                      "   Green Curve Point 2",   	0.0, 10.0, 0.5)
UI_FLOAT(GEP,                       "   Green Curve End Point",    	0.0, 1.0, 1.0)
UI_WHITESPACE(6)
UI_MESSAGE(m8,                      " Blue Curve:")
UI_FLOAT(CurveBlendB,               "   Blue Curve Power",       	0.0, 1.0, 0.0)
UI_FLOAT(BSP,                       "   Blue Curve Startpoint",  	0.0, 1.0, 0.0)
UI_FLOAT(BCP1,                      "   Blue Curve Point 1",  		0.0, 10.0, 0.5)
UI_FLOAT(BCP2,                      "   Blue Curve Point 2",   		0.0, 10.0, 0.5)
UI_FLOAT(BEP,                       "   Blue Curve End Point",   	0.0, 1.0, 1.0)
UI_WHITESPACE(7)
UI_MESSAGE(m9,                      " Channel Isolation:")
UI_FLOAT_FINE(hueMid ,           	"   Hue Selection ",          	0.0, 1.0, 0.0, 0.001)
UI_FLOAT(hueRange  ,          	    "   Hue Range ",               	0.0, 1.0, 0.1)
UI_FLOAT(satLimit ,        			"   Saturation Limit",         	0.0, 1.0, 1.0)
UI_FLOAT(fxcolorMix  ,        	    "   Mix Isolated Color",       	0.0, 1.0, 0.2)
UI_WHITESPACE(8)
UI_MESSAGE(m10,                     "=== Vingette ===")
UI_BOOL(enableVingette,             "   Enable Vingette",          	false)
UI_FLOAT(vingetteIntesity,          "   Vingette Intesity",         0.0, 1.0, 0.1)
UI_WHITESPACE(9)
UI_MESSAGE(m11,                     "=== Grain ===")
UI_BOOL(enableGrain,                "   Enable Grain",             	false)
UI_INT(grainAmount,                 "   Grain Amount",            	0, 100, 50)
UI_INT(grainRoughness,              "   Grain Roughness",          	1, 3, 1)
UI_WHITESPACE(10)
UI_MESSAGE(m13,                     "=== Lens ===")
UI_BOOL(enableDistortion,           "   Enable Lens Distortion",   	false)
UI_INT(lensDistortion,              "   Distortion Amount",       	-100, 100, 0)
UI_WHITESPACE(12)
UI_BOOL(enableCA,                   "   Enable Chromatic Aberration",false)
UI_FLOAT(RadialCA,                  "   Aberration Strength",      	0.0, 2.5, 1.0)
UI_FLOAT(barrelPower,               "   Aberration Curve",         	0.0, 2.5, 1.0)
UI_WHITESPACE(13)
UI_MESSAGE(m14,                     "=== AA ===")
UI_BOOL(enableFxaa,                 "   Enable FXAA",             	false)

//==================================================//
// Functions                                		//
//==================================================//
#include "Include/Shaders/lensDistortion.fxh"
#include "Include/Shaders/letterbox.fxh"
#include "Include/Shaders/filmGrain.fxh"
//#include "Include/Shaders/lut.fxh"
#include "Include/Shaders/vibrance.fxh"
#include "Include/Shaders/channelSat.fxh"
#include "Include/Shaders/aces.fxh"
//#include "Include/Shaders/sharpening.fxh" //moved to prepass to mask out Skin
#include "Include/Shaders/colorIsolation.fxh"
#include "Include/Shaders/curve.fxh"
#include "Include/Shaders/FXAA.fxh"
#include "Include/Shaders/SMAA/enbsmaa.fx"

//==================================================//
// Pixel Shaders                            		//
//==================================================//

float3 PS_Color(VS_OUTPUT IN) : SV_Target
{
	float2 coord	= IN.txcoord.xy;
    float3 Color    = TextureColor.Sample(PointSampler, coord);
    float  Luma     = GetLuma(Color, Rec709);

           Color    = lerp(Luma, Color, saturation);
           Color    = channelsat(Color, sat_r, sat_y, sat_g, sat_a, sat_b, sat_p, sat_m, RGBtoHSL(Color).x);
           Color    = Vibrance(Color);
		   Color	= colorIso(Color);
		   Color 	= curveCombine(Color);
		   Color 	= lerp(Color, Color * Color * Color * (Color * (Color * 6.0 - 15.0) + 10.0), contrast); // Smootherstep curve
           Color 	= ACESFilm(Color); // Shadersin. But it looks so gud i just cant...
           Color    = ldexp(Color, exposure);
		   Color 	= pow(((Color) - inputBlackPoint) / (inputWhitePoint - inputBlackPoint) , inputGamma) * (outputWhitePoint - outputBlackPoint) + outputBlackPoint; // Levels

           // Apply Lut
           //if(ToggleLUT)
           //Color    = lutSwitch(Color);

    return Color;
}

float4 PS_PostFX(VS_OUTPUT IN) : SV_Target
{
    float2 coord    = IN.txcoord.xy;
    float4 Color    = TextureColor.Sample(PointSampler, coord);

    // Grain
    if(enableGrain)
    Color.rgb = GrainPass(coord, Color);

    // Vingette
    if(enableVingette)
    Color   *= pow(16.0 * coord.x * coord.y * (1.0 - coord.x) * (1.0 - coord.y), vingetteIntesity); // fast and simpel

    //Letterboxes
    if(enableLetterbox)
    Color   = applyLetterbox(Color, getLinearizedDepth(coord), coord);

    return Color;
}

float3 PS_LensDistortion(VS_OUTPUT IN) : SV_Target
{
    return LensDist(IN.txcoord.xy);
}

float3 PS_LensCABlur(VS_OUTPUT IN) : SV_Target
{
    return enableCA ? SampleBlurredImage(TextureColor.Sample(LinearSampler, IN.txcoord.xy), IN.txcoord.xy) : TextureColor.Sample(PointSampler, IN.txcoord.xy);
}

float3 PS_LensCA(VS_OUTPUT IN) : SV_Target
{
    return enableCA ? LensCA(IN.txcoord.xy) : TextureColor.Sample(PointSampler, IN.txcoord.xy);
}

//==================================================//
// Techniques                               		//
//==================================================//

technique11 post  <string UIName="Nordwind Postpass";>
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_FXAA()));
	}
}

technique11 post1
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_Color()));
	}
}

technique11 post2
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_LensDistortion()));
	}
}

technique11 post3
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_LensCABlur()));
	}
}

technique11 post4
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_LensCA()));
	}
}

technique11 post5
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_PostFX()));
	}
}

// This time with SMAA passes

technique11 smaa <string UIName= "Nordwind + SMAA";>
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_FXAA()));
	}
}

technique11 smaa1 <string RenderTarget= SMAA_STRING(SMAA_EDGE_TEX); >
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

technique11 smaa2 <string RenderTarget=SMAA_STRING(SMAA_BLEND_TEX);>
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

technique11 smaa3
{
    pass NeighborhoodBlending
    {
        SetVertexShader(CompileShader(vs_5_0, VS_SMAANeighborhoodBlending()));
        SetPixelShader (CompileShader(ps_5_0, PS_SMAANeighborhoodBlending()));
    }
}

technique11 smaa4
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_Color()));
	}
}

technique11 smaa5
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_LensDistortion()));
	}
}

technique11 smaa6
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_LensCABlur()));
	}
}

technique11 smaa7
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_LensCA()));
	}
}

technique11 smaa8
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
		SetPixelShader (CompileShader(ps_5_0, PS_PostFX()));
	}
}

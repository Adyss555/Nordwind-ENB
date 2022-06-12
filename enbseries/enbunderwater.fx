//===================== V1.0 =======================//
//   _   _               _          _           _   //
//  | \ | | ___  _ __ __| |_      _(_)_ __   __| |  //
//  |  \| |/ _ \| '__/ _` \ \ /\ / / | '_ \ / _` |  //
//  | |\  | (_) | | | (_| |\ V  V /| | | | | (_| |  //
//  |_| \_|\___/|_|  \__,_| \_/\_/ |_|_| |_|\__,_|  //
//                                                  //
//        An ENB Preset by Guts and Adyss           //
//==================================================//
// Underwater Shader by Adyss                       //
//==================================================//


//==========//
// Textures //
//==========//
Texture2D			TextureOriginal; //color R10B10G10A2 32 bit ldr format
Texture2D			TextureColor;    //color which is output of previous technique (except when drawed to temporary render target), R10B10G10A2 32 bit ldr format
Texture2D			TextureDepth;    //scene depth R32F 32 bit hdr format
Texture2D			TextureMask;     //mask of underwater area of screen
// .x seems like a transiton when you go into water
// .y 0 as soon as the view touches water 1 if youre fully underwater. No transition
// .z same as .y?
// .w 1 if view underwater

Texture2D			RenderTargetRGBA32;  //R8G8B8A8 32 bit ldr format
Texture2D			RenderTargetRGBA64;  //R16B16G16A16 64 bit ldr format
Texture2D			RenderTargetRGBA64F; //R16B16G16A16F 64 bit hdr format
Texture2D			RenderTargetR16F;    //R16F 16 bit hdr format with red channel only
Texture2D			RenderTargetR32F;    //R32F 32 bit hdr format with red channel only
Texture2D			RenderTargetRGB32F;  //32 bit hdr format without alpha

// Include Needes Values
#include "Include/Shared/Globals.fxh"
#include "Include/Shared/ReforgedUI.fxh"
#include "Include/Shared/Conversions.fxh"
#include "Include/Shared/BlendingModes.fxh"

float4	TintColor; //xyz - tint color; w - tint amount

UI_FLOAT(fogDensity,             " Underwater Fog Density",    0.0, 10.0, 0.0)
UI_FLOAT(nearPlane,              "  near Plane",               0.0, 10.0, 0.0)
UI_FLOAT(farPlane,               "  far Plane",                0.0, 10.0, 1.0)

float3	PS_Prepass(VS_OUTPUT IN) : SV_Target
{
    float2 coord    = IN.txcoord.xy;
    float3 Color    = TextureColor.Sample(PointSampler, coord);
    //clip(Color); // i hoped this would be a good workaround for the Letterbox issue. Does not work tho

	float  	Luma     = GetLuma(Color, Rec709);
	float4 	Mask     = TextureMask.Sample(LinearSampler, coord);
	float  	Depth    = getLinearizedDepth(coord);
	float  	Map      = (1 - saturate((Depth - nearPlane) / (farPlane - nearPlane))) * Mask.x;
		   	Color    = lerp(BlendScreenHDR(Color, TintColor.rgb * TintColor.a), Color, exp(-fogDensity * Map));

			Color    = 1 - exp(-Color);

	return 	Color;
}

// TECHNIQUES
technique11 Open <string UIName="Underwater";>
{
  pass p0
  {
    SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
    SetPixelShader (CompileShader(ps_5_0, PS_Prepass()));
  }
}

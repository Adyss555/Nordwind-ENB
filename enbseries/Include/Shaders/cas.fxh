// LICENSE
// =======
// Copyright (c) 2017-2019 Advanced Micro Devices, Inc. All rights reserved.
// -------
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// -------
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
// -------
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE

//Initial port to ReShade: SLSNe	https://gist.github.com/SLSNe/bbaf2d77db0b2a2a0755df581b3cf00c

//Optimizations by Marty McFly:
//	vectorized math, even with scalar gcn hardware this should work
//	out the same, order of operations has not changed
//	For some reason, it went from 64 to 48 instructions, a lot of MOV gone
//	Also modified the way the final window is calculated
//	  
//	reordered min() and max() operations, from 11 down to 9 registers	
//
//	restructured final weighting, 49 -> 48 instructions
//
//	delayed RCP to replace SQRT with RSQRT
//
//	removed the saturate() from the control var as it is clamped
//	by UI manager already, 48 -> 47 instructions
//
//	replaced tex2D with tex2Doffset intrinsic (address offset by immediate integer)
//	47 -> 43 instructions
//	9 -> 8 registers

//Further modified by OopyDoopy and Lord of Lunacy:
//	Changed wording in the UI for the existing variable and added a new variable and relevant code to adjust sharpening strength.

//Fix by Lord of Lunacy:
//	Made the shader use a linear colorspace rather than sRGB, as recommended by the original AMD documentation from FidelityFX.

//Modified by CeeJay.dk:
//	Included a label and tooltip description. I followed AMDs official naming guidelines for FidelityFX.
//
//	Used gather trick to reduce the number of texture operations by one (9 -> 8). It's now 42 -> 51 instructions but still faster
//	because of the texture operation that was optimized away.

//Fix by CeeJay.dk
//	Fixed precision issues with the gather at super high resolutions
//	Also tried to refactor the samples so more work can be done while they are being sampled, but it's not so easy and the gains
//	I'm seeing are so small they might be statistical noise. So it MIGHT be faster - no promises.

//Ported to ENB by Adyss
//  Just changed up some stuff for ENB.

float3 CASsharpening(float2 texcoord) : SV_Target
{
	// fetch a 3x3 neighborhood around the pixel 'e',
	//  a b c
	//  d(e)f
	//  g h i
	
	float3 b = TextureColor.SampleLevel(LinearSampler, texcoord, int2(0, -1)).rgb;
	float3 d = TextureColor.SampleLevel(LinearSampler, texcoord, int2(-1, 0)).rgb;
 
	float4 red_efhi = TextureColor.GatherRed(LinearSampler, texcoord + 0.5 * PixelSize);
	
	float3 e = float3( red_efhi.w, red_efhi.w, red_efhi.w);
	float3 f = float3( red_efhi.z, red_efhi.z, red_efhi.z);
	float3 h = float3( red_efhi.x, red_efhi.x, red_efhi.x);
	float3 i = float3( red_efhi.y, red_efhi.y, red_efhi.y);
	
	float4 green_efhi = TextureColor.GatherGreen(LinearSampler, texcoord + 0.5 * PixelSize);
	
	e.g = green_efhi.w;
	f.g = green_efhi.z;
	h.g = green_efhi.x;
	i.g = green_efhi.y;
	
	float4 blue_efhi = TextureColor.GatherBlue(LinearSampler, texcoord + 0.5 * PixelSize);
	
	e.b = blue_efhi.w;
	f.b = blue_efhi.z;
	h.b = blue_efhi.x;
	i.b = blue_efhi.y;

	float3 g = TextureColor.SampleLevel(LinearSampler, texcoord, int2(-1,  1)).rgb; 
	float3 a = TextureColor.SampleLevel(LinearSampler, texcoord, int2(-1, -1)).rgb;
	float3 c = TextureColor.SampleLevel(LinearSampler, texcoord, int2( 1, -1)).rgb;
   
	// Soft min and max.
	//  a b c			 b
	//  d e f * 0.5  +  d e f * 0.5
	//  g h i			 h
	// These are 2.0x bigger (factored out the extra multiply).
	float3 mnRGB = min(min(min(d, e), min(f, b)), h);
	float3 mnRGB2 = min(mnRGB, min(min(a, c), min(g, i)));
	mnRGB += mnRGB2;

	float3 mxRGB = max(max(max(d, e), max(f, b)), h);
	float3 mxRGB2 = max(mxRGB, max(max(a, c), max(g, i)));
	mxRGB += mxRGB2;

	// Smooth minimum distance to signal limit divided by smooth max.
	float3 rcpMRGB = rcp(mxRGB);
	float3 ampRGB = saturate(min(mnRGB, 2.0 - mxRGB) * rcpMRGB);	
	
	// Shaping amount of sharpening.
	ampRGB = rsqrt(ampRGB);
	
	float peak = -3.0 * casContrast + 8.0;
	float3 wRGB = -rcp(ampRGB * peak);

	float3 rcpWeightRGB = rcp(4.0 * wRGB + 1.0);

	//						  0 w 0
	//  Filter shape:		  w 1 w
	//						  0 w 0  
	float3 window = (b + d) + (f + h);
	float3 outColor = saturate((window * wRGB + e) * rcpWeightRGB);
	
	return lerp(e, outColor, casSharpening);
}
// Per channel curves by Adyss
// http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=6014

float Curve(float x, float4 CurveValues)
{
	x = CurveValues.x * (1 - x) * (1 - x) * (1 - x) + 3 * CurveValues.y * (1 - x) * (1 - x) * x + 3 * CurveValues.z * (1 - x) * x * x + CurveValues.w * x * x *x;
    return x;
}

float3 curveCombine(float3 Color)
{
	float  Luma = GetLuma(Color, Rec709);

	// Calculate chroma
	float3 Chroma  = Color.rgb - Luma;
		   Chroma += chromaShift; // Shift up so we dont go below 0 here

    // Apply
    Chroma.r = lerp(Chroma.r, Curve(Chroma.r, float4(RSP, RCP1, RCP2, REP)), CurveBlendR);  // Red
    Chroma.g = lerp(Chroma.g, Curve(Chroma.g, float4(GSP, GCP1, GCP2, GEP)), CurveBlendG);  // Green
	Chroma.b = lerp(Chroma.b, Curve(Chroma.b, float4(BSP, BCP1, BCP2, BEP)), CurveBlendB);  // Blue
    Luma     = lerp(Luma,     Curve(Luma,     float4(LSP, LCP1, LCP2, LEP)), CurveBlendL);  // Luminace

	if(curveScreenBlend)
	return BlendScreenHDR(Color, Luma + (Chroma - chromaShift)) * 0.57; // 0.57 here since screenBlend Darkens the image a lil

	if(!curveScreenBlend)
    return saturate(Luma + (Chroma - chromaShift));
}

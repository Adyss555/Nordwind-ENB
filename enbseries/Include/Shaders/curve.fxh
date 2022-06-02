// Per channel curves by Adyss
// http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=6014

float Curve(float x, float4 CurveValues)
{
	x = CurveValues.x * (1 - x) * (1 - x) * (1 - x) + 3 * CurveValues.y * (1 - x) * (1 - x) * x + 3 * CurveValues.z * (1 - x) * x * x + CurveValues.w * x * x *x;
    return max(x, 0);
}

float3 curveCombine(float3 Color)
{
	float  Luma = GetLuma(Color, Rec709);

	// Calculate chroma
	float3 Chroma = Color.rgb - Luma;

    // Pack up tweakable values so we dont need 4 times the same function
    float4 RedCurve, GreenCurve, BlueCurve, LumaCurve;
    RedCurve.x   = RSP, RedCurve.y   = RCP1, RedCurve.z   = RCP2, RedCurve.w   = REP;
    GreenCurve.x = GSP, GreenCurve.y = GCP1, GreenCurve.z = GCP2, GreenCurve.w = GEP;
    BlueCurve.x  = BSP, BlueCurve.y  = BCP1, BlueCurve.z  = BCP2, BlueCurve.w  = BEP;
    LumaCurve.x  = LSP, LumaCurve.y  = LCP1, LumaCurve.z  = LCP2, LumaCurve.w  = LEP;

    // Apply
    Chroma.r = lerp(Chroma.r, Curve(saturate(Chroma.r), RedCurve),   CurveBlendR);  // Red
    Chroma.g = lerp(Chroma.g, Curve(saturate(Chroma.g), GreenCurve), CurveBlendG);  // Green
    Chroma.b = lerp(Chroma.b, Curve(saturate(Chroma.b), BlueCurve),  CurveBlendB);  // Blue
    Luma     = lerp(Luma,     Curve(saturate(Luma),     LumaCurve),  CurveBlendL);  // Luminace

    return Chroma + Luma; // Combine
}

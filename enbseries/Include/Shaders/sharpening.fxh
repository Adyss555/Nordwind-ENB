// Basic Sharpening by Adyss
// This also removes outlines to fight aliasing and ignores Skin

float3 PS_Sharpening(VS_OUTPUT IN) : SV_Target
{
    float2 coord   = IN.txcoord.xy;
    float2 North   = float2(coord.x, coord.y + PixelSize.y * SharpenigOffset);
    float2 South   = float2(coord.x, coord.y - PixelSize.y * SharpenigOffset);
    float2 West    = float2(coord.x + PixelSize.x * SharpenigOffset, coord.y);
    float2 East    = float2(coord.x - PixelSize.x * SharpenigOffset, coord.y);

    float3 Color   = TextureColor.Sample(PointSampler, coord.xy);

    float3 Sharp   = Color;
           Sharp  += TextureColor.Sample(PointSampler, North);
           Sharp  += TextureColor.Sample(PointSampler, South);
           Sharp  += TextureColor.Sample(PointSampler, West);
           Sharp  += TextureColor.Sample(PointSampler, East); // PointSampler looks sharper but youll have to fight aliasing
           Sharp  *= 0.2;

    float  Skin           = TextureMask.Sample(PointSampler, coord).a;
    float  SharpeningMask = 1 - smoothstep(0.0, SharpDistance * 0.025, getLinearizedDepth(coord));

           if(ignoreSkin)
           SharpeningMask = SharpeningMask * Skin;

    float  SharpLuma = saturate(dot(Color - Sharp, SharpeningStrength * 0.3333));

    return enableSharpening ? Color + SharpLuma * SharpeningMask: Color;
}

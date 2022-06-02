// Original lut code by kingeric1992
// Slightly modified by Adyss

UI_BOOL(ToggleLUT,                  "  Enable LUT",                   false)
UI_INT(selectedLut,                 "  Selectet Lut",                 0.0, 2.0, 0.0)
UI_FLOAT(LUTAmount,                 "  Lut Amount",                   0.0, 1.0, 1.0)

// Textures
Texture2D   lutTextureDay1          <string ResourceName="Include/Textures/lutDay1.png"; >;
Texture2D   lutTextureNight1        <string ResourceName="Include/Textures/lutNight1.png"; >;
Texture2D   lutTextureInterior1     <string ResourceName="Include/Textures/lutInterior1.png"; >;

Texture2D   lutTextureDay2          <string ResourceName="Include/Textures/lutDay2.png"; >;
Texture2D   lutTextureNight2        <string ResourceName="Include/Textures/lutNight2.png"; >;
Texture2D   lutTextureInterior2     <string ResourceName="Include/Textures/lutInterior2.png"; >;

Texture2D   lutTextureDay3          <string ResourceName="Include/Textures/lutDay3.png"; >;
Texture2D   lutTextureNight3        <string ResourceName="Include/Textures/lutNight3.png"; >;
Texture2D   lutTextureInterior3     <string ResourceName="Include/Textures/lutInterior3.png"; >;

// Functions
float3 Lut(float3 colorIN, Texture2D lutTexIn, float2 lutSize)
{
    float2 CLut_pSize = 1.0 / lutSize;
    float4 CLut_UV;
    colorIN    = saturate(colorIN) * ( lutSize.y - 1.0);
    CLut_UV.w  = floor(colorIN.b);
    CLut_UV.xy = (colorIN.rg + 0.5) * CLut_pSize;
    CLut_UV.x += CLut_UV.w * CLut_pSize.y;
    CLut_UV.z  = CLut_UV.x + CLut_pSize.y;
    return       lerp(lutTexIn.SampleLevel(LinearSampler, CLut_UV.xy, 0).rgb,
                      lutTexIn.SampleLevel(LinearSampler, CLut_UV.zy, 0).rgb, colorIN.b - CLut_UV.w);
}

//function overload
float3 Lut(float3 colorIN, Texture2D lutTexIn)
{
    float2 lutsize;
    lutTexIn.GetDimensions(lutsize.x, lutsize.y);
    return Lut(colorIN, lutTexIn, lutsize);
}

float3 lutSwitch(float3 color)
{
    [branch] switch(selectedLut)
    {
        case 0:
            return lerp(color, lerp(lerp(Lut(color, lutTextureNight1), Lut(color, lutTextureDay1), ENightDayFactor), Lut(color, lutTextureInterior1), EInteriorFactor), LUTAmount);
        case 1:
            return lerp(color, lerp(lerp(Lut(color, lutTextureNight2), Lut(color, lutTextureDay2), ENightDayFactor), Lut(color, lutTextureInterior2), EInteriorFactor), LUTAmount);
        case 2:
            return lerp(color, lerp(lerp(Lut(color, lutTextureNight3), Lut(color, lutTextureDay3), ENightDayFactor), Lut(color, lutTextureInterior3), EInteriorFactor), LUTAmount);
        default:
            return color;
    }
}

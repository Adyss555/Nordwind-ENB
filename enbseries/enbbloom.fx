//==================== V7 =====================//
//      _      _        ___ _                  //
//     /_\  __| |_  _  | _ ) |___  ___ _ __    //
//    / _ \/ _` | || | | _ \ / _ \/ _ \ '  \   //
//   /_/ \_\__,_|\_, | |___/_\___/\___/_|_|_|  //
//               |__/                          //
//=============================================//
// Ady Bloom V7 beta by Adyss                  //
// Feel free to use with your own presets      //
//=============================================//

//=============================================//
// Textures                                    //
//=============================================//
Texture2D   TextureDepth;
Texture2D   TextureColor;
Texture2D   TextureDownsampled;  //color R16B16G16A16 64 bit or R11G11B10 32 bit hdr format. 1024*1024 size
Texture2D   RenderTarget1024;    //R16B16G16A16F 64 bit hdr format, 1024*1024 size
Texture2D   RenderTarget512;     //R16B16G16A16F 64 bit hdr format, 512*512 size
Texture2D   RenderTarget256;     //R16B16G16A16F 64 bit hdr format, 256*256 size
Texture2D   RenderTarget128;     //R16B16G16A16F 64 bit hdr format, 128*128 size
Texture2D   RenderTarget64;      //R16B16G16A16F 64 bit hdr format, 64*64 size
Texture2D   RenderTarget32;      //R16B16G16A16F 64 bit hdr format, 32*32 size
Texture2D   RenderTarget16;      //R16B16G16A16F 64 bit hdr format, 16*16 size

Texture2D   RenderTargetRGBA32;  // R8G8B8A8 32 bit ldr format
Texture2D   RenderTargetRGBA64;  // R16B16G16A16 64 bit ldr format
Texture2D   RenderTargetRGBA64F; // R16B16G16A16F 64 bit hdr format
Texture2D   RenderTargetR16F;    // R16F 16 bit hdr format with red channel only
Texture2D   RenderTargetR32F;    // R32F 32 bit hdr format with red channel only
Texture2D   RenderTargetRGB32F;  // 32 bit hdr format without alpha

Texture2D   lensDirt1           <string ResourceName="Include/Textures/lensdirt1.jpg"; >;
Texture2D   lensDirt2           <string ResourceName="Include/Textures/lensdirt2.jpg"; >;
Texture2D   lensDirt3           <string ResourceName="Include/Textures/lensdirt3.jpg"; >;

//=============================================//
// Internals                                   //
//=============================================//
#include "Include/Shared/Globals.fxh"
#include "Include/Shared/ReforgedUI.fxh"
#include "Include/Shared/Conversions.fxh"
#include "Include/Shared/BlendingModes.fxh"

//=============================================//
// UI                                          //
//=============================================//
UI_MESSAGE(1,                   "----- Masking -----")
UI_FLOAT(linearSlope,           " Linear Slope",            0.1, 5.0, 1.0)
UI_FLOAT(bloomSensitivity,      " Sensitivity",             0.1, 3.0, 1.0)
UI_FLOAT(threshold,             " Threshold",               0.0, 1.0, 0.1)
UI_FLOAT(softThreshold,         " Soft Threshold",          0.0, 1.0, 0.1)
UI_FLOAT(removeSky,             " Mask out Sky",            0.0, 1.0, 0.3)
UI_WHITESPACE(1)
UI_MESSAGE(2,                   "----- Color -----")
UI_FLOAT(bloomIntensity,        " Intensity",              -5.0, 5.0, 0.0)
UI_FLOAT(bloomSaturation,       " Saturation",              0.0, 3.0, 1.0)
UI_FLOAT3(bloomTint,            " Tint",                    1.0, 1.0, 1.0)
UI_BOOL(tonemapOutput,          " Tonemap output",	        false)
UI_WHITESPACE(2)
UI_MESSAGE(3,                   "----- Shape -----")
UI_INT(bloomSize,               " Samples",                 4.0, 32.0, 8.0)
UI_FLOAT(sigma,                 " Sigma",                   0.1, 5.0, 1.0)
UI_WHITESPACE(3)
UI_MESSAGE(5,                   "----- Adaptation -----")
UI_BOOL(enableAdaptation,       " Enable Adaptation",       false)
UI_INT(adaptationSamples,       "  Adaptation Samples",     2.0, 100.0, 8.0)
UI_FLOAT(adaptationImpact,      "  Adaptation Impact",      0.0, 100.0, 1.0)
UI_FLOAT(minAdaptation,         "  Min Adaptation",         0.0, 10.0, 0.0)
UI_FLOAT(maxAdaptation,         "  Max Adaptation",         0.0, 10.0, 1.0)
UI_WHITESPACE(5)
UI_MESSAGE(6,                   "----- Lens Dirt -----")
UI_BOOL(enableLensDirt,         " Enable Lens Dirt",	    false)
UI_INT(selectedDirt,            "  Select Dirt Texture",    0.0, 2.0, 0.0)
UI_FLOAT(dirtIntensity,         "  Dirt Intensity",         0.0, 2.0, 0.5)
UI_FLOAT(dirtSpread,            "  Dirt Spread",            0.3, 2.0, 1.0)
UI_FLOAT3(dirtTint,             "  Dirt Tint",              0.5, 0.5, 0.5)

//=============================================//
// Functions                                   //
//=============================================//

float2 getPixelSize(float texsize)
{
    return (1 / texsize) * float2(1, ScreenSize.z);
}

// Box Blur
float4 simpleBlur(Texture2D inputTex, float2 coord, float2 pixelsize)
{
    float4 Blur = 0.0;

    static const float2 Offsets[4]=
    {
        float2(0.5, 0.5),
        float2(0.5, -0.5),
        float2(-0.5, 0.5),
        float2(-0.5, -0.5)
    };

    for (int i = 0; i < 4; i++)
    {
        Blur += inputTex.Sample(LinearSampler, coord + Offsets[i] * pixelsize);
    }

    return Blur * 0.25;
}

// https://danielilett.com/2019-05-08-tut1-3-smo-blur/
static const float twoPi = 6.28319;
static const float E = 2.71828;

float gaussian(int x)
{
    float sigmaSquared = sigma * sigma * 2; // why 2x? it looks way to small otherwise
    return (1 / sqrt(twoPi * sigmaSquared)) * pow(E, -(x * x) / (2 * sigmaSquared));
}

// A second time for x and y
float gaussian(int x, int y)
{
    float sigmaSquared = sigma * sigma;
    return (1 / sqrt(twoPi * sigmaSquared)) * pow(E, -((x * x) + (y * y)) / (2 * sigmaSquared));
}

float3 singlePassGaussian(uniform Texture2D inputTex, float2 pixelSize, float2 uv)
{
    float3 color;
    int upper = (bloomSize - 1) * 0.5;
    int lower = -upper;
    float kernelSum = 0.0;
    for (int x = lower; x <= upper; ++x)
    {
        for (int y = lower; y <= upper; ++y)
        {
            float gauss = gaussian(x, y);
            kernelSum  += gauss;

            float2 offset = float2(pixelSize.x * x, pixelSize.y * y);
                   color += inputTex.Sample(LinearSampler, uv + offset) * gauss;
        }
    }
    return color / kernelSum;
}

//=============================================//
// Pixel Shaders                               //
//=============================================//

// Prepass inspired by https://catlikecoding.com/unity/tutorials/advanced-rendering/bloom/
float3	PS_Prepass(VS_OUTPUT IN, uniform Texture2D InputTex) : SV_Target
{
    float3  Color         = InputTex.Sample(LinearSampler, IN.txcoord.xy);
            Color         = (exp(Color * Color) - 1) / (linearSlope * Color);
            Color         = pow(Color, bloomSensitivity);
    float   Luma          = max3(Color);
    float   Knee          = threshold * softThreshold;
    float   Soft          = Luma - threshold + Knee;
            Soft          = clamp(Soft, 0, 2 * Knee);
            Soft          = Soft * Soft / (4 * Knee + 0.00001);
    float   Contribution  = max(Soft, Luma - threshold);
            Contribution /= max(Luma, 0.00001);
            Color        *= Contribution;
            Color         = lerp(GetLuma(Color, Rec709), Color, bloomSaturation);
            Color         = lerp(Color, Color * (1 - floor(getLinearizedDepth(IN.txcoord.xy))), removeSky);
    return saturate(Color * bloomTint);
}

float3  PS_Downsample(VS_OUTPUT IN, uniform Texture2D InputTex, uniform float texsize) : SV_Target
{
    return simpleBlur(InputTex, IN.txcoord.xy, getPixelSize(texsize));
}

float3  PS_Upsample(VS_OUTPUT IN, uniform Texture2D InputTex, uniform float texsize) : SV_Target
{
    return singlePassGaussian(InputTex, getPixelSize(texsize), IN.txcoord.xy);
}

// For mutipass blur
float3  PS_BlurH(VS_OUTPUT IN, uniform Texture2D InputTex, uniform float texsize) : SV_Target
{
    int     upper = (bloomSize - 1) * 0.5;
    int     lower = -upper;
    float2  pixelSize = getPixelSize(texsize);
    float   kernelSum = 0.0;
    float3 color;
    for (int x = lower; x <= upper; ++x)
    {
        float gauss = gaussian(x);
        kernelSum   += gauss;
        color       += InputTex.Sample(LinearSampler, IN.txcoord.xy + float2(pixelSize.x * x, 0.0)) * gauss;
    }
    return color / kernelSum;
}

float3  PS_BlurV(VS_OUTPUT IN, uniform Texture2D InputTex, uniform float texsize) : SV_Target
{
    int upper   = (bloomSize - 1) * 0.5;
    int lower   = -upper;
    float2 pixelSize = getPixelSize(texsize);
    float kernelSum  = 0.0;
    float3 color;
    for (int y = lower; y <= upper; ++y)
    {
        float gauss = gaussian(y);
        kernelSum += gauss;
        color += InputTex.Sample(LinearSampler, IN.txcoord.xy + float2(0.0, pixelSize.y * y)) * gauss;
    }
    return color / kernelSum;
}

float3  PS_BloomMix(VS_OUTPUT IN) : SV_Target
{
    float2 coord  = IN.txcoord.xy;
    float3 bloom  = 1;
           bloom  = simpleBlur(RenderTarget1024, coord, getPixelSize(1024)) * (1 - sqrt(bloom));
           bloom += simpleBlur(RenderTarget512,  coord, getPixelSize(512))  * (1 - sqrt(bloom));
           bloom += simpleBlur(RenderTarget256,  coord, getPixelSize(256))  * (1 - sqrt(bloom));
           bloom += simpleBlur(RenderTarget128,  coord, getPixelSize(128))  * (1 - sqrt(bloom));
           bloom += simpleBlur(RenderTarget64,   coord, getPixelSize(64))   * (1 - sqrt(bloom));
           bloom += simpleBlur(RenderTarget32,   coord, getPixelSize(32))   * (1 - sqrt(bloom));
           bloom += simpleBlur(RenderTarget16,   coord, getPixelSize(16))   * (1 - sqrt(bloom)); 
    return bloom; // Normalize  1/7 = 0.1428571428571429
}

float	PS_CalcAvgLuma(VS_OUTPUT IN) : SV_Target
{
    if (!enableAdaptation) return 0;

    float Luma = 0;
    for (int x = 0; x < adaptationSamples; x++)
    {
        for (int y = 0; y < adaptationSamples; y++)

        {
            Luma += TextureColor.Sample(LinearSampler, float2(x, y) / adaptationSamples);
        }
    }
    return Luma /= adaptationSamples * adaptationSamples;
}

float3  PS_Postpass(VS_OUTPUT IN) : SV_Target
{
    float2 coord    = IN.txcoord.xy;
    float3 color    = TextureColor.Sample(LinearSampler, coord);
    float  avgLuma  = RenderTargetRGBA32.Load(int3(0, 0, 0));
           avgLuma  = clamp(avgLuma, minAdaptation, maxAdaptation);

           color   *= exp2(bloomIntensity - (avgLuma * adaptationImpact));

    if (tonemapOutput)
    color = 1 - exp(-color);

    float3 dirtMask = pow(color * dirtIntensity * dirtTint, dirtSpread);
    float3 dirtTex  = 0.0;

    if(selectedDirt == 0)
    dirtTex = lensDirt1.Sample(LinearSampler, coord);

    if(selectedDirt == 1)
    dirtTex = lensDirt2.Sample(LinearSampler, coord);

    if(selectedDirt == 2)
    dirtTex = lensDirt3.Sample(LinearSampler, coord);

    if(enableLensDirt)
    color = BlendScreenHDR(color, dirtTex * dirtMask);

    return saturate(color);
}

//=============================================//
// Techniques                                  //
//=============================================//

technique11 Blum <string UIName="Progressive Bloom(Wide)"; string RenderTarget="RenderTarget1024";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Prepass(TextureDownsampled))); } }

technique11 Blum1 <string RenderTarget="RenderTarget512";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget1024, 1024.0))); } }

technique11 Blum2 <string RenderTarget="RenderTarget256";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget512, 512.0))); } }

technique11 Blum3 <string RenderTarget="RenderTarget128";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget256, 256.0))); } }

technique11 Blum4 <string RenderTarget="RenderTarget64";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget128, 128.0))); } }

technique11 Blum5 <string RenderTarget="RenderTarget32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget64, 64.0))); } }

technique11 Blum6 <string RenderTarget="RenderTarget16";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget32, 32.0))); } }

// Up from here
technique11 Blum7 <string RenderTarget="RenderTarget32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget16, 16.0))); } }

technique11 Blum8 <string RenderTarget="RenderTarget64";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget32, 32.0))); } }

technique11 Blum9 <string RenderTarget="RenderTarget128";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget64, 64.0))); } }

technique11 Blum10 <string RenderTarget="RenderTarget256";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget128, 128.0))); } }

technique11 Blum11 <string RenderTarget="RenderTarget512";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget256, 256.0))); } }

technique11 Blum12 <string RenderTarget="RenderTarget1024";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget512, 512.0))); } }

technique11 Blum13
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget1024, 1024.0))); } }

technique11 Blum14 <string RenderTarget="RenderTargetRGBA32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_CalcAvgLuma())); } }

technique11 Blum15
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Postpass())); } }

// Middle Mode
technique11 middle <string UIName="Progressive Bloom(Tight)"; string RenderTarget="RenderTarget512";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Prepass(TextureDownsampled))); } }

technique11 middle1 <string RenderTarget="RenderTarget256";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget512, 512.0))); } }

technique11 middle2 <string RenderTarget="RenderTarget128";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget256, 256.0))); } }

technique11 middle3 <string RenderTarget="RenderTarget64";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget128, 128.0))); } }

technique11 middle4 <string RenderTarget="RenderTarget32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget64, 64.0))); } }

// Up from here
technique11 middle5 <string RenderTarget="RenderTarget64";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget32, 32.0))); } }

technique11 middle6 <string RenderTarget="RenderTarget128";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget64, 64.0))); } }

technique11 middle7 <string RenderTarget="RenderTarget256";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget128, 128.0))); } }

technique11 middle8 <string RenderTarget="RenderTarget512";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget256, 256.0))); } }

technique11 middle9 <string RenderTarget="RenderTarget1024";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget512, 512.0))); } }

technique11 middle10
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget1024, 1024.0))); } }

technique11 middle11 <string RenderTarget="RenderTargetRGBA32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_CalcAvgLuma())); } }

technique11 middle12
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Postpass())); } }

// Small Mode
technique11 smol <string UIName="Progressive Bloom(Dense)"; string RenderTarget="RenderTarget512";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Prepass(TextureDownsampled))); } }

technique11 smol1 <string RenderTarget="RenderTarget256";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget512, 512.0))); } }

technique11 smol2 <string RenderTarget="RenderTarget128";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget256, 256.0))); } }

technique11 smol3 <string RenderTarget="RenderTarget64";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget128, 128.0))); } }

technique11 smol4 <string RenderTarget="RenderTarget32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget64, 64.0))); } }

technique11 smol5 <string RenderTarget="RenderTarget16";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Downsample(RenderTarget32, 32.0))); } }

// Up from here
technique11 smol6 <string RenderTarget="RenderTarget64";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget16, 16.0))); } }

technique11 smol7 <string RenderTarget="RenderTarget256";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget64, 64.0))); } }

technique11 smol8 <string RenderTarget="RenderTarget1024";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget256, 256.0))); } }

technique11 smol9
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Upsample(RenderTarget1024, 1024.0))); } }

technique11 smol10 <string RenderTarget="RenderTargetRGBA32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_CalcAvgLuma())); } }

technique11 smol11
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Postpass())); } }

// the "normal" way
technique11 normal <string UIName="Traditional Bloom"; string RenderTarget="RenderTarget1024";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Prepass(TextureDownsampled))); } }

technique11 normal1
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurH(RenderTarget1024, 1024.0))); } }

technique11 normal2 <string RenderTarget="RenderTarget1024";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurV(TextureColor, 1024.0))); } }

technique11 normal3
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurH(RenderTarget1024, 512.0))); } }

technique11 normal4 <string RenderTarget="RenderTarget512";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurV(TextureColor, 512.0))); } }

technique11 normal5
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurH(RenderTarget512, 256.0))); } }

technique11 normal6 <string RenderTarget="RenderTarget256";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurV(TextureColor, 256.0))); } }

technique11 normal7
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurH(RenderTarget256, 128.0))); } }

technique11 normal8 <string RenderTarget="RenderTarget128";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurV(TextureColor, 128.0))); } }

technique11 normal9
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurH(RenderTarget128, 64.0))); } }

technique11 normal10 <string RenderTarget="RenderTarget64";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurV(TextureColor, 64.0))); } }

technique11 normal11
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurH(RenderTarget64, 32.0))); } }

technique11 normal12 <string RenderTarget="RenderTarget32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurV(TextureColor, 32.0))); } }

technique11 normal13
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurH(RenderTarget32, 16.0))); } }

technique11 normal14 <string RenderTarget="RenderTarget16";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BlurV(TextureColor, 16.0))); } }

technique11 normal15
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_BloomMix())); } }

technique11 normal16 <string RenderTarget="RenderTargetRGBA32";>
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_CalcAvgLuma())); } }

technique11 normal17
{ pass p0 { SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
            SetPixelShader (CompileShader(ps_5_0, PS_Postpass())); } }

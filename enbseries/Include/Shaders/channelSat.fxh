/*
    Description : PD80 04 Contrast Brightness Saturation for Reshade https://reshade.me/
    Author      : prod80 (Bas Veth)
    License     : MIT, Copyright (c) 2020 prod80


    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

float curve( float x )
{
    return x * x * ( 3.0 - 2.0 * x );
}

float3 channelsat( float3 col, float r, float y, float g, float a, float b, float p, float m, float hue )
{
    float desat        = GetLuma(col.xyz, Rec709);

    // Red          : 0.0
    // Orange       : 0.083
    // Yellow       : 0.167
    // Green        : 0.333
    // Cyan/Aqua    : 0.5
    // Blue         : 0.667
    // Purple       : 0.75
    // Magenta      : 0.833

    float weight_r     = curve( max( 1.0f - abs(  hue               * 6.0f ), 0.0f )) +
                         curve( max( 1.0f - abs(( hue - 1.0f      ) * 6.0f ), 0.0f ));
    float weight_y     = curve( max( 1.0f - abs(( hue - 0.166667f ) * 6.0f ), 0.0f ));
    float weight_g     = curve( max( 1.0f - abs(( hue - 0.333333f ) * 6.0f ), 0.0f ));
    float weight_a     = curve( max( 1.0f - abs(( hue - 0.5f      ) * 6.0f ), 0.0f ));
    float weight_b     = curve( max( 1.0f - abs(( hue - 0.666667f ) * 6.0f ), 0.0f ));
    float weight_p     = curve( max( 1.0f - abs(( hue - 0.75f     ) * 6.0f ), 0.0f ));
    float weight_m     = curve( max( 1.0f - abs(( hue - 0.833333f ) * 6.0f ), 0.0f ));

    col.xyz            = lerp( desat, col.xyz, clamp( 1.0f + r * weight_r, 0.0f, 2.0f ));
    col.xyz            = lerp( desat, col.xyz, clamp( 1.0f + y * weight_y, 0.0f, 2.0f ));
    col.xyz            = lerp( desat, col.xyz, clamp( 1.0f + g * weight_g, 0.0f, 2.0f ));
    col.xyz            = lerp( desat, col.xyz, clamp( 1.0f + a * weight_a, 0.0f, 2.0f ));
    col.xyz            = lerp( desat, col.xyz, clamp( 1.0f + b * weight_b, 0.0f, 2.0f ));
    col.xyz            = lerp( desat, col.xyz, clamp( 1.0f + p * weight_p, 0.0f, 2.0f ));
    col.xyz            = lerp( desat, col.xyz, clamp( 1.0f + m * weight_m, 0.0f, 2.0f ));

    return saturate(col.xyz);
}

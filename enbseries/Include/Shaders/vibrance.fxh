/**
 * Vibrance
 * by Christian Cann Schuldt Jensen ~ CeeJay.dk
 *
 * Vibrance intelligently boosts the saturation of pixels so pixels that had little color get a larger boost than pixels that had a lot.
 * This avoids oversaturation of pixels that were already very saturated.
 */

float3 Vibrance(float3 color)
{
	float luma = GetLuma(color, Rec709);

	float max_color = max(color.r, max(color.g, color.b)); // Find the strongest color
	float min_color = min(color.r, min(color.g, color.b)); // Find the weakest color

	float color_saturation = max_color - min_color; // The difference between the two is the saturation

    float3 coeffVibrance = float3(vibranceRGBBalance * vibrance);
	color = lerp(luma, color, 1.0 + (coeffVibrance * (1.0 - (sign(coeffVibrance) * color_saturation))));

    return color;
}

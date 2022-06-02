//==========================================//
// Letterbox shader by Adyss                //
// Features: rotation, pillarboxes,         //
// depthawareness and customizable color    //
// Feel free to use this in your own presets//
//==========================================//
// the Color.a portion is to create a mask of where the letterboxes are in alpha channel. This is used for underwater shaders wich usually just draw over Letterboxes

float4 applyLetterbox(float4 Color, float Depth, float2 coord)
{
			 Color.a 		= 1.0; // Underwater Shader workaround
	float 	 rotSin 		= sin(BoxRotation);
	float	 rotCos 		= cos(BoxRotation);
	float2x2 rotationMatrix = float2x2(rotCos, -rotSin, rotSin, rotCos);
			 rotationMatrix *= 0.5; // Matrix Correction to fix on center point
			 rotationMatrix += 0.5;
			 rotationMatrix = rotationMatrix * 2 - 1;
	float2	 rotationCoord  = mul(coord - 0.5, rotationMatrix);
			 rotationCoord += 0.5;

	if(Depth > LetterboxDepth * 0.01)
	{
		if(rotationCoord.x > 1.0 - vBoxSize || rotationCoord.y < hBoxSize)
		{
			Color = float4(BoxColor, 0);
		}
		if (rotationCoord.y > 1.0 - hBoxSize || rotationCoord.x < vBoxSize)
		{
			Color = float4(BoxColor, 0);
		}
	}
	return Color;
}

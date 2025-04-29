#include "common.slh"
#include "blending.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D tex;

[material][a] property float2 maxUV;
[material][a] property float2 pixelSize;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	const float2 gWeightsOffsets[9];
	gWeightsOffsets[0] = float2(0.10855, 0.66293);
	gWeightsOffsets[1] = float2(0.13135, 2.47904);
	gWeightsOffsets[2] = float2(0.10406, 4.46232);
	gWeightsOffsets[3] = float2(0.07216, 6.44568);
	gWeightsOffsets[4] = float2(0.04380, 8.42917);
	gWeightsOffsets[5] = float2(0.02328, 10.41281);
	gWeightsOffsets[6] = float2(0.01083, 12.39664);
	gWeightsOffsets[7] = float2(0.00441, 14.38072);
	gWeightsOffsets[8] = float2(0.00157, 16.36501);

	float2 blurColor = const0List2;

	#ifdef VBLUR
		float2 pixelOffset = float2(pixelSize.x, 0.0);
	#else
		float2 pixelOffset = float2(0.0, pixelSize.y);
	#endif

	[unroll]
	for (int i = 0; i < 9; i++)
	{
		float2 offset = pixelOffset * gWeightsOffsets[i].y;
		blurColor += tex2D(tex, clamp(input.texCoord + offset, const0List2, maxUV)).xyz * gWeightsOffsets[i].x;
		blurColor += tex2D(tex, clamp(input.texCoord - offset, const0List2, maxUV)).xyz * gWeightsOffsets[i].x;
	}

	#ifdef USE_RED_TEXTURE_CHANNEL
		output.color = float4(blurColor.r, const1List3);
	#else
		output.color = float4(blurColor.g, const1List3);
	#endif

	return output;
}

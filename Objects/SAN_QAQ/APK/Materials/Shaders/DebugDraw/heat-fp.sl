#include "common.slh"

#ensuredefined VIEW_MODE_FLIP_UV_HACK 0
#ensuredefined VIEW_MODE_OVERDRAW_COUNT_ALPHABLEND 0
#ensuredefined VIEW_MODE_OVERDRAW_COUNT_ALPHATEST 0

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D image;
uniform sampler2D heatColorLUT;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 texCoord = input.texCoord;
	float heatTerm = 0.0;

	#if VIEW_MODE_FLIP_UV_HACK
		texCoord = 1.0 - texCoord;
	#endif

	float3 colorSample = tex2D(image, texCoord).rgb;

	#if VIEW_MODE_OVERDRAW_COUNT_ALPHABLEND
		heatTerm += colorSample.r;
	#endif

	#if VIEW_MODE_OVERDRAW_COUNT_ALPHATEST
		heatTerm += colorSample.g;
	#endif

	output.color = tex2D(heatColorLUT, float2(heatTerm, 0.0));

	return output;
}

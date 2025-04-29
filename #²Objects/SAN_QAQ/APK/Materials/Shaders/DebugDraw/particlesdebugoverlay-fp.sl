#include "common.slh"
#include "blending.slh"

#ensuredefined HEATMAP 0

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if HEATMAP
	uniform sampler2D heatColorLUT;
#else
	uniform sampler2D particlesRT;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#if HEATMAP
		output.color = tex2D(heatColorLUT, float2(output.color.r, 0.0));
	#else
		output.color = tex2D(particlesRT, input.texCoord);
	#endif

	return output;
}

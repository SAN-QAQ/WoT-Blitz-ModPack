#include "common.slh"
#include "blending.slh"

#if COLORBLIND_MODE
	#include "colorblind-mode.slh"
#endif

fragment_in
{
	float2 texCoord : TEXCOORD0;
	float4 color : COLOR0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D tex;

[material][instance] property float smoothing;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = float4(input.color.rgb, min(smoothstep(0.5 - smoothing, 0.5 + smoothing, tex2D(tex, input.texCoord).a), input.color.a));

	#if COLORBLIND_MODE
		output.color.rgb = getColorBlind(output.color.rgb);
	#endif

	return output;
}

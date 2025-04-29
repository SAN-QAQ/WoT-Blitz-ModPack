#include "common.slh"
#include "blending.slh"

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

[material][a] property float2 maxUV;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = tex2D(tex, clamp(input.texCoord, const0List2, maxUV)) * input.color;

	return output;
}
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

[material][a] property float saturation;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = tex2D(tex, input.texCoord) * input.color;

	float lum = dot(output.color.rgb, lumCof);
	output.color.rgb = lerp(float3(lum, lum, lum), output.color.rgb, saturation);

	return output;
}
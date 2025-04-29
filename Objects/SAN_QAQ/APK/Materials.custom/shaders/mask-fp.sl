#include "blending.slh"

blending { src=dst_color dst=zero }

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

	float alpha = tex2D(tex, input.texCoord).a;

	output.color = float4(input.color.rgb, input.color.a * lerp(alpha, 1.0, step(0.0, alpha)));

	return output;
}
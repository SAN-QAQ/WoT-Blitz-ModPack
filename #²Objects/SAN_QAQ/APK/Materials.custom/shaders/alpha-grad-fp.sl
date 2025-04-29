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

[material][a] property float maxU;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float4 color = tex2D(tex, input.texCoord);
	float sVal = saturate(abs(-input.texCoord.x * 2.0 + maxU));
	output.color = float4(color.rgb, (color.a + sVal - abs(color.a - sVal)) * 0.5) * input.color;

	return output;
}

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

[material][a] property float2 pixelSize;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = float4(((tex2D(tex, input.texCoord + pixelSize).rgb + tex2D(tex, input.texCoord - pixelSize).rgb) + (tex2D(tex, input.texCoord + float2(pixelSize.x, -pixelSize.y)).rgb + tex2D(tex, input.texCoord + float2(-pixelSize.x, pixelSize.y)).rgb)) * 0.25, 1.0) * input.color;

	return output;
}
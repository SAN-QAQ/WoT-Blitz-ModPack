#include "common.slh"

#ensuredefined TEXTURED 0

vertex_in
{
	float4 localPos : POSITION;

	#if TEXTURED
		float2 texCoord : TEXCOORD0;
	#endif

	float4 color : COLOR0;
};

vertex_out
{
	float4 localPos : SV_POSITION;

	#if TEXTURED
		float2 texCoord : TEXCOORD0;
	#endif

	float4 color : COLOR0;
};

[auto][instance] property float4x4 worldViewProjMatrix;

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	output.localPos = mul4Fast1(input.localPos.xyz, worldViewProjMatrix);

	#if TEXTURED
		output.texCoord = input.texCoord;
	#endif

	output.color = input.color;

	return output;
}

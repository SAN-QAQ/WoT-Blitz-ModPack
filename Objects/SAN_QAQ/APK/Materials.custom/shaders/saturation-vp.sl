#include "common.slh"

vertex_in
{
	float4 localPos : POSITION;
	float2 texCoord : TEXCOORD0;
	float4 color : COLOR0;
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float2 texCoord : TEXCOORD0;
	float4 color : COLOR0;
};

[auto][instance] property float4x4 worldViewProjMatrix;

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	output.localPos = mul4Fast1(input.localPos.xyz, worldViewProjMatrix);
	output.texCoord = input.texCoord;
	output.color = input.color;

	return output;
}

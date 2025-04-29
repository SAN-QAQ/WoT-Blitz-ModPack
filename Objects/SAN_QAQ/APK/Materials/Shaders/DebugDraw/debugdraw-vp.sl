#include "common.slh"

vertex_in
{
	float4 localPos : POSITION;
};

vertex_out
{
	float4 localPos : SV_POSITION;
};

[auto][a] property float4x4 worldViewProjMatrix;

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	output.localPos = mul4Fast1(input.localPos.xyz, worldViewProjMatrix);

	return output;
}

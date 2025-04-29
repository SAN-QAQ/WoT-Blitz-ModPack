#include "common.slh"

vertex_in
{
	[vertex] float4 localPos : POSITION;
	[instance] float4 worldMatrix0 : TEXCOORD0;
	[instance] float4 worldMatrix1 : TEXCOORD1;
	[instance] float4 worldMatrix2 : TEXCOORD2;
	[instance] float4 invWorldMatrix0 : TEXCOORD3;
	[instance] float4 invWorldMatrix1 : TEXCOORD4;
	[instance] float4 invWorldMatrix2 : TEXCOORD5;
	[instance] float4 instanceOpacity : TEXCOORD6;
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;
	float4 invWorldMatrix0 : TEXCOORD0;
	float4 invWorldMatrix1 : TEXCOORD1;
	float4 invWorldMatrix2 : TEXCOORD2;
	float4 instanceOpacity : TEXCOORD3;
};

[auto][a] property float farFadeDistance;
[auto][a] property float nearFadeDistance;
[auto][a] property float3 cameraPosition;
[auto][a] property float4x4 viewProjMatrix;

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	float3 camPos = cameraPosition;
	float3 worldPos = mul3Fast1(input.localPos.xyz, vecToMat(input.worldMatrix0, input.worldMatrix1, input.worldMatrix2));
	output.localPos = mul4Fast1(worldPos, viewProjMatrix);
	output.projPos = output.localPos;
	output.invWorldMatrix0 = input.invWorldMatrix0;
	output.invWorldMatrix1 = input.invWorldMatrix1;
	output.invWorldMatrix2 = input.invWorldMatrix2;
	output.instanceOpacity = -input.instanceOpacity * (clamp(length(camPos - worldPos), nearFadeDistance, farFadeDistance) - nearFadeDistance) * (1.0 / max(farFadeDistance - nearFadeDistance, 0.0001)) + input.instanceOpacity;

	return output;
}
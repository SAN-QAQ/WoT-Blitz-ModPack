#include "common.slh"

vertex_in
{
	float4 localPos : POSITION;
	float2 texCoord : TEXCOORD0;
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float2 texCoord : TEXCOORD0;

	#if FLOWMAP
		float3 flowData : TEXCOORD1; // For flowmap animations - xy next frame uv. z - frame time
	#endif
};

[auto][a] property float4x4 worldViewProjMatrix;

#if FLOWMAP
	[auto][a] property float globalTime;

	[material][a] property float flowAnimSpeed = 0.0;
	[material][a] property float flowAnimOffset = 0.0;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	output.localPos = mul4Fast0(input.localPos.xyz, worldViewProjMatrix);
	output.localPos.z = output.localPos.w - 0.0001;

	#if FORCE_2D_MODE
		output.localPos.z = 0.0;
	#endif

	output.texCoord = input.texCoord;

	#include "flowmap-vec.slh"

	return output;
}

#include "common.slh"
#include "materials-vertex-properties.slh"

vertex_in
{
	float4 localPos : POSITION;
	float3 normal : NORMAL;

	#if HARD_SKINNING
		float index : BLENDINDICES;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;
};

[auto][a] property float4x4 projMatrix;
[auto][a] property float4x4 worldViewInvTransposeMatrix;
[auto][a] property float4x4 worldViewMatrix;

[material][a] property float silhouetteExponent = 0.0;
[material][a] property float silhouetteScale = 1.0;

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#if HARD_SKINNING
		float3 localPos = hardSkinnedPosition(input.localPos.xyz, input.index);
		float4 jQ = jointQuaternions[int(input.index)];
		float3 tmp = cross(jQ.xyz, input.normal) * 2.0;
		float3 normal = tmp * jQ.w + (input.normal + cross(jQ.xyz, tmp));
	#else
		float3 localPos = input.localPos.xyz;
		float3 normal = input.normal;
	#endif

	float3 eyePos = mul3Fast1(localPos, worldViewMatrix);
	output.localPos = mul4Fast1(pow(float3(0.01, 0.01, 0.01) * (silhouetteScale * length(eyePos)), silhouetteExponent) * normalize(mul3Fast0(normal, worldViewInvTransposeMatrix)) + eyePos, projMatrix);

	return output;
}

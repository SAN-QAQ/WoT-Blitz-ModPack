#include "common.slh"
#include "ibl.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform samplerCUBE cubemap;

[auto][a] property float renderTargetId;
[auto][a] property float2 mipmapLevel; // x - current, y - total

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#include "cubemap-faces.slh"

	int face = int(renderTargetId);

	float linearRoughness = -(mipmapLevel.x + mipmapLevel.y) * 0.833333 + 2.5;
	float width = float(1 << int(mipmapLevel.y));
	float totalWeight = 0.0;
	float3 N = normalize(faceNormals[face] + (input.texCoord.x * faceUs[face] + ((input.texCoord.x * faceUs[face] - faceUs[face])) + (input.texCoord.y * faceVs[face] + (input.texCoord.y * faceVs[face] - faceVs[face]))));
	float3 LD = const0List3;

	for (int i = 0; i < 1024; i++)
	{
		float2 Y = D_Hammersley(i, 1024.0);
		float3 H = I_GGX(Y, linearRoughness, N);
		float3 L = reflect(-N, H);

		float NdotL = saturate(dot(N, L));
		float NdotH = saturate(dot(N, H));

		float P = D_GGX(NdotH, linearRoughness) * 0.25 + 0.0001;
		float SA = width * width * (1.0 / ((P * 256.0 + 0.000025) * _PI_06));

		totalWeight += NdotL;
		LD += texCUBElod(cubemap, L, lerp(log2(SA) * 0.5, 0.0, float(linearRoughness == 0.0))).rgb * NdotL;
	}

	output.color = float4(LD * (1.0 / totalWeight), 1.0);

	return output;
}

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

	float totalWeight = 0.0;
	float linearRoughness = -(mipmapLevel.x + mipmapLevel.y) * 0.833333 + 2.5;
	float width = float(1 << int(mipmapLevel.y));
	float3 N = normalize(faceNormals[face] + (input.texCoord.x * faceUs[face] + ((input.texCoord.x * faceUs[face] - faceUs[face])) + (input.texCoord.y * faceVs[face] + (input.texCoord.y * faceVs[face] - faceVs[face]))));
	float3 landscapeDiffuse = const0List3;

	for (int i = 0; i < 1024; i++)
	{
		float3 H = I_GGX(D_Hammersley(i, 1024.0), linearRoughness, N);
		float3 L = reflect(-N, H);

		float NdotL = saturate(dot(N, L));
		float NdotH = saturate(dot(N, H));

		totalWeight += NdotL;
		landscapeDiffuse += texCUBElod(cubemap, L, lerp(log2(1.0 / (D_GGX(NdotH, linearRoughness) * 1206.371578978480604 + 0.48301987048943071)) * 0.5 + log2(width), 0.0, float(linearRoughness == 0.0))).rgb * NdotL;
	}

	output.color = float4(landscapeDiffuse * (1.0 / totalWeight), 1.0);

	return output;
}

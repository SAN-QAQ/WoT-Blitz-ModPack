#include "common.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

[auto][a] property float convertSRGBToLinear;
[auto][a] property float gamma;
[auto][a] property float groundFactor;
[auto][a] property float multiplier;
[auto][a] property float renderTargetId;

uniform samplerCUBE cubemap;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#include "cubemap-faces.slh"

	int face = int(renderTargetId);
	float3 normal = normalize(faceNormals[face] + (input.texCoord.x * faceUs[face] + (input.texCoord.x * faceUs[face] - faceUs[face] + (input.texCoord.y * faceVs[face] + (input.texCoord.y * faceVs[face] - faceVs[face]))));

	output.color.rgb = texCUBE(cubemap, normal).rgb;
	output.color.rgb = lerp(output.color.rgb, toLinear(output.color.rgb), step(0.0, convertSRGBToLinear));
	output.color = float4(pow(output.color.rgb, gamma) * multiplier * saturate(normal.z + groundFactor + groundFactor), 1.0);

	return output;
}

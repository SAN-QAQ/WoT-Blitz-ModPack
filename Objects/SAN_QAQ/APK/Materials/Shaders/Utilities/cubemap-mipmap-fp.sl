fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

[auto][a] property float renderTargetId;

uniform samplerCUBE cubemap;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#include "cubemap-faces.slh"

	int face = int(renderTargetId);

	output.color = float4(texCUBE(cubemap, normalize(faceNormals[face] + (input.texCoord.x * faceUs[face] + (input.texCoord.x * faceUs[face] - faceUs[face] + (input.texCoord.y * faceVs[face] + (input.texCoord.y * faceVs[face] - faceVs[face])))))).rgb, 1.0);

	return output;
}

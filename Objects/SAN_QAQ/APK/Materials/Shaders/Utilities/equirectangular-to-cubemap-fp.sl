#include "common.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D envmap;

[auto][a] property float renderTargetId;

float2 envMapTexCoord(float3 v)
{
	return float2(atan2(v.y, -v.x), asin(-v.z)) * float2(0.1591, 0.3183) + const05List2;
}

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#include "cubemap-faces.slh"

	int face = int(renderTargetId);

	float2 envMapTexCoord = envMapTexCoord(normalize(faceNormals[face] + (input.texCoord.x * faceUs[face] + ((input.texCoord.x * faceUs[face] - faceUs[face])) + (input.texCoord.y * faceVs[face] + (input.texCoord.y * faceVs[face] - faceVs[face])))));

	output.color = float4(tex2D(envmap, envMapTexCoord).rgb, 1.0);
	output.color.rgb = toSRGB(output.color.rgb);

	return output;
}

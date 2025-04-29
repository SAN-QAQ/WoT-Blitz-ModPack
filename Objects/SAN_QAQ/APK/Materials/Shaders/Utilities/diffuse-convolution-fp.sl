#include "common.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform samplerCUBE cubemap;

[auto][a] property float envMapSize;
[auto][a] property float renderTargetId;

float texelSolidAngle(float3 uvNInvSize)
{
	float x0 = uvNInvSize.x - uvNInvSize.z;
	float x1 = uvNInvSize.x + uvNInvSize.z;
	float y0 = uvNInvSize.y - uvNInvSize.z;
	float y1 = uvNInvSize.y + uvNInvSize.z;
	float x00sq = x0 * x0;
	float x11sq = x1 * x1;
	float y00sq = y0 * y0;
	float y11sq = y1 * y1;

	return atan2(x0 * y0, sqrt(x00sq + y00sq + 1.0)) - atan2(x0 * y1, sqrt(x00sq + y11sq + 1.0)) - atan2(x1 * y0, sqrt(x11sq + y00sq + 1.0)) + atan2(x1 * y1, sqrt(x11sq + y11sq + 1.0));
}

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#include "cubemap-faces.slh"

	float size = min(envMapSize, 64.0);
	float invSize = 1.0 / size;
	int face = int(renderTargetId);

	float3 normal = normalize(faceNormals[face] + (input.texCoord.x * faceUs[face] + (input.texCoord.x * faceUs[face] - faceUs[face] + (input.texCoord.y * faceVs[face] + (input.texCoord.y * faceVs[face] - faceVs[face]))));

	float3 irradiance = const0List3;

	for (int f = 0; f < 6; f++)
	{
		float3 faceNormal = faceNormals[f];
		float3 faceU = faceUs[f];
		float3 faceV = faceVs[f];

		for (int i = 0; i < size; i++)
		{
			float u = invSize * i + (invSize * i + (invSize - 1.0));

			for (int j = 0; j < size; j++)
			{
				float v = invSize * j + (invSize * j + (invSize - 1.0));

				float3 direction = normalize(u * faceU + (v * faceV + faceNormal));
				float3 uvNInvSize = float3(u, v, invSize);
				float cs = saturate(dot(direction, normal));
				float solidAngle = texelSolidAngle(uvNInvSize);

				float3 cubeSample = texCUBElod(cubemap, direction, log2(envMapSize) - log2(size)).rgb;
				irradiance += toLinear(cubeSample) * (cs * solidAngle);
			}
		}
	}

	output.color = float4(irradiance * _INVERSE_PI, 1.0);

	return output;
}

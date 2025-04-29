#include "common.slh"
#include "blending.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D tex;

[material][a] property float radius;
[material][a] property float2 maxUV;
[material][a] property float2 pixelSize;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 accumulationCount = const0List2;

	for (float x = 0.0; x <= radius; x += 0.5)
	{
		for (float y = 0.0; y <= radius; y += 0.5)
		{
			if (x == 0.0 && y == 0.0)
			{
				accumulationCount.x += tex2D(tex, input.texCoord).w;
				accumulationCount.y += 1.0;
			}
			else
			{
				accumulationCount.x += tex2D(tex, clamp(float2(x, y) * pixelSize + input.texCoord, const0List2, maxUV)).w + tex2D(tex, clamp(float2(x, -y) * pixelSize + input.texCoord, const0List2, maxUV)).w + tex2D(tex, clamp(float2(-x, y) * pixelSize + input.texCoord, const0List2, maxUV)).w + tex2D(tex, clamp(float2(-x, -y) * pixelSize + input.texCoord, const0List2, maxUV)).w;
				accumulationCount.y += 4.0;
			}
		}
	}

	output.color = float4(accumulationCount.x * (1.0 / accumulationCount.y), const1List3);

	return output;
}
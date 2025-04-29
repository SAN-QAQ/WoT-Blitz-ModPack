#include "common.slh"
#include "blending.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;

	#if FLOWMAP
		float3 flowData : TEXCOORD1; // For flowmap animations - xy next frame uv. z - frame time
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D albedo;

#if FLOWMAP
	uniform sampler2D flowmap;
#endif

#if FLATCOLOR
	[material][a] property float4 flatColor = const1List4;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#if FLOWMAP
		float2 flowDir = tex2D(flowmap, input.texCoord).xy * 2.0 - const1List2;

		output.color = lerp(tex2D(albedo, flowDir * input.flowData.x + input.texCoord), tex2D(albedo, flowDir * input.flowData.y + input.texCoord), input.flowData.z);
	#else
		output.color = tex2D(albedo, input.texCoord);
	#endif

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	output.color.rgb = toLinear(output.color.rgb);

	#include "color-grading.slh"

	return output;
}

#include "depth-fetch.slh"

blending0 { src=src_alpha dst=inv_src_alpha }
blending1 { src=src_alpha dst=inv_src_alpha }
color_mask0 = rgb;
color_mask1 = rgb;

fragment_in
{
	float4 projPos : POSITION0;
	float4 invWorldMatrix0 : TEXCOORD0;
	float4 invWorldMatrix1 : TEXCOORD1;
	float4 invWorldMatrix2 : TEXCOORD2;
	float4 instanceOpacity : TEXCOORD3;
};

fragment_out
{
	float4 gbuffer0 : SV_TARGET0;
	float4 gbuffer1 : SV_TARGET1;
};

uniform sampler2D albedo;

[auto][a] property float4x4 invViewMatrix;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 projPos = input.projPos.xy * (1.0 / input.projPos.w);

	#include "deferred-pos.slh"

	float4 albedoSample = tex2D(albedo, localPos.xy + const05List2);
	albedoSample.a *= input.instanceOpacity.x * dot(step(abs(localPos), const05List3), const1List3);

	output.gbuffer0 = albedoSample;
	output.gbuffer1 = albedoSample;

	return output;
}
#include "common.slh"
#include "blending.slh"

#ensuredefined SIMPLE_COLOR_RECEIVED_SHADOW_ONLY 0

#define SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED (SIMPLE_COLOR_RECEIVED_SHADOW_ONLY && USE_SHADOW_MAP)

#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
	#include "shadow-mapping.slh"
#endif

fragment_in
{
	#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
		float4 projPos : POSITION0;
		float3 worldPos : POSITION1;
		float4 vertexColor : COLOR0;
		float4 worldNormalNdotL : TEXCOORD0;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if FLATCOLOR
	[material][a] property float4 flatColor = const1List4;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = input.vertexColor;

	#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY
		#if USE_SHADOW_MAP
			float2 projPos = input.projPos.xy * (1.0 / input.projPos.w);
			float3 shadowInf = getShadow(input.worldNormalNdotL.xyz * (shadowNormalSlopeOffset * input.worldNormalNdotL.w) + input.worldPos, projPos, input.worldNormalNdotL.w);
			output.color = float4(shadowMapShadowColor.rgb, 1.0 - shadowInf.x);

			#if FLATCOLOR
				output.color *= flatColor;
			#endif
		#else
			output.color.a = 0.0;
		#endif
	#endif

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	return output;
}

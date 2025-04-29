#include "common.slh"
#include "materials-vertex-properties.slh"
#include "vp-fog-props.slh"

#ensuredefined NEED_CHAIN_TEXCOORD_OFFSETS 0
#ensuredefined SIMPLE_COLOR_RECEIVED_SHADOW_ONLY 0

#define SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED (SIMPLE_COLOR_RECEIVED_SHADOW_ONLY && USE_SHADOW_MAP)

#if INSTANCED_CHAIN
	#include "instanced-chain.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;

	#if USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if VERTEX_VERTICAL_OFFSET
		float offsetWeight : TEXCOORD5;
	#elif WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED || USE_VERTEX_DISPLACEMENT
		float3 normal : NORMAL;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;

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

[auto][a] property float4 lightPosition0;

#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
	[auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if FLATCOLOR
	[material][a] property float4 flatColor = const1List4;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing.slh"

	const float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
	const float toLightDis = length(toLightDir);
	toLightDir *= 1.0 / toLightDis;

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
		const float3 lightColor = flatColor.rgb * 0.5 + float3(0.25, 0.25, 0.25);
		const float3 N = normalize(mul3Fast0(input.normal, worldViewInvTransposeMatrix));
		const float3 L = toLightDir;

		const float NdotL = saturate(dot(N, L));

		output.worldPos = worldPos;
		output.worldNormalNdotL = float4(N, 1.0 - NdotL);
		output.vertexColor = float4(flatColor.rgb * flatColor.rgb * 0.5 + ((lightColor * NdotL) * ((NdotL * NdotL) * (NdotL * NdotL) + _INVERSE_PI)), flatColor.a);
	#endif

	return output;
}

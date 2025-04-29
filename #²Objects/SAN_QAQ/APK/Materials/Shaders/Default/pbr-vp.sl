#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

#ensuredefined PBR_DECAL 0
#ensuredefined PBR_DETAIL 0

#define NEED_CHAIN_TEXCOORD_OFFSETS 1

#if INSTANCED_CHAIN
	#include "instanced-chain.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 binormal : BINORMAL;
	float2 texCoord0 : TEXCOORD0;

	#if PBR_LIGHTMAP || PBR_DECAL || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if NEEDS_LOCAL_POSITION
		float4 displacePos : POSITION1; // xyz - position, w - normal.z
	#endif

	#if HARD_SKINNING && TILED_DECAL_MASK
		float index : POSITION2;
	#endif

	float4 tbnToWorld0 : TANGENTTOWORLD0;
	float4 tbnToWorld1 : TANGENTTOWORLD1;
	float4 tbnToWorld2 : TANGENTTOWORLD2;

	#if TILED_DECAL_MASK
		float4 texCoord0 : TEXCOORD0;
	#else
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if PBR_DECAL || PBR_DETAIL || PBR_LIGHTMAP
		float4 texCoord1 : TEXCOORD1;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD2;
	#endif

	#if RECEIVE_SHADOW
		float3 toLightDir : TEXCOORD3;
	#endif

	#if TILED_DECAL_ANIMATED_EMISSION && TILED_DECAL_MASK
		float4 aniCamo : TEXCOORD4;
	#endif

	#if VERTEX_COLOR
		float vertexAlpha : COLOR0;
	#endif
};

[auto][a] property float4 lightPosition0;
[auto][a] property float4x4 worldInvTransposeMatrix;

#if RECEIVE_SHADOW
	[auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if HARD_SKINNING && TILED_DECAL_MASK
	[material][a] property float4 jointToDecalTextureMapping;
#endif

#if PBR_DETAIL
	[material][a] property float2 pbrDetailTileCoordScale = const1List2;
#endif

#if PBR_LIGHTMAP
	[material][a] property float2 pbrUvOffset = const0List2;
	[material][a] property float2 pbrUvScale = const0List2;
#endif

#if TEXTURE0_ANIMATION_SHIFT
	[material][a] property float2 tex0ShiftPerSecond = const0List2;
#endif

#if TEXTURE0_SHIFT_ENABLED
	[material][a] property float2 texture0Shift = const0List2;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing.slh"

	float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
	float toLightDis = length(toLightDir);
	toLightDir *= 1.0 / toLightDis;

	float3 normal = input.normal;
	float3 binormal = input.binormal;
	float3 tangent = input.tangent;

	#if INSTANCED_CHAIN
		normal.yz = rotate(normal.yz, segmentDir);
		binormal.yz = rotate(binormal.yz, segmentDir);
		tangent.yz = rotate(tangent.yz, segmentDir);
		normal = normalize(normal);
		binormal = normalize(binormal);
		tangent = normalize(tangent);
	#endif

	#if SOFT_SKINNING
		float3x3 tbn = softSkinnedTBN(tangent, binormal, normal, input.indices, input.weights);
		tangent = tbn[0];
		binormal = tbn[1];
		normal = tbn[2];
	#elif HARD_SKINNING
		float3x3 tbn = hardSkinnedTBN(tangent, binormal, normal, input.index);
		tangent = tbn[0];
		binormal = tbn[1];
		normal = tbn[2];
	#endif

	float3 t = normalize(mul3Fast0(tangent, worldInvTransposeMatrix));
	float3 b = normalize(mul3Fast0(binormal, worldInvTransposeMatrix));
	float3 n = normalize(mul3Fast0(normal, worldInvTransposeMatrix));

	output.tbnToWorld0 = float4(t.x, b.x, n.x, worldPos.x);
	output.tbnToWorld1 = float4(t.y, b.y, n.y, worldPos.y);
	output.tbnToWorld2 = float4(t.z, b.z, n.z, worldPos.z);

	#if RECEIVE_SHADOW
		output.toLightDir = float3(dot(toLightDir, normalize(mul3Fast0(tangent, worldViewInvTransposeMatrix))), dot(toLightDir, normalize(mul3Fast0(binormal, worldViewInvTransposeMatrix))), dot(toLightDir, normalize(mul3Fast0(normal, worldViewInvTransposeMatrix))));
	#endif

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if VERTEX_COLOR
		output.vertexAlpha = input.color0.a;
	#endif

	output.texCoord0.xy = input.texCoord0;

	#if INSTANCED_CHAIN
		output.texCoord0.y = output.texCoord0.y * segmentLength * (1.0 / chunkLength) + getTexCoordOffset(instanceId + 1);
	#endif

	#if ALBEDO_TRANSFORM
		output.texCoord0.xy = getTexCoordsTransform0(output.texCoord0.xy);
	#endif

	#if TEXTURE0_ANIMATION_SHIFT
		output.texCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
	#endif

	#if TEXTURE0_SHIFT_ENABLED
		output.texCoord0.xy += texture0Shift;
	#endif

	#if TILED_DECAL_MASK
		#include "decal-mask.slh"
	#endif

	#if PBR_DECAL || PBR_DETAIL || PBR_LIGHTMAP
		output.texCoord1 = const0List4;

		#if PBR_DECAL
			output.texCoord1.xy = input.texCoord1;
		#elif PBR_LIGHTMAP
			output.texCoord1.xy = input.texCoord1 * pbrUvScale + pbrUvOffset;
		#endif

		#if PBR_DETAIL
			output.texCoord1.zw = output.texCoord0.xy * pbrDetailTileCoordScale;
		#endif
	#endif

	#if NEEDS_LOCAL_POSITION
		#if INSTANCED_CHAIN
			output.displacePos = float4(displacePos, normal.z);
		#else
			output.displacePos = float4(displacePos, input.normal.z);
		#endif
	#endif

	#if HARD_SKINNING && TILED_DECAL_MASK
		output.index = jointToDecalTextureMapping[int(clamp(input.index, 0.0, 3.0))];
	#endif

	return output;
}

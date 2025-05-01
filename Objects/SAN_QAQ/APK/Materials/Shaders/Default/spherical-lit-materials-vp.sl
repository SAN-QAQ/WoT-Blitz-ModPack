#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

vertex_in
{
	float4 localPos : POSITION;

	#if VERTEX_COLOR
		float4 color0 : COLOR0;
	#endif

	#if MATERIAL_TEXTURE
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || MATERIAL_TEXTURE || MATERIAL_DECAL || TILED_DECAL_MASK
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if RECEIVE_SHADOW
		float3 worldPos : POSITION1;
	#endif

	#if ALPHA_MASK || MATERIAL_TEXTURE || MATERIAL_DECAL || TILED_DECAL_MASK
		float4 texCoord0 : TEXCOORD0;
	#endif

	#if MATERIAL_DETAIL || TILED_DECAL_MASK
		float4 texCoord1 : TEXCOORD1;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD2;
	#endif

	#if FLOWMAP
		float3 flowData : TEXCOORD3;
	#endif

	float3 sphericalLightFactor : TEXCOORD4;
};

#if SPHERICAL_HARMONICS_4 || SPHERICAL_HARMONICS_9 
	[auto][a] property float3 boundingBoxSize;
	[auto][a] property float3 worldViewObjectCenter;
	[auto][a] property float4x4 invViewMatrix;

	#if SPHERICAL_HARMONICS_4
		[auto][sh] property float4 sphericalHarmonics[3] : "bigarray";
	#endif

	#if SPHERICAL_HARMONICS_9
		[auto][sh] property float4 sphericalHarmonics[7] : "bigarray";
	#endif
#else
	[auto][sh] property float4 sphericalHarmonics;
#endif

#if USE_VERTEX_FOG
	[auto][a] property float4 lightPosition0;
#endif

#if FLOWMAP
	[material][a] property float flowAnimSpeed = 0.0;
	[material][a] property float flowAnimOffset = 0.0;
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
	#include "flowmap-vec.slh"

	#if USE_VERTEX_FOG
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir *= 1.0 / toLightDis;

		#include "vp-fog-math.slh"
	#endif

	#if SPHERICAL_HARMONICS_4 || SPHERICAL_HARMONICS_9
		float3 normal = normalize(mul3Fast0(eyePos - worldViewObjectCenter, invViewMatrix) * (1.0 / boundingBoxSize));
		float3 normalS = normal * normal;
		output.sphericalLightFactor = sphericalHarmonics[0].xyz * 0.564188 + mul(normal.yzx, float3x3(float3(sphericalHarmonics[0].w, sphericalHarmonics[1].xy), float3(sphericalHarmonics[1].zw, sphericalHarmonics[2].x), sphericalHarmonics[2].yzw)) * 0.651468;

		#if SPHERICAL_HARMONICS_9
			output.sphericalLightFactor += sphericalHarmonics[3].xyz * (normal.x * normal.y * 0.273136) + float3(sphericalHarmonics[3].w, sphericalHarmonics[4].xy) * (normal.y * normal.z * 0.273136) + float3(sphericalHarmonics[4].zw, sphericalHarmonics[5].x) * (normalS.z * 0.236541 - 0.078847) + sphericalHarmonics[5].yzw * (normal.x * normal.z * 0.273136) + sphericalHarmonics[6].xyz * ((normalS.x - normalS.y) * 0.136568);
		#endif
	#else
		output.sphericalLightFactor = sphericalHarmonics.xyz * 0.564188;
	#endif

	#if VERTEX_COLOR
		output.sphericalLightFactor *= input.color0.xyz;
	#endif

	#if ALPHA_MASK || MATERIAL_TEXTURE || MATERIAL_DECAL || TILED_DECAL_MASK
		output.texCoord0 = float4(input.texCoord0, input.texCoord1);
	#endif

	#if ALBEDO_TRANSFORM
		output.texCoord0.xy = getTexCoordsTransform0(input.texCoord0);
	#endif

	#if MATERIAL_TEXTURE
		#if TEXTURE0_SHIFT_ENABLED
			output.texCoord0.xy += texture0Shift;
		#endif

		#if TEXTURE0_ANIMATION_SHIFT
			output.texCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
		#endif
	#endif

	#if MATERIAL_DETAIL || TILED_DECAL_MASK
		output.texCoord1 = float4(output.texCoord.xy * detailTileCoordScale, output.texCoord.xy * decalTileCoordScale);
	#endif

	#if TILED_DECAL_MASK
		#if TILED_DECAL_TRANSFORM
			#if HARD_SKINNING
				output.texCoord1.zw = getTexCoordsTransform2(output.texCoord1.zw, int(input.index * 2.0));
			#elif !SOFT_SKINNING
				output.texCoord1.zw = getTexCoordsTransform1(output.texCoord1.zw);
			#endif
		#endif
	#endif

	#if RECEIVE_SHADOW
		output.worldPos = worldPos;
	#endif

	return output;
}

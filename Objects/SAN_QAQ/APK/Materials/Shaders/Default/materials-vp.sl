#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

#ensuredefined HIGHLIGHT_WAVE_ANIM 0

#if ENVIRONMENT_MAPPING
	#include "fresnel-shlick.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;

	#if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
	#endif

	#if ENVIRONMENT_MAPPING || MATERIAL_TEXTURE || TILED_DECAL_MASK
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE) || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if VERTEX_VERTICAL_OFFSET
		float offsetWeight : TEXCOORD5;
	#elif WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#if BLEND_BY_ANGLE || ENVIRONMENT_MAPPING || RECEIVE_SHADOW || USE_VERTEX_DISPLACEMENT
		float3 normal : NORMAL;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if VERTEX_COLOR
		float4 vertexColor : COLOR0;
	#endif

	#if (ALPHA_MASK || MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE)) || (ENVIRONMENT_MAPPING || MATERIAL_TEXTURE || TILED_DECAL_MASK)
		float4 texCoord0 : TEXCOORD0;
	#endif

	#if MATERIAL_DETAIL || TILED_DECAL_MASK
		float4 texCoord1 : TEXCOORD1;
	#endif

	#if ENVIRONMENT_MAPPING
		float4 specularVector : TEXCOORD2;
		float4 reflectionVector : TEXCOORD3;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD4;
	#endif

	#if FLOWMAP
		float3 flowData : TEXCOORD5; // For flowmap animations - xy next frame uv. z - frame time
	#endif

	#if BLEND_BY_ANGLE || RECEIVE_SHADOW
		float4 worldNormalNdotL : POSITION0;
	#endif

	#if BLEND_BY_ANGLE
		float3 worldView : POSITION1;
	#endif

	#if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
		float3 worldPos : POSITION2;
	#endif
};

[auto][a] property float4 lightPosition0;

#if BLEND_BY_ANGLE || ENVIRONMENT_MAPPING || RECEIVE_SHADOW
	[auto][a] property float4x4 worldInvTransposeMatrix;
	[auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if !SETUP_LIGHTMAP && MATERIAL_LIGHTMAP && VIEW_DIFFUSE
	[material][a] property float2 uvOffset = const0List2;
	[material][a] property float2 uvScale = const0List2;
#endif

#if DISTANCE_FADE_OUT && VERTEX_COLOR
	[material][a] property float2 distanceFadeNearFarSq;
#endif

#if ENVIRONMENT_MAPPING
	[material][a] property float reflectionBrightenEnvMap = 3.0;
	[material][a] property float reflectionSpecular = 1.0;
	[material][a] property float3 reflectionMetalFresnelReflectance = float3(0.562, 0.565, 0.578);
#endif

#if FLOWMAP
	[material][a] property float flowAnimOffset = 0.0;
	[material][a] property float flowAnimSpeed = 0.0;
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

	float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
	float toLightDis = length(toLightDir);
	toLightDir *= 1.0 / toLightDis;

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if BLEND_BY_ANGLE || RECEIVE_SHADOW || ENVIRONMENT_MAPPING
		float3 worldNormal = normalize(mul3Fast0(input.normal, worldInvTransposeMatrix));
	#endif

	float3 worldView = normalize(worldPos - camPos);

	#if BLEND_BY_ANGLE
		output.worldView = worldView;
	#endif

	#if VERTEX_COLOR
		output.vertexColor = input.color0;

		#if DISTANCE_FADE_OUT
			output.vertexColor.a -= output.vertexColor.a * smoothstep(distanceFadeNearFarSq.x, distanceFadeNearFarSq.y, dot(worldView, worldView));
		#endif
	#endif

	#if (ALPHA_MASK || MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE)) || (ENVIRONMENT_MAPPING || MATERIAL_TEXTURE || TILED_DECAL_MASK)
		output.texCoord0 = const0List4;

		#if ALPHA_MASK || MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE)
			#if !SETUP_LIGHTMAP && MATERIAL_LIGHTMAP && VIEW_DIFFUSE
				output.texCoord0.xy = input.texCoord1 * uvScale + uvOffset;
			#else
				output.texCoord0.xy = input.texCoord1;
			#endif
		#endif

		#if ENVIRONMENT_MAPPING || MATERIAL_TEXTURE || TILED_DECAL_MASK
			output.texCoord0.zw = getTexCoordsTransform0(input.texCoord0);
		#endif
	#endif

	#if MATERIAL_TEXTURE
		#if TEXTURE0_SHIFT_ENABLED
			output.texCoord0.zw += texture0Shift;
		#endif

		#if TEXTURE0_ANIMATION_SHIFT
			output.texCoord0.zw += frac(tex0ShiftPerSecond * globalTime);
		#endif
	#endif

	#if !DRAW_DEPTH_ONLY && (MATERIAL_DETAIL || TILED_DECAL_MASK)
		output.texCoord1 = float4(output.texCoord0.zw * decalTileCoordScale, output.texCoord0.zw * detailTileCoordScale);

		#if TILED_DECAL_TRANSFORM
			#if HARD_SKINNING
				output.texCoord1.xy = getTexCoordsTransform2(output.texCoord1.xy, int(input.index * 2.0));
			#elif !SOFT_SKINNING
				output.texCoord1.xy = getTexCoordsTransform1(output.texCoord1.xy);
			#endif
		#endif
	#endif

	float3 L = toLightDir;

	#if BLEND_BY_ANGLE || ENVIRONMENT_MAPPING || RECEIVE_SHADOW
		float3 normal = input.normal;

		#if SOFT_SKINNING
			normal = softSkinnedNormal(normal, input.indices, input.weights);
		#elif HARD_SKINNING
			normal = hardSkinnedNormal(normal, input.index);
		#endif

		float3 N = normalize(mul3Fast0(normal, worldViewInvTransposeMatrix));
		float NdotL = saturate(dot(N, L));
	#endif

	#if ENVIRONMENT_MAPPING
		float3 V = normalize(-eyePos);
		float3 H = normalize(L + V);

		float NdotV = saturate(dot(N, V));
		float NdotH = saturate(dot(N, H));
		float VdotH = saturate(dot(V, H));

		float3 fresnelOut = F_ShlickVec3(NdotV, reflectionMetalFresnelReflectance);

		output.specularVector = float4(fresnelOut * (NdotL * reflectionSpecular) * (1.0 / (VdotH * VdotH + 0.0001)), NdotH);
		output.reflectionVector = float4(reflect(worldView, worldNormal), dot(fresnelOut, rgbMixList * reflectionBrightenEnvMap));
	#endif

	#if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
		output.worldPos = worldPos;
	#endif

	#if BLEND_BY_ANGLE || RECEIVE_SHADOW
		output.worldNormalNdotL = float4(worldNormal, 1.0 - NdotL);
	#endif

	#if PUSH_TO_NEAR_PLANE_HACK
		float z = output.localPos.z * 0.00005 * (1.0 / output.localPos.w) + 0.00005;
		output.localPos.z = z * output.localPos.w - output.localPos.w;
	#endif

	return output;
}

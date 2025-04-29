#include "common.slh"
#include "lighting.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

#ensuredefined HIGHLIGHT_WAVE_ANIM 0

#define NEED_CHAIN_TEXCOORD_OFFSETS 1

#if INSTANCED_CHAIN
	#include "instanced-chain.slh"
#endif

#if !PIXEL_LIT && NORMALIZED_BLINN_PHONG
	#include "fresnel-shlick.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;
	float3 normal : NORMAL;

	#if MATERIAL_TEXTURE
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || MATERIAL_DETAIL || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if USE_VERTEX_DISPLACEMENT || VERTEX_COLOR
		float4 color0 : COLOR0;
	#endif

	#if PIXEL_LIT
		float3 tangent : TANGENT;
		float3 binormal : BINORMAL;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if HIGHLIGHT_WAVE_ANIM || PIXEL_LIT || RECEIVE_SHADOW
		float3 worldPos : POSITION1;
	#endif

	#if TILED_DECAL_MASK && TILED_DECAL_SPATIAL_SPREADING
		float3 displacePos : POSITION2;
	#endif

	#if MATERIAL_TEXTURE || PIXEL_LIT || TILED_DECAL_MASK
		float4 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || MATERIAL_DETAIL
		float4 texCoord1 : TEXCOORD1;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD2;
	#endif

	#if PIXEL_LIT
		float4 tbnToView0 : TANGENTTOVIEW0;
		float4 tbnToView1 : TANGENTTOVIEW1;
		float4 tbnToView2 : TANGENTTOVIEW2;

		#if RECEIVE_SHADOW
			float4 tbnToWorld0 : TANGENTTOWORLD0;
			float4 tbnToWorld1 : TANGENTTOWORLD1;
			float4 tbnToWorld2 : TANGENTTOWORLD2;
		#endif
	#else
		#if SIMPLE_BLINN_PHONG || NORMALIZED_BLINN_PHONG
			float3 diffuseVector : TEXCOORD3;
		#endif

		#if SIMPLE_BLINN_PHONG
			float specularVector : TEXCOORD4;
		#elif NORMALIZED_BLINN_PHONG
			float4 specularVector : TEXCOORD4;
		#endif

		#if RECEIVE_SHADOW
			float4 worldNormalNdotL : TEXCOORD5;
		#endif
	#endif

	#if !ENVIRONMENT_MAPPING_NORMALMAP && ENVIRONMENT_MAPPING
		float3 reflectionTexCoord : TEXCOORD6;
	#endif

	#if HARD_SKINNING && TILED_DECAL_MASK
		float index : TEXCOORD7;
	#endif

	#if TILED_DECAL_ANIMATED_EMISSION && TILED_DECAL_MASK
		float4 aniCamo : COLOR0;
	#endif

	#if VERTEX_COLOR
		float4 vertexColor : COLOR1;
	#endif
};

[auto][a] property float4 lightPosition0;
[auto][a] property float4x4 worldViewInvTransposeMatrix;

#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW
	[auto][a] property float4x4 worldInvTransposeMatrix;
#endif

#if !PIXEL_LIT
	[auto][a] property float3 lightColor0;
	[auto][a] property float4x4 pointLights; // 0,1:(position, radius); 2:3 (color, unused)

	[material][a] property float materialSpecularShininess = 0.5;
	[material][a] property float inSpecularity = 1.0;
	[material][a] property float inGlossiness = 0.5;
	[material][a] property float3 metalFresnelReflectance = float3(0.562, 0.565, 0.578);
#endif

#if HARD_SKINNING && TILED_DECAL_MASK
	[material][a] property float4 jointToDecalTextureMapping;
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

	float3 L = toLightDir;
	float3 V = normalize(-eyePos);

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if PIXEL_LIT
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

		float3 t = normalize(mul3Fast0(tangent, worldViewInvTransposeMatrix));
		float3 b = normalize(mul3Fast0(binormal, worldViewInvTransposeMatrix));
		float3 n = normalize(mul3Fast0(normal, worldViewInvTransposeMatrix));

		output.tbnToView0 = float4(t.x, b.x, n.x, eyePos.x);
		output.tbnToView1 = float4(t.y, b.y, n.y, eyePos.y);
		output.tbnToView2 = float4(t.z, b.z, n.z, eyePos.z);

		#if RECEIVE_SHADOW
			float3 temp = float3(dot(L, t), dot(L, b), dot(L, n));

			t = normalize(mul3Fast0(tangent, worldInvTransposeMatrix));
			b = normalize(mul3Fast0(binormal, worldInvTransposeMatrix));
			n = normalize(mul3Fast0(normal, worldInvTransposeMatrix));

			output.tbnToWorld0 = float4(t.x, b.x, n.x, temp.x);
			output.tbnToWorld1 = float4(t.y, b.y, n.y, temp.y);
			output.tbnToWorld2 = float4(t.z, b.z, n.z, temp.z);
		#endif
	#else
		float3 normal = input.normal;

		#if INSTANCED_CHAIN
			normal.yz = rotate(normal.yz, segmentDir);
			normal = normalize(normal);
		#elif SOFT_SKINNING
			normal = softSkinnedNormal(normal, input.indices, input.weights);
		#elif HARD_SKINNING
			normal = hardSkinnedNormal(normal, input.index);
		#endif

		float3 N = normalize(mul3Fast0(normal, worldViewInvTransposeMatrix);
		float NdotL = saturate(dot(N, L));

		#if RECEIVE_SHADOW
			output.worldNormalNdotL = float4(normalize(mul3Fast0(input.normal, worldInvTransposeMatrix)), 1.0 - NdotL);
		#endif

		#if SIMPLE_BLINN_PHONG
			float3 H = normalize(L + V);

			float NdotH = saturate(dot(N, H));

			output.specularVector = pow(NdotH, materialSpecularShininess);
			output.diffuseVector= float3(NdotL, NdotL, NdotL);
		#elif NORMALIZED_BLINN_PHONG
			float3 H = normalize(L + V);

			float NdotV = saturate(dot(N, V));
			float NdotH = saturate(dot(N, H));
			float VdotH = saturate(dot(V, H));

			float3 fresnelOut = F_ShlickVec3(NdotV, metalFresnelReflectance);
			float Geo = 1.0 / (VdotH * VdotH + 0.0001);

			output.diffuseVector = lightColor0 * (NdotL * _INVERSE_PI);
			output.specularVector = float4(fresnelOut * (NdotL * Geo * inSpecularity), NdotH);

			#if MAX_POINT_LIGHTS > 0
				output.diffuseVector += getBlinnPhongPointLight(pointLights[0].w, pointLights[2], pointLights[0].xyz - eyePos, N);

				#if MAX_POINT_LIGHTS > 1
					output.diffuseVector += getBlinnPhongPointLight(pointLights[1].w, pointLights[3], pointLights[1].xyz - eyePos, N);
				#endif
			#endif
		#endif
	#endif

	#if VERTEX_COLOR
		output.vertexColor = input.color0;
	#endif

	#if MATERIAL_TEXTURE || TILED_DECAL_MASK
		output.texCoord0.xy = input.texCoord0;

		#if INSTANCED_CHAIN
			output.texCoord0.y = output.texCoord0.y * segmentLength * (1.0 / chunkLength) + getTexCoordOffset(instanceId + 1);
		#endif

		output.texCoord0.xy = getTexCoordsTransform0(output.texCoord0.xy);
	#endif

	#if MATERIAL_TEXTURE
		#if TEXTURE0_ANIMATION_SHIFT
			output.texCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
		#endif

		#if TEXTURE0_SHIFT_ENABLED
			output.texCoord0.xy += texture0Shift;
		#endif
	#endif

	#if TILED_DECAL_MASK
		#include "decal-mask.slh"
	#endif

	#if ALPHA_MASK || MATERIAL_DETAIL
		output.texCoord1 = float4(input.texCoord1, output.texCoord0.xy * detailTileCoordScale);
	#endif

	#if HIGHLIGHT_WAVE_ANIM || PIXEL_LIT || RECEIVE_SHADOW
		output.worldPos = worldPos;
	#endif

	#if TILED_DECAL_MASK && TILED_DECAL_SPATIAL_SPREADING
		output.displacePos = displacePos;
	#endif

	#if !ENVIRONMENT_MAPPING_NORMALMAP && ENVIRONMENT_MAPPING
		output.reflectionTexCoord = reflect(normalize(worldPos - camPos), normalize(mul3Fast0(input.normal, worldInvTransposeMatrix)));
	#endif

	#if HARD_SKINNING && TILED_DECAL_MASK
		output.index = jointToDecalTextureMapping[int(clamp(input.index, 0.0, 3.0))];
	#endif

	return output;
}

#define SHADOW_RECEIVER 1

#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

#if ENVIRONMENT_MAPPING
	#include "fresnel-shlick.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;

	#if ENVIRONMENT_MAPPING || MATERIAL_TEXTURE
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if (MATERIAL_LIGHTMAP && VIEW_DIFFUSE) || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW || USE_VERTEX_DISPLACEMENT
		float3 normal : NORMAL;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if RECEIVE_SHADOW
		float4 worldNormalNdotL : POSITION1;
		float3 worldPos : POSITION2;
	#endif

	#if ENVIRONMENT_MAPPING || (MATERIAL_TEXTURE || MATERIAL_LIGHTMAP && VIEW_DIFFUSE)
		float4 texCoord : TEXCOORD0;
	#endif

	#if ENVIRONMENT_MAPPING
		float4 specularVector : TEXCOORD1;
		float4 reflectionVector : TEXCOORD2;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD3;
	#endif
};

[auto][a] property float4 lightPosition0;

#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW
	[auto][a] property float4x4 worldInvTransposeMatrix;
	[auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if ENVIRONMENT_MAPPING
	[material][a] property float reflectionBrightenEnvMap = 3.0;
	[material][a] property float reflectionSpecular = 1.0;
	[material][a] property float3 reflectionMetalFresnelReflectance = float3(0.562, 0.565, 0.578);
#endif

#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
	[material][a] property float2 uvOffset = const0List2;
	[material][a] property float2 uvScale = const0List2;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing.slh"

	float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
	float toLightDis = length(toLightDir);
	toLightDir *= 1.0 / toLightDis;

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if ENVIRONMENT_MAPPING || (MATERIAL_TEXTURE || MATERIAL_LIGHTMAP && VIEW_DIFFUSE)
		output.texCoord = const0List4;

		#if ENVIRONMENT_MAPPING || MATERIAL_TEXTURE
			output.texCoord.xy = getTexCoordsTransform0(input.texCoord0);
		#endif

		#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
			output.texCoord.zw = input.texCoord1 * uvScale + uvOffset;
		#endif
	#endif

	#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW
		float3 normal = input.normal;
		float3 worldNormal = normalize(mul3Fast0(normal, worldInvTransposeMatrix));

		#if SOFT_SKINNING
			normal = softSkinnedNormal(normal, input.indices, input.weights);
		#elif HARD_SKINNING
			normal = hardSkinnedNormal(normal, input.index);
		#endif

		float3 L = toLightDir;
		float3 N = normalize(mul3Fast0(normal, worldViewInvTransposeMatrix));
		float NdotL = saturate(dot(N, L));
	#endif

	#if ENVIRONMENT_MAPPING
		float3 toWorldDir = normalize(worldPos - camPos);
		float3 V = normalize(-eyePos);
		float3 H = normalize(L + V);

		float NdotV = saturate(dot(N, V));
		float NdotH = saturate(dot(N, H));
		float VdotH = saturate(dot(V, H));

		float3 fresnelOut = fresnelVec3(NdotV, reflectionMetalFresnelReflectance);

		output.specularVector = float4(fresnelOut * (NdotL * reflectionSpecular) * (1.0 / (VdotH * VdotH + 0.0001)), NdotH);
		output.reflectionVector = float4(reflect(toWorldDir, worldNormal), dot(fresnelOut, rgbMixList * reflectionBrightenEnvMap));
	#endif

	#if RECEIVE_SHADOW
		output.worldPos = worldPos;
		output.worldNormalNdotL = float4(worldNormal, 1.0 - NdotL);
	#endif

	return output;
}

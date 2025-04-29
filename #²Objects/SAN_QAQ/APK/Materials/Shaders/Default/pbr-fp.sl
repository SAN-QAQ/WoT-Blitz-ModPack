#include "common.slh"
#include "blending.slh"
#include "highlight-animation.slh"
#include "pbr-lighting.slh"

#ensuredefined PBR_DECAL 0
#ensuredefined PBR_DETAIL 0

#if LOD_TRANSITION
	#include "lod-transition.slh"
#endif

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

#if TILED_DECAL_MASK && TILED_DECAL_SPREADING 
	#include "decal-spreading.slh"
#endif

fragment_in
{
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

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D baseColorMap; // RGB - albedo color, A - alpha
uniform sampler2D baseNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
uniform sampler2D baseRMMap; // RG or AG(DXT5NM) or GA(ASTC) - roughness / metallic
uniform sampler2D maskMap; // RG or AG(DXT5NM) or GA(ASTC) - decal mask / dirt mask
uniform sampler2D miscMap; // RG or AG(DXT5NM) or GA(ASTC) - ambient occlusion / emissive

#if DIRT_COVERAGE
	uniform sampler2D dirtHeightMap; // R or A (API specific) - dirt height
	uniform sampler2D dirtNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
#endif

#if PBR_DECAL
	uniform sampler2D pbrDecalColorRoughnessMap; // RGB - albedo color, A - roughness
	uniform sampler2D pbrDecalLightmap; // RG or AG(DXT5NM) or GA(ASTC) - directional shadow / ambient occlusion
#endif

#if PBR_DETAIL
	uniform sampler2D pbrDetailColorMap; // RGB - albedo color
	uniform sampler2D pbrDetailNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
	uniform sampler2D pbrDetailRoughnessAOMap; // RG or AG(DXT5NM) or GA(ASTC) - roughness / ambient occlusion
#endif

#if PBR_LIGHTMAP
	uniform sampler2D pbrLightmap; // RG or AG(DXT5NM) or GA(ASTC) - directional shadow / ambient occlusion
#endif

#if TILED_DECAL_MASK
	uniform sampler2DArray decalColorMap; // RGB - decal color, A - decal alpha

	#if TILED_DECAL_BLEND_NORMAL
		uniform sampler2DArray decalNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
	#endif

	#if TILED_DECAL_OVERRIDE_ROUGHNESS_METALLIC
		uniform sampler2DArray decalRMMap; // RG or AG(DXT5NM) or GA(ASTC) - roughness / metallic
	#endif
#endif

#if WETNESS_MULTILEVEL
	#ifndef PERLIN_NOISE_DEFINED
		uniform sampler2D perlinNoise;

		#define PERLIN_NOISE_DEFINED 1
	#endif
#endif

[auto][a] property float lightIntensity0;
[auto][a] property float3 cameraPosition;
[auto][a] property float3 lightColor0;
[auto][a] property float4 lightPosition0;
[auto][a] property float4x4 invViewMatrix;

#if MAX_POINT_LIGHTS > 0
	[auto][a] property float pointLightIntensity0;
	[auto][a] property float pointLightIntensity1;
	[auto][a] property float4x4 pointLights; // 0,1: (position, radius); 2,3: (color, falloff exponent)
#endif

[material][a] property float normalScale = 1.0;
[material][a] property float2 roughnessMetallicFactor = const1List2;
[material][a] property float4 baseColorFactor = const1List4;

#if ALPHABLEND && ALPHASTEPVALUE
	[material][a] property float alphaStepValue = 0.5;
#endif

#if ALPHATEST && ALPHATESTVALUE
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if AMBIENT_ATTENUATION_BOX
	[material][a] property float3 attenuationBoxHalfSize = const0List3;
	[material][a] property float3 attenuationBoxPosition = const0List3;
	[material][a] property float3 attenuationBoxSmoothness = const0List3;
#endif

#if BLEND_WITH_CONST_ALPHA
	[material][a] property float flatAlpha = 1.0;
#endif

#if DIRT_COVERAGE
	[material][a] property float dirtRoughness = 1.0;
	[material][a] property float dirtStrength = 0.0;
	[material][a] property float4 dirtColor = const1List4;
#endif

#if EMISSIVE_ALBEDO
	[material][a] property float emissiveAlbedoFactor = 1.0;
#endif

#if EMISSIVE_COLOR
	[material][a] property float3 emissiveColor = const1List3;
#endif

#if LOD_TRANSITION
	[material][a] property float lodTransitionThreshold = 0.0;
#endif

#if TILED_DECAL_EMISSIVE_ALBEDO
	[material][a] property float tiledDecalEmissiveAlbedoFactor = 1.0;
#endif

#if TILED_DECAL_EMISSIVE_COLOR
	[material][a] property float3 tiledDecalEmissiveColor = const1List3;
#endif

#if TILED_DECAL_BLEND_NORMAL && TILED_DECAL_MASK
	[material][a] property float decalblendNormal = 0.5;
#endif

#if WETNESS_MULTILEVEL
	[material][a] property float4 wetnessHeights = float4(0.8, 1.2, 1.6, 2.0);
	[material][a] property float4 wetnessStrengths = const0List4;
#endif

#if WETNESS_SIMPLIFIED
	[material][a] property float simpleWetnessStrength = 0.0;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 projPos = input.projPos.xy * (1.0 / input.projPos.w);
	float3 worldPos = float3(input.tbnToWorld0.w, input.tbnToWorld1.w, input.tbnToWorld2.w);
	float4 baseColor = tex2D(baseColorMap, input.texCoord0.xy);

	#if LOD_TRANSITION
		baseColor.a *= getLodTransition(projPos, lodTransitionThreshold);
	#endif

	#if ALPHATEST
		float alpha = baseColor.a;

		#if VERTEX_COLOR
			alpha *= input.vertexAlpha;
		#endif

		#if ALPHATESTVALUE
			if (alpha < alphatestThreshold) discard;
		#else
			if (alpha < 0.5) discard;
		#endif
	#endif

	#if ALPHABLEND && ALPHASTEPVALUE
		baseColor.a = step(alphaStepValue, baseColor.a);
	#endif

	baseColor *= baseColorFactor;

	float2 misc = tex2D(miscMap, input.texCoord0.xy).ga;
	float2 mask = tex2D(maskMap, input.texCoord0.xy).ga;
	float2 baseRM = tex2D(baseRMMap, input.texCoord0.xy).ga * roughnessMetallicFactor;
	float3 baseNormal = unpackNormal(tex2D(baseNormalMap, input.texCoord0.xy).ga);

	#if PBR_DECAL
		float4 decalColorAndRoughness = tex2D(pbrDecalColorRoughnessMap, input.texCoord1.xy) * 2.0;
		baseColor.rgb *= decalColorAndRoughness.rgb;
		baseRM.x *= decalColorAndRoughness.a;
	#endif

	#if PBR_DETAIL
		float2 detailRoughnessAO = tex2D(pbrDetailRoughnessAOMap, input.texCoord1.zw).ga;
		float3 detailColor = tex2D(pbrDetailColorMap, input.texCoord1.zw).rgb;
		float3 detailNormal = unpackNormal(tex2D(pbrDetailNormalMap, input.texCoord1.zw).ga);

		baseNormal = blendNormal(detailNormal, baseNormal);
		baseColor.rgb *= detailColor * 2.0;
		baseRM.x *= detailRoughnessAO.x * 2.0;
		misc.r *= detailRoughnessAO.y;
	#endif

	float3 emission = const0List3;

	#if TILED_DECAL_MASK
		#if HARD_SKINNING
			float index = floor(input.index + 0.5);
		#else
			float index = 0.0;
		#endif

		float4 decalColor = tex2Darray(decalColorMap, input.texCoord0.zw, index);

		#if TILED_DECAL_EMISSIVE_ALBEDO
			emission += decalColor.rgb * (mask.r * decalColor.a * max(0.0, tiledDecalEmissiveAlbedoFactor));
		#elif TILED_DECAL_EMISSIVE_COLOR
			emission += tiledDecalEmissiveColor * (mask.r * decalColor.a);
		#elif !TILED_DECAL_ANIM_MASK
			mask.r *= decalColor.a;
		#endif

		#if TILED_DECAL_ANIMATED_EMISSION
			float a = dot(decalColor.rgb, rgbMixList) * input.aniCamo.z;
			float selector = saturate(a - input.aniCamo.x) - saturate(a - input.aniCamo.y);

			#if TILED_DECAL_ANIM_MASK
				selector *= decalColor.a;
			#else
				selector *= mask.r;
			#endif

			decalColor.rgb *= (selector * input.aniCamo.w + 1.0);
		#endif

		#if TILED_DECAL_SPREADING
			float spreading = 1.0;

			#if TILED_DECAL_NOISE_SPREADING
				spreading *= getSpreadNoise(input.texCoord0.zw);
			#endif

			#if TILED_DECAL_SPATIAL_SPREADING
				spreading *= getSpreadSpace(input.displacePos.xyz);
			#endif

			mask.r *= spreading;
			emission += lerp(emission, spreadingBorderColor * 2.0, -abs(spreading * 2.0 - 1.0) * mask.r + mask.r);
		#endif

		#if TILED_DECAL_BLEND_NORMAL
			float blendFactor = decalblendNormal * mask.r * 2.0;
			float3 decalNormal = unpackNormal(tex2Darray(decalNormalMap, input.texCoord0.zw, index).ga);
			float3 blendNormal = blendNormal(baseNormal, decalNormal);

			baseNormal = lerp(baseNormal, blendNormal, saturate(blendFactor));
			baseNormal = lerp(baseNormal, decalNormal, saturate(blendFactor - 1.0));
		#endif

		#if TILED_DECAL_OVERRIDE_ROUGHNESS_METALLIC
			baseRM = lerp(baseRM, tex2Darray(decalRMMap, input.texCoord0.zw, index).ga, mask.r);
		#endif

		baseColor.rgb = lerp(baseColor.rgb, toLinear(decalColor.rgb), mask.r);
	#endif

	#if DIRT_COVERAGE
		float dirtFactor = saturate(1.0 - smoothstep(dirtStrength - 0.25, dirtStrength + 0.25, 1.0 - mask.g) + smoothstep(0.05, 0.95, dirtStrength * tex2D(dirtHeightMap, input.texCoord0.xy).g));
		float3 dirtNormal = unpackNormal(tex2D(dirtNormalMap, input.texCoord0.xy).ga);

		baseColor.rgb = lerp(baseColor.rgb, toLinear(dirtColor.rgb), dirtFactor * dirtColor.a);
		baseRM = lerp(baseRM, float2(dirtRoughness, 0.0), dirtFactor);
		dirtNormal = normalize(lerp(blendNormal(baseNormal, dirtNormal), dirtNormal, dirtStrength * dirtStrength));
		baseNormal = normalize(lerp(baseNormal, dirtNormal, dirtFactor));
	#endif

	float3 N = baseNormal;
	N.xy *= normalScale;
	N = normalize(float3(dot(N, input.tbnToWorld0.xyz), dot(N, input.tbnToWorld1.xyz), dot(N, input.tbnToWorld2.xyz)));
	float3 polygonN = normalize(float3(input.tbnToWorld0.z, input.tbnToWorld1.z, input.tbnToWorld2.z));
	float3 L = normalize(mul3Fast0(lightPosition0.xyz, invViewMatrix));
	float3 V = normalize(cameraPosition - worldPos);
	float3 H = normalize(L + V);

	#if WETNESS_MULTILEVEL || WETNESS_SIMPLIFIED
		#if WETNESS_MULTILEVEL
			float2 boundPos = const0List2;
			boundPos += input.displacePos.xy * 1.2;
			boundPos += input.displacePos.zz * 0.4;

			const float noiseSample = tex2D(perlinNoise, boundPos).a;
			const float boundarySample = lerp(noiseSample * 0.25, noiseSample * 0.05 + 0.15, saturate(input.displacePos.w * 10.0 - 9.0));
			const float boundarySampleFade = boundarySample + 0.05;

			const float4 stepCurrentLevel = step(wetnessHeights, input.displacePos.zzzz);
			const float4 stepNextLevel = step(wetnessHeights, input.displacePos.zzzz + float4(boundarySampleFade, boundarySampleFade, boundarySampleFade, boundarySampleFade));

			const float currentLevelF32 = dot(stepCurrentLevel, const1List4);
			const float nextLevelF32 = dot(stepNextLevel, const1List4);
			const int currentLevel = int(currentLevelF32);
			const int nextLevel = int(nextLevelF32);

			const float currentStrength = lerp(1.0, wetnessStrengths[currentLevel - 1], float(currentLevelF32 > 0.0));
			const float nextStrength = lerp(1.0, wetnessStrengths[nextLevel - 1], float(nextLevelF32 > 0.0));
			float currentHeight = lerp(100.0, wetnessHeights[currentLevel], float(currentLevelF32 < 4.0));

			for (int midLevel = nextLevel - 1; midLevel > currentLevel; --midLevel)
			{
				float midHeight = wetnessHeights[midLevel];

				nextStrength = lerp(wetnessStrengths[midLevel - 1], nextStrength, smoothstep(midHeight - boundarySampleFade, midHeight - boundarySample, input.displacePos.z));
			}

			const float wetnessStrength = lerp(currentStrength, nextStrength, smoothstep(currentHeight - boundarySampleFade, currentHeight - boundarySample, input.displacePos.z));
		#else
			const float wetnessStrength = simpleWetnessStrength;
		#endif

		const float porosity = saturate(baseRM.x * 2.0 - 0.4);
		const float wetnessMultiplier = lerp(1.0, 0.05, -porosity * baseRM.y + porosity);

		baseColor.rgb *= lerp(1.0, wetnessMultiplier, wetnessStrength);
		baseRM.x = lerp(0.0, baseRM.x, lerp(1.0, baseRM.x * baseRM.x * wetnessMultiplier, wetnessStrength * 0.5));
	#endif

	#if PBR_DECAL || PBR_LIGHTMAP
		float2 directionalAndAO = const1List2;

		#if PBR_DECAL
			directionalAndAO *= tex2D(pbrDecalLightmap, input.texCoord1.xy).ga;
		#endif

		#if PBR_LIGHTMAP
			directionalAndAO *= tex2D(pbrLightmap, input.texCoord1.xy).ga;
		#endif

		misc.r *= directionalAndAO.y;
	#endif

	#if AMBIENT_ATTENUATION_BOX
		float3 ambientAttenuation = const1List3 - smoothstep(attenuationBoxHalfSize - attenuationBoxSmoothness, attenuationBoxHalfSize, abs(attenuationBoxPosition - input.displacePos.xyz));
		misc.r -= (ambientAttenuation.x * ambientAttenuation.y) * (ambientAttenuation.z * misc.r);
	#endif

	#if EMISSIVE_ALBEDO
		emission += baseColor.rgb * (misc.g * max(emissiveAlbedoFactor, 0.0) * 1.5);
	#elif EMISSIVE_COLOR
		emission += emissiveColor * (misc.g * 1.5);
	#endif

	float shadow = 1.0;

	#if RECEIVE_SHADOW
		float3 NShady = baseNormal;
		NShady.xy *= shadowLitNormalScale;
		NShady = normalize(NShady);
		float3 LShady = normalize(input.toLightDir);
		float NdotLShady = saturate(1.0 - dot(NShady, LShady));
		float3 worldNormal = float3(dot(NShady, input.tbnToWorld0.xyz), dot(NShady, input.tbnToWorld1.xyz), dot(NShady, input.tbnToWorld2.xyz));
		float3 shadowInf = getShadow(worldNormal * (shadowNormalSlopeOffset * NdotLShady) + worldPos, projPos, NdotLShady);

		#if PBR_DECAL || PBR_LIGHTMAP
			shadow = lerp(directionalAndAO.x, shadowInf.z, shadowInf.y);
		#else
			shadow = shadowInf.x;
		#endif
	#elif PBR_DECAL || PBR_LIGHTMAP
		shadow = directionalAndAO.x;
	#endif

	baseColor.rgb = saturate(baseColor.rgb);
	baseRM = saturate(baseRM);
	misc.r = saturate(misc.r);

	output.color.rgb = getPBR(polygonN, N, V, L, H, lightColor0 * lightIntensity0, baseColor.rgb, baseRM.y, baseRM.x, misc.r, shadow, emission);

	#if MAX_POINT_LIGHTS > 0
		float4 pbrPointLightInf = getPbrPointLight(mul3Fast1(pointLights[0].xyz, invViewMatrix) - worldPos, pointLights[0].w, pointLights[2].w);
		output.color.rgb += getPBR(polygonN, N, V, pbrPointLightInf.xyz, H, pointLights[2].xyz * (pointLightIntensity0 * pbrPointLightInf.w), baseColor.rgb, baseRM.y, baseRM.x, 0.0, 1.0, const0List3);

		#if MAX_POINT_LIGHTS > 1
			pbrPointLightInf = getPbrPointLight(mul3Fast1(pointLights[1].xyz, invViewMatrix) - worldPos, pointLights[1].w, pointLights[3].w);
			output.color.rgb += getPBR(polygonN, N, V, pbrPointLightInf.xyz, H, pointLights[3].xyz * (pointLightIntensity1 * pbrPointLightInf.w), baseColor.rgb, baseRM.y, baseRM.x, 0.0, 1.0, const0List3);
		#endif
	#endif

	#include "color-grading.slh"

	#if ALPHABLEND
		output.color.a = baseColor.a;
	#else
		output.color.a = 1.0;
	#endif

	#if BLEND_WITH_CONST_ALPHA
		output.color.a = flatAlpha;
	#endif

	#if HIGHLIGHT_COLOR || HIGHLIGHT_WAVE_ANIM
		output.color = getHighlightAnim(output.color, worldPos.z);
	#endif

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	return output;
}

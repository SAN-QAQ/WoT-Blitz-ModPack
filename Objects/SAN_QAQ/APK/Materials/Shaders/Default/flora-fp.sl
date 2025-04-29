#include "common.slh"
#include "blending.slh"

#ensuredefined FLORA_AMBIENT_ANIMATION 0
#ensuredefined FLORA_EDGE_MAP 0
#ensuredefined FLORA_FAKE_SHADOW 0
#ensuredefined FLORA_LAYING 0
#ensuredefined FLORA_LOD_TRANSITION_FAR 0
#ensuredefined FLORA_LOD_TRANSITION_NEAR 0
#ensuredefined FLORA_NORMAL_MAP 0
#ensuredefined FLORA_PBR_LIGHTING 0
#ensuredefined FLORA_WIND_ANIMATION 0

#define FLORA_ANIMATION (FLORA_AMBIENT_ANIMATION || FLORA_WIND_ANIMATION)
#define FLORA_LOD_TRANSITION (FLORA_LOD_TRANSITION_FAR || FLORA_LOD_TRANSITION_NEAR)

#if !DRAW_DEPTH_ONLY
	#if FLORA_PBR_LIGHTING
		#include "pbr-lighting.slh"
	#endif

	#if RECEIVE_SHADOW
		#include "shadow-mapping.slh"
	#endif
#endif

#if FLORA_LOD_TRANSITION
	#include "lod-transition.slh"
#endif

fragment_in
{
	float4 projPos : POSITION0;
	float3 worldPos : POSITION1;
	float2 texCoord : TEXCOORD0;

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif

	#if !DRAW_DEPTH_ONLY
		#if FLORA_LAYING
			float3 vegetationTexCoord : TEXCOORD2; // .z - layingStrength
		#else
			float2 vegetationTexCoord : TEXCOORD2;
		#endif

		#if FLORA_PBR_LIGHTING
			#if FLORA_NORMAL_MAP
				float4 tbnToWorld0 : TANGENTTOWORLD0; // .w - localHeight

				#if FLORA_FAKE_SHADOW && FLORA_ANIMATION
					float4 tbnToWorld1 : TANGENTTOWORLD1; // .w - animation.x
					float4 tbnToWorld2 : TANGENTTOWORLD2; // .w - animation.y
				#else
					float3 tbnToWorld1 : TANGENTTOWORLD1;
					float3 tbnToWorld2 : TANGENTTOWORLD2;
				#endif
			#else
				float4 normal : NORMAL; // .w - localHeight

				#if FLORA_ANIMATION && FLORA_FAKE_SHADOW
					float2 animation : TEXCOORD3;
				#endif
			#endif
		#endif
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if FLORA_PBR_LIGHTING
	uniform sampler2D baseColorMap;
#else
	uniform sampler2D albedo;
#endif

#if !DRAW_DEPTH_ONLY
	#if FLORA_PBR_LIGHTING
		uniform sampler2D floraLightmap;
		uniform sampler2D floraPbrColorMap;

		#if FLORA_EDGE_MAP
			uniform sampler2D floraEdgeMap;
		#endif

		#if FLORA_FAKE_SHADOW
			uniform sampler2D floraFakeShadow;
		#endif

		#if FLORA_NORMAL_MAP
			uniform sampler2D baseNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
		#endif
	#else
		uniform sampler2D floraColorMap;
	#endif
#endif

[auto][a] property float3 cameraPosition;

#if !DRAW_DEPTH_ONLY && FLORA_PBR_LIGHTING
	[auto][a] property float lightIntensity0;
	[auto][a] property float3 lightColor0;
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 invViewMatrix;

	[material][a] property float2 floraBottomOcclusionShadow;
	[material][a] property float2 floraRoughnessMetallic;
	[material][a] property float3 worldSize;

	#if FLORA_FAKE_SHADOW
		[material][a] property float floraFakeShadowIntensity;
		[material][a] property float2 floraFakeShadowAnimationFactor;
		[material][a] property float4 floraFakeShadowOffsetScale;
	#endif

	#if FLORA_NORMAL_MAP
		[material][a] property float floraNormalMapScale;
	#endif
#endif

#if !DRAW_DEPTH_ONLY && FLORA_LAYING
	#if FLORA_PBR_LIGHTING
		[material][a] property float3 floraLayingPbrColorFactor;
	#else
		[material][a] property float3 floraLayingColorFactor;
	#endif
#endif

#if (ALPHATEST || FLORA_LOD_TRANSITION) && ALPHATESTVALUE
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if FLORA_LOD_TRANSITION_NEAR
	[material][a] property float2 floraLodTransitionNearRange;
#endif

#if FLORA_LOD_TRANSITION_FAR
	[material][a] property float2 floraLodTransitionFarRange;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 projPos = input.projPos.xyz * (1.0 / input.projPos.w);

	#if FLORA_PBR_LIGHTING
		float4 baseColor = tex2D(baseColorMap, input.texCoord);
	#else
		float4 baseColor = tex2D(albedo, input.texCoord);
	#endif

	#if ALPHATEST || FLORA_LOD_TRANSITION
		#if ALPHATEST
			float alpha = baseColor.a;
		#else
			float alpha = 1.0;
		#endif

		#if FLORA_LOD_TRANSITION
			float toCamDis = length(input.worldPos.xy - cameraPosition.xy);

			#if FLORA_LOD_TRANSITION_NEAR
				alpha *= getLodTransition(projPos.xy, smoothstep(floraLodTransitionNearRange.x, floraLodTransitionNearRange.y, toCamDis));
			#endif

			#if FLORA_LOD_TRANSITION_FAR
				alpha *= getLodTransition(projPos.xy, smoothstep(floraLodTransitionFarRange.x, floraLodTransitionFarRange.y, toCamDis) - 1.0);
			#endif
		#endif

		#if ALPHATESTVALUE
			if (alpha < alphatestThreshold) discard;
		#else
			if (alpha < 0.5) discard;
		#endif
	#endif

	#if DRAW_DEPTH_ONLY
		float depthColor = projPos.z * 0.5 + 0.5;
		output.color = float4(depthColor, depthColor, depthColor, depthColor);
	#else
		#if RECEIVE_SHADOW
			float3 shadowInf = getShadow(input.worldPos, projPos.xy, 0.0);
		#endif

		#if FLORA_PBR_LIGHTING
			float4 floraColor = tex2D(floraPbrColorMap, input.vegetationTexCoord.xy);
			baseColor.rgb *= floraColor.rgb;
		#else
			float4 floraColor = tex2D(floraColorMap, input.vegetationTexCoord.xy);
			baseColor.rgb *= floraColor.rgb * floraColor.a;
		#endif

		#if FLORA_LAYING
			#if FLORA_PBR_LIGHTING;
				float3 layingColorFactor = floraLayingPbrColorFactor;
			#else
				float3 layingColorFactor = floraLayingColorFactor;
			#endif

			baseColor.rgb *= lerp(const1List3, layingColorFactor, input.vegetationTexCoord.z);
		#endif

		output.color = baseColor;

		#if FLORA_PBR_LIGHTING
			#if FLORA_NORMAL_MAP
				float3 baseNormal = unpackNormal(tex2D(baseNormalMap, input.texCoord).ga);
				baseNormal.xy *= floraNormalMapScale;

				float3 N = normalize(float3(dot(baseNormal, input.tbnToWorld0.xyz), dot(baseNormal, input.tbnToWorld1.xyz), dot(baseNormal, input.tbnToWorld2.xyz)));
				float3 polygonN = normalize(float3(input.tbnToWorld0.z, input.tbnToWorld1.z, input.tbnToWorld2.z));
			#else
				float3 N = normalize(input.normal.xyz);
				float3 polygonN = N;
			#endif

			#include "vector-compute.slh"

			float2 worldTexCoord = input.worldPos.xy * (1.0 / worldSize.xy) + const05List2;
			worldTexCoord.y = -worldTexCoord.y - 1.0;

			#if FLORA_EDGE_MAP
				float edgeFactor = tex2D(floraEdgeMap, worldTexCoord).r;
			#else
				float edgeFactor = 0.0;
			#endif

			#if FLORA_NORMAL_MAP
				float localHeight = input.tbnToWorld0.w;
			#else
				float localHeight = input.normal.w;
			#endif

			float2 lightmapDirAndAO = tex2D(floraLightmap, worldTexCoord).ga;
			float2 occlusionShadow = lerp(floraBottomOcclusionShadow, const1List2, lerp(localHeight, 1.0, edgeFactor));
			occlusionShadow.x *= lightmapDirAndAO.y;

			#if RECEIVE_SHADOW
				occlusionShadow.y *= lerp(lightmapDirAndAO.x, shadowInf.z, shadowInf.y);
			#else
				occlusionShadow.y *= lightmapDirAndAO.x;
			#endif

			#if FLORA_FAKE_SHADOW
				float2 fakeShadowTexCoord = input.texCoord * floraFakeShadowOffsetScale.zw + floraFakeShadowOffsetScale.xy;

				#if FLORA_ANIMATION
					#if FLORA_NORMAL_MAP
						float2 animation = float2(input.tbnToWorld1.w, input.tbnToWorld2.w);
					#else
						float2 animation = input.animation;
					#endif

					fakeShadowTexCoord += animation * (floraFakeShadowAnimationFactor * localHeight);
				#endif

				float fakeShadowIntensity = -edgeFactor * floraFakeShadowIntensity + floraFakeShadowIntensity;

				#if FLORA_LAYING
					fakeShadowIntensity -= fakeShadowIntensity * input.vegetationTexCoord.z;
				#endif

				occlusionShadow.y *= lerp(1.0, tex2D(floraFakeShadow, fakeShadowTexCoord).r, fakeShadowIntensity);
			#endif

			baseColor.rgb = saturate(baseColor.rgb);
			float roughness = saturate(floraRoughnessMetallic.x);
			occlusionShadow.x = saturate(occlusionShadow.x);

			output.color.rgb = getPBR(polygonN, N, V, L, H, lightColor0 * lightIntensity0, baseColor.rgb, floraRoughnessMetallic.y, roughness, occlusionShadow.x, occlusionShadow.y, const0List3);

			#include "color-grading.slh"
		#else
			#if RECEIVE_SHADOW
				output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
			#endif

			output.color.rgb = toLinear(output.color.rgb);

			#include "color-grading.slh"
		#endif

		#if USE_VERTEX_FOG
			output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
		#endif
	#endif

	return output;
}

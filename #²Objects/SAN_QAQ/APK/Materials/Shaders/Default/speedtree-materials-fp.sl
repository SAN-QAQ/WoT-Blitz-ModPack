#include "common.slh"
#include "blending.slh"

#if !DRAW_DEPTH_ONLY
	#if PBR_SPEEDTREE
		#include "pbr-lighting.slh"
	#endif

	#if RECEIVE_SHADOW
		#include "shadow-mapping.slh"
	#endif
#endif

#if LOD_TRANSITION
	#include "lod-transition.slh"
#endif

fragment_in
{
	#if LOD_TRANSITION || (!DRAW_DEPTH_ONLY && RECEIVE_SHADOW)
		float4 projPos : POSITION0;
	#endif

	#if !DRAW_DEPTH_ONLY
		#if RECEIVE_SHADOW
			float3 shadowWorldPos : POSITION1;
		#endif

		#if PBR_SPEEDTREE
			float4 tbnToWorld0 : TANGENTTOWORLD0;
			float4 tbnToWorld1 : TANGENTTOWORLD1;
			float4 tbnToWorld2 : TANGENTTOWORLD2;
		#endif
	#endif

	float2 texCoord : TEXCOORD0;

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif

	float4 vertexColor : COLOR0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if PBR_SPEEDTREE
	uniform sampler2D baseColorMap; // RGB - albedo color (SRGB), A - alpha
	uniform sampler2D baseNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
	uniform sampler2D roughnessAOMap; // RG or AG(DXT5NM) or GA(ASTC) - roughness / ambient occlusion
#else
	uniform sampler2D albedo;
#endif

#if PBR_SPEEDTREE
	[auto][a] property float lightIntensity0;
	[auto][a] property float3 cameraPosition;
	[auto][a] property float3 lightColor0;
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 invViewMatrix;

	[material][a] property float normalScale = 1.0;
	[material][a] property float metallness = 0.0;
	[material][a] property float pbrShadowLighten = 0.0;
	[material][a] property float2 pbrTextureAOBrightnessContrast = float2(0.0, 1.0);
#endif

#if ALPHABLEND && ALPHASTEPVALUE
	[material][a] property float alphaStepValue = 0.5;
#endif

#if ALPHATEST && ALPHATESTVALUE
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if FLATALBEDO || FLATCOLOR
	[material][a] property float4 flatColor = const1List4;
#endif

#if LOD_TRANSITION
	[material][a] property float lodTransitionThreshold = 0.0;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#if LOD_TRANSITION || (!DRAW_DEPTH_ONLY && RECEIVE_SHADOW)
		float2 projPos = input.projPos.xy * (1.0 / input.projPos.w);
	#endif

	#if PBR_SPEEDTREE
		float4 baseColor = tex2D(baseColorMap, input.texCoord);
	#else
		float4 baseColor = tex2D(albedo, input.texCoord);
	#endif

	#if !ALPHATEST && !ALPHABLEND
		#if TEST_OCCLUSION
			baseColor.rgb *= baseColor.a;
		#endif

		baseColor.a = 1.0;
	#endif

	#if FLATALBEDO
		baseColor *= flatColor;
	#endif

	#if LOD_TRANSITION
		baseColor.a *= getLodTransition(projPos, lodTransitionThreshold);
	#endif

	#if ALPHATEST
		float alpha = baseColor.a * input.vertexColor.a;

		#if ALPHATESTVALUE
			if (alpha < alphatestThreshold) discard;
		#else
			if (alpha < 0.5) discard;
		#endif
	#endif

	#if DRAW_DEPTH_ONLY
		output.color = const1List4;
	#else
		#if ALPHABLEND
			#if ALPHASTEPVALUE
				baseColor.a = step(alphaStepValue, baseColor.a);
			#endif
		#else
			baseColor.a = 1.0;
		#endif

		#if !PBR_SPEEDTREE
			baseColor *= input.vertexColor;
		#endif

		#if FLATCOLOR
			baseColor *= flatColor;
		#endif

		#if RECEIVE_SHADOW
			float3 shadowInf = getShadow(float3(0.0, 0.5, 0.0) * shadowNormalSlopeOffset + input.shadowWorldPos, projPos, 0.5);
		#endif

		output.color = baseColor;

		#if PBR_SPEEDTREE
			float2 roughnessAO = tex2D(roughnessAOMap, input.texCoord).ga;
			float3 tangentNormal = unpackNormal(tex2D(baseNormalMap, input.texCoord).ga);
			tangentNormal.xy *= normalScale;

			float3 polygonN = normalize(float3(input.tbnToWorld0.z, input.tbnToWorld1.z, input.tbnToWorld2.z));
			float3 N = normalize(float3(dot(tangentNormal, input.tbnToWorld0.xyz), dot(tangentNormal, input.tbnToWorld1.xyz), dot(tangentNormal, input.tbnToWorld2.xyz)));
			float3 L = normalize(mul3Fast0(lightPosition0.xyz, invViewMatrix));
			float3 V = normalize(cameraPosition - float3(input.tbnToWorld0.w, input.tbnToWorld1.w, input.tbnToWorld2.w));
			float3 H = normalize(L + V);

			float occlusion = dot(input.vertexColor.rgb, rgbMixList) * saturate(pbrTextureAOBrightnessContrast.y * (roughnessAO.y - 0.5) + (0.5 + pbrTextureAOBrightnessContrast.x));

			#if RECEIVE_SHADOW
				float shadow = lerp(shadowInf.x, 1.0, pbrShadowLighten);
			#else
				float shadow = 1.0;
			#endif

			baseColor.rgb = saturate(baseColor.rgb);
			roughnessAO.x = saturate(roughnessAO.x);

			output.color.rgb = getPBR(polygonN, N, V, L, H, lightColor0 * lightIntensity0, baseColor.rgb, metallness, roughnessAO.x, occlusion, shadow, const0List3);

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

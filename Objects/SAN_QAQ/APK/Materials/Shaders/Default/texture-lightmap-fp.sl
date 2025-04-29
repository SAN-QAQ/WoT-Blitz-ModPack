#define SHADOW_RECEIVER 1

#include "common.slh"
#include "blending.slh"

#if ENVIRONMENT_MAPPING
	#include "lighting.slh"
#endif

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

fragment_in
{
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

fragment_out
{
	float4 color : SV_TARGET0;
};

#if ENVIRONMENT_MAPPING
	uniform sampler2D envReflectionMask;
	uniform samplerCUBE cubemap;
#endif

#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
	uniform sampler2D lightmap;
#endif

#if MATERIAL_TEXTURE
	uniform sampler2D albedo;

	#if ALPHABLEND && ALPHASTEPVALUE
		[material][a] property float alphaStepValue = 0.5;
	#endif

	#if ALPHATEST && ALPHATESTVALUE
		[material][a] property float alphatestThreshold = 0.0;
	#endif
#endif

#if ENVIRONMENT_MAPPING
	[auto][a] property float3 lightColor0;

	[material][a] property float reflectionAddDiffuse = 0.025;
	[material][a] property float reflectionLerpEnvMap = 0.5;
	[material][a] property float reflectionMaskMultiplier = 100.0;
	[material][a] property float reflectionMultLightmap = 2.0;
	[material][a] property float reflectionSpecParamGloss = 0.45;
	[material][a] property float3 cubemapIntensity = const1List3;
#endif

#if FLATALBEDO || FLATCOLOR
	[material][a] property float4 flatColor = const1List4;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 projPos = input.projPos.xy * (1.0 / input.projPos.w);
	float4 outColor = const1List4;

	#if MATERIAL_TEXTURE
		float4 albedoSample = tex2D(albedo, input.texCoord.xy);

		#if ALPHATEST || ALPHABLEND
			outColor = albedoSample;
		#elif TEST_OCCLUSION
			outColor.rgb = albedoSample.rgb * albedoSample.a;
		#else
			outColor.rgb = albedoSample.rgb;
		#endif
	#endif

	#if FLATALBEDO
		outColor *= flatColor;
	#endif

	#if MATERIAL_TEXTURE
		#if ALPHATEST
			#if ALPHATESTVALUE
				if (outColor.a < alphatestThreshold) discard;
			#else
				if (outColor.a < 0.5) discard;
			#endif
		#endif

		#if ALPHABLEND && ALPHASTEPVALUE
			outColor.a = step(alphaStepValue, outColor.a);
		#endif
	#endif

	#if RECEIVE_SHADOW
		float3 shadowInf = getShadow(input.worldNormalNdotL.xyz * (shadowNormalSlopeOffset * input.worldNormalNdotL.w) + input.worldPos, projPos, input.worldNormalNdotL.w);
	#endif

	#if MATERIAL_LIGHTMAP
		#if VIEW_ALBEDO
			output.color.rgb = outColor.rgb;
		#else
			output.color.rgb = const1List3;
		#endif

		#if VIEW_DIFFUSE
			float3 diffuse = tex2D(lightmap, input.texCoord.zw).rgb;

			#if RECEIVE_SHADOW
				diffuse *= lerp(shadowMapShadowColor.rgb * lerp(shadowLMGateFactor.y, 1.0, saturate(dot(diffuse, rgbMixList) * shadowLMGateFactor.x)), const1List3, shadowInf.x);
			#endif
			
			#if VIEW_ALBEDO
				output.color.rgb *= diffuse * 2.0;
			#else
				output.color.rgb *= diffuse;
			#endif
		#endif
	#elif MATERIAL_TEXTURE
		output.color.rgb = outColor.rgb;

		#if RECEIVE_SHADOW
			output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
		#endif
	#else
		output.color.rgb = const1List3;
	#endif

	#if ENVIRONMENT_MAPPING
		float envMaskValue = tex2D(envReflectionMask, input.texCoord.xy).a;
		float maskScaled = min(1.0, envMaskValue * reflectionMaskMultiplier);

		#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
			float3 lightenLM = saturate(diffuse * reflectionMultLightmap);
		#else
			float3 lightenLM = float3(reflectionMultLightmap, reflectionMultLightmap, reflectionMultLightmap);
		#endif

		output.color.rgb = lightColor0 * input.specularVector.xyz * (getBlinnPhongSpecular(input.specularVector.w, reflectionSpecParamGloss * envMaskValue) * maskScaled) + lerp(output.color.rgb, output.color.rgb * reflectionAddDiffuse + texCUBE(cubemap, input.reflectionVector.xyz).xyz * cubemapIntensity * lightenLM * (maskScaled * input.reflectionVector.w), min(1.0, envMaskValue * reflectionLerpEnvMap));
	#endif

	output.color.rgb = toLinear(output.color.rgb);

	#include "color-grading.slh"

	#if ALPHABLEND && MATERIAL_TEXTURE
		output.color.a = outColor.a;
	#else
		output.color.a = 1.0;
	#endif

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	return output;
}

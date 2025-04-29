#include "common.slh"
#include "blending.slh"
#include "highlight-animation.slh"

#if ENVIRONMENT_MAPPING
	#include "lighting.slh"
#endif

#if LOD_TRANSITION
	#include "lod-transition.slh"
#endif

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

fragment_in
{
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

fragment_out
{
	float4 color : SV_TARGET0;
};

#if ALPHA_MASK
	uniform sampler2D alphamask;
#endif

#if ENVIRONMENT_MAPPING
	uniform sampler2D envReflectionMask;
	uniform samplerCUBE cubemap;
#endif

#if FLOWMAP
	uniform sampler2D flowmap;
#endif

#if MATERIAL_DECAL
	uniform sampler2D decal;
#endif

#if MATERIAL_DETAIL
	uniform sampler2D detail;
#endif

#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
	uniform sampler2D lightmap;
#endif

#if MATERIAL_TEXTURE
	uniform sampler2D albedo;
#endif

#if TILED_DECAL_MASK
	uniform sampler2D decalmask;
	uniform sampler2D decaltexture;
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

#if LOD_TRANSITION || MATERIAL_TEXTURE
	#if ALPHABLEND && ALPHASTEPVALUE
		[material][a] property float alphaStepValue = 0.5;
	#endif

	#if ALPHATEST && ALPHATESTVALUE
		[material][a] property float alphatestThreshold = 0.0;
	#endif
#endif

#if BLEND_BY_ANGLE
	[material][a] property float angleBlendPower = 1.0;
	[material][a] property float angleBlendInversion = 0.0;
	[material][a] property float2 angleBlendBounds = float2(0.0, 1.0);
#endif

#if FLATCOLOR || FLATALBEDO
	[material][a] property float4 flatColor = const1List4;
#endif

#if LOD_TRANSITION
	[material][a] property float lodTransitionThreshold = 0.0;
#endif

#if SETUP_LIGHTMAP && (MATERIAL_DECAL || MATERIAL_LIGHTMAP)
	[material][a] property float lightmapSize = 1.0;
#endif

#if TILED_DECAL_MASK
	[material][a] property float4 decalTileColor = const1List4;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 projPos = input.projPos.xy * (1.0 / input.projPos.w);
	float4 outColor = const1List4;

	#if MATERIAL_TEXTURE
		#if FLOWMAP
			float2 flowDir = tex2D(flowmap, input.texCoord0.zw).xy * 2.0 - const1List2;

			float4 albedoSample = lerp(tex2D(albedo, flowDir * input.flowData.x + input.texCoord0.zw), tex2D(albedo, flowDir * input.flowData.y + input.texCoord0.zw), input.flowData.z);
		#else
			float4 albedoSample = tex2D(albedo, input.texCoord0.zw);
		#endif

		#if ALPHATEST || ALPHABLEND
			outColor = albedoSample;

			#if ALPHA_MASK 
				outColor.a *= tex2D(alphamask, input.texCoord0.xy).a;
			#endif
		#elif TEST_OCCLUSION
			outColor.rgb = albedoSample.rgb * albedoSample.a;
		#else
			outColor.rgb = albedoSample.rgb;
		#endif
	#endif

	#if FLATALBEDO
		outColor *= flatColor;
	#endif

	#if LOD_TRANSITION
		outColor.a *= getLodTransition(projPos, lodTransitionThreshold);
	#endif

	#if LOD_TRANSITION || MATERIAL_TEXTURE
		#if ALPHATEST
			float alpha = outColor.a;

			#if VERTEX_COLOR
				alpha *= input.vertexColor.a;
			#endif

			#if ALPHATESTVALUE
				if (alpha < alphatestThreshold) discard;
			#else
				if (alpha < 0.5) discard;
			#endif
		#endif

		#if ALPHABLEND && ALPHASTEPVALUE
			outColor.a = step(alphaStepValue, outColor.a);
		#endif
	#endif

	#if (MATERIAL_DECAL || MATERIAL_LIGHTMAP) && VIEW_DIFFUSE
		float3 diffuse = const1List3;

		#if MATERIAL_DECAL
			float4 decalColor = tex2D(decal, input.texCoord0.xy);
			diffuse *= decalColor.rgb;
		#endif

		#if MATERIAL_LIGHTMAP
			diffuse *= tex2D(lightmap, input.texCoord0.xy).rgb;
		#endif

		#if SETUP_LIGHTMAP
			float2 oddXY = step(const05List2, frac(input.texCoord0.xy * (aLightmapSize * 0.5)));

			diffuse = -const05List3 * abs(oddXY.x - oddXY.y) + float3(0.75, 0.75, 0.75);
		#endif
	#endif

	#if RECEIVE_SHADOW
		float3 shadowInf = getShadow(input.worldNormalNdotL.xyz * (shadowNormalSlopeOffset * input.worldNormalNdotL.w) + input.worldPos, projPos, input.worldNormalNdotL.w);
	#endif

	#if MATERIAL_DECAL || MATERIAL_LIGHTMAP
		#if VIEW_ALBEDO
			output.color.rgb = outColor.rgb;
		#else
			output.color.rgb = const1List3;
		#endif

		#if VIEW_DIFFUSE
			float3 diffuseColor = diffuse;

			#if RECEIVE_SHADOW
				#if MATERIAL_DECAL && LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL
					float lmValue = lerp(shadowLMGateFactor.w, 1.0, saturate(decalColor.a * shadowLMGateFactor.z)) * decalColor.a;
				#else
					float lmValue = lerp(shadowLMGateFactor.y, 1.0, saturate(dot(diffuseColor, rgbMixList) * shadowLMGateFactor.x));
				#endif

				diffuseColor *= lerp(shadowMapShadowColor.rgb * lmValue, const1List3, shadowInf.x);
			#elif MATERIAL_DECAL && LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL
				diffuseColor *= decalColor.a;
			#endif
			
			#if VIEW_ALBEDO
				output.color.rgb *= diffuseColor * 2.0;
			#else
				output.color.rgb *= diffuseColor;
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
		float envMaskValue = tex2D(envReflectionMask, input.texCoord0.zw).a;
		float maskScaled = min(1.0, envMaskValue * reflectionMaskMultiplier);

		#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
			float3 lightenLM = saturate(diffuse * reflectionMultLightmap);
		#else
			float3 lightenLM = float3(reflectionMultLightmap, reflectionMultLightmap, reflectionMultLightmap);
		#endif

		output.color.rgb = lightColor0 * input.specularVector.xyz * (getBlinnPhongSpecular(input.specularVector.w, reflectionSpecParamGloss * envMaskValue) * maskScaled) + lerp(output.color.rgb, output.color.rgb * reflectionAddDiffuse + texCUBE(cubemap, input.reflectionVector.xyz).xyz * cubemapIntensity * lightenLM * (maskScaled * input.reflectionVector.w), min(1.0, envMaskValue * reflectionLerpEnvMap));
	#endif

	#if TILED_DECAL_MASK
		float4 tileColor = tex2D(decaltexture, input.texCoord1.xy) * decalTileColor;
		output.color.rgb += (tileColor.rgb - output.color.rgb) * (tileColor.a * tex2D(decalmask, input.texCoord0.zw).a);
	#endif

	#if MATERIAL_DETAIL
		output.color.rgb *= tex2D(detail, input.texCoord1.zw).rgb * 2.0;
	#endif

	output.color.rgb = toLinear(output.color.rgb);

	#include "color-grading.slh"

	#if ALPHABLEND && MATERIAL_TEXTURE
		output.color.a = outColor.a;
	#else
		output.color.a = 1.0;
	#endif

	#if VERTEX_COLOR
		output.color *= input.vertexColor;
	#endif

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	#if HIGHLIGHT_COLOR || HIGHLIGHT_WAVE_ANIM
		output.color = getHighlightAnim(output.color, input.worldPos.z);
	#endif

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	#if BLEND_BY_ANGLE
		float NdotV = abs(dot(input.worldNormalNdotL.xyz, input.worldView)) * (1.0 / (length(input.worldNormalNdotL.xyz) * length(input.worldView)));
		output.color.a *= pow(saturate((lerp(NdotV, 1.0 - NdotV, angleBlendInversion) - angleBlendBounds.x) * (1.0 / (angleBlendBounds.y - angleBlendBounds.x))), angleBlendPower);
	#endif

	return output;
}

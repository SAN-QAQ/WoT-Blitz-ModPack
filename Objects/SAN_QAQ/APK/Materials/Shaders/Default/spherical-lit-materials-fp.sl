#include "common.slh"
#include "blending.slh"

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

#if LOD_TRANSITION
	#include "lod-transition.slh"
#endif

fragment_in
{
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

	float3 sphericalLightFactor : COLOR0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if ALPHA_MASK
	uniform sampler2D alphamask;
#endif

#if FLOWMAP
	uniform sampler2D flowmap;
#endif

#if MATERIAL_TEXTURE
	uniform sampler2D albedo;
#endif

#if MATERIAL_DECAL
	uniform sampler2D decal;
#endif

#if MATERIAL_DETAIL
	uniform sampler2D detail;
#endif

#if TILED_DECAL_MASK
	uniform sampler2D decalmask;
	uniform sampler2D decaltexture;

	[material][a] property float4 decalTileColor = const1List4;
#endif

#if LOD_TRANSITION
	[material][a] property float lodTransitionThreshold = 0.0;
#endif

#if LOD_TRANSITION || MATERIAL_TEXTURE
	#if ALPHABLEND && ALPHASTEPVALUE
		[material][a] property float alphaStepValue = 0.5;
	#endif

	#if ALPHATEST && ALPHATESTVALUE
		[material][a] property float alphatestThreshold = 0.0;
	#endif
#endif

#if FLATCOLOR || FLATALBEDO
	[material][a] property float4 flatColor = const1List4;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 projPos = input.projPos.xy * (1.0 / input.projPos.w);
	float4 textureColor0 = const1List4;

	#if MATERIAL_TEXTURE
		#if FLOWMAP
			float2 flowDir = tex2D(flowmap, input.texCoord0.xy).xy * 2.0 - const1List2;

			float4 albedoSample = lerp(tex2D(albedo, flowDir * input.flowData.x + input.texCoord0.xy), tex2D(albedo, flowDir * input.flowData.y + input.texCoord0.xy), input.flowData.z);
		#else
			float4 albedoSample = tex2D(albedo, input.texCoord0.xy);
		#endif

		#if ALPHATEST || ALPHABLEND
			textureColor0 = albedoSample;

			#if ALPHA_MASK 
				textureColor0.a *= tex2D(alphamask, input.texCoord0.zw).a;
			#endif
		#elif TEST_OCCLUSION
			textureColor0.rgb = albedoSample.rgb * albedoSample.a;
		#else
			textureColor0.rgb = albedoSample.rgb;
		#endif
	#endif

	#if FLATALBEDO
		textureColor0 *= flatColor;
	#endif

	#if LOD_TRANSITION
		textureColor0.a *= getLodTransition(projPos, lodTransitionThreshold);
	#endif

	#if LOD_TRANSITION || MATERIAL_TEXTURE
		#if ALPHATEST
			float alpha = textureColor0.a;

			#if ALPHATESTVALUE
				if (alpha < alphatestThreshold) discard;
			#else
				if (alpha < 0.5) discard;
			#endif
		#endif

		#if ALPHASTEPVALUE && ALPHABLEND
			textureColor0.a = step(alphaStepValue, textureColor0.a);
		#endif
	#endif

	#if MATERIAL_DECAL
		float3 decalColor = tex2D(decal, input.texCoord0.zw).rgb;

		#if VIEW_ALBEDO
			output.color.rgb = decalColor;
		#else
			output.color.rgb = const1List3;
		#endif

		#if VIEW_DIFFUSE
			#if VIEW_ALBEDO
				output.color.rgb *= decalColor * 2.0;
			#else
				output.color.rgb *= decalColor;
			#endif
		#endif
	#elif MATERIAL_TEXTURE
		output.color.rgb = textureColor0.rgb;
	#else
		output.color.rgb = const1List3;
	#endif

	#if TILED_DECAL_MASK
		float4 tileColor = tex2D(decaltexture, input.texCoord1.zw) * decalTileColor;
		output.color.rgb += (tileColor.rgb - output.color.rgb) * (tileColor.a * tex2D(decalmask, input.texCoord0.xy).a);
	#endif

	#if MATERIAL_DETAIL
		output.color.rgb *= tex2D(detail, input.texCoord1.xy).rgb * 2.0;
	#endif

	#if ALPHABLEND && MATERIAL_TEXTURE
		output.color.a = textureColor0.a;
	#else
		output.color.a = 1.0;
	#endif

	output.color.rgb *= input.sphericalLightFactor;

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	#if RECEIVE_SHADOW
		float3 shadowInf = getShadow(float3(0.0, 0.5, 0.0) * shadowNormalSlopeOffset + input.worldPos, projPos, 0.5);
		output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
	#endif

	output.color.rgb = toLinear(output.color.rgb);

	#include "color-grading.slh"

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	return output;
}

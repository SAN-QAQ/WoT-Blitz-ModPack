#define SHADOW_RECEIVER 1

#include "common.slh"
#include "blending.slh"

#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
	#include "depth-fetch.slh"
#endif

fragment_in
{
	#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
		float4 projPos : POSITION0;
	#endif

	float4 vertexColor : COLOR0;

	#if RECEIVE_SHADOW
		float3 shadowColor : COLOR1;
	#endif

	#if PARTICLES_MASK
		float4 texCoord0 : TEXCOORD0;
	#else
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if FRAME_BLEND
		float3 texCoord1 : TEXCOORD1;
	#endif

	#if PARTICLES_FLOWMAP
		float4 texCoord2 : TEXCOORD2;
		float texCoord3 : TEXCOORD3;
	#endif

	#if PARTICLES_NOISE
		#if PARTICLES_FRESNEL_TO_ALPHA
			float4 texCoord4 : TEXCOORD4; // xy - noise uv, z - noise scale, w - fresnel.
		#else
			float3 texCoord4 : TEXCOORD4; // xy - noise uv, z - noise scale.
		#endif
	#elif PARTICLES_FRESNEL_TO_ALPHA
		float texCoord4 : TEXCOORD4; // Fresnel.
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD5;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D albedo;

#if PARTICLES_FLOWMAP
	uniform sampler2D flowmap;
#endif

#if PARTICLES_MASK
	uniform sampler2D mask;
#endif

#if PARTICLES_NOISE
	uniform sampler2D noiseTex;
#endif

#if ALPHABLEND
	#if ALPHA_EROSION
		[material][a] property float alphaErosionAcceleration = 2.0;
	#endif

	#if ALPHASTEPVALUE
		[material][a] property float alphaStepValue = 0.5;
	#endif
#endif

#if ALPHATEST && ALPHATESTVALUE
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if FLATCOLOR || FLATALBEDO
	[material][a] property float4 flatColor = const1List4;
#endif

#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
	[material][a] property float depthDifferenceSlope = 2.0;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#if PARTICLES_FLOWMAP
		float2 flowDir = tex2D(flowmap, input.texCoord2.xy).xy * 2.0 - const1List2;
	#endif

	float4 textureColor0 = const1List4;

	#if ALPHATEST || ALPHABLEND
		#if PARTICLES_FLOWMAP
			#if PARTICLES_NOISE
				flowDir *= tex2D(noiseTex, input.texCoord4.xy).r * input.texCoord4.z;
			#endif

			textureColor0 = lerp(tex2D(albedo, flowDir * input.texCoord2.z + input.texCoord0.xy), tex2D(albedo, flowDir * input.texCoord2.w + input.texCoord0.xy), input.texCoord3);
		#else
			float2 albedoTexCoord = input.texCoord0.xy;

			#if PARTICLES_NOISE
				float2 noiseSample = tex2D(noiseTex, input.texCoord4.xy).rr * 2.0 - const1List2;

				albedoTexCoord += noiseSample * input.texCoord4.z;
			#endif

			textureColor0 = tex2D(albedo, albedoTexCoord);
		#endif
	#else
		#if PARTICLES_FLOWMAP
			textureColor0.rgb = lerp(tex2D(albedo, flowDir * input.texCoord2.z + input.texCoord0.xy).rgb, tex2D(albedo, flowDir * input.texCoord2.w + input.texCoord0.xy).rgb, input.texCoord3);
		#else
			float4 albedoSample = tex2D(albedo, input.texCoord0.xy);
			textureColor0.rgb = albedoSample.rgb;

			#if TEST_OCCLUSION
				textureColor0.rgb *= albedoSample.a;
			#endif
		#endif
	#endif

	#if FRAME_BLEND
		textureColor0 = lerp(textureColor0, tex2D(albedo, input.texCoord1.xy), input.texCoord1.z);
	#endif

	#if FLATALBEDO
		textureColor0 *= flatColor;
	#endif

	#if ALPHATEST
		float alpha = textureColor0.a * input.vertexColor.a;

		#if ALPHATESTVALUE
			if (alpha < alphatestThreshold) discard;
		#else
			if (alpha < 0.5) discard;
		#endif
	#endif

	#if ALPHABLEND
		#if ALPHASTEPVALUE
			textureColor0.a = step(alphaStepValue, textureColor0.a);
		#endif
	#else
		textureColor0.a = 1.0;
	#endif

	output.color = textureColor0 * input.vertexColor;

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	#if PARTICLES_MASK
		output.color *= tex2D(mask, input.texCoord0.zw);
	#endif

	#if ALPHABLEND && ALPHA_EROSION
		float srcA = tex2D(albedo, input.texCoord0.xy).a;
		float opacity = saturate(1.0 - input.vertexColor.a);
		output.color.a = (srcA * alphaErosionAcceleration - alphaErosionAcceleration) * opacity + (srcA - opacity);
	#endif

	#if PARTICLES_FRESNEL_TO_ALPHA
		#if PARTICLES_NOISE
			output.color.a *= input.texCoord4.w;
		#else
			output.color.a *= input.texCoord4;
		#endif
	#endif

	#if RECEIVE_SHADOW
		output.color.rgb *= input.shadowColor;
	#endif

	output.color.rgb = toLinear(output.color.rgb);

	#include "color-grading.slh"

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
		float3 projPos = input.projPos.xyz * (1.0 / input.projPos.w);

		#include "depth-diff.slh"

		float scale = 1.0 - exp2((-depthDifferenceSlope * _LOG2_E) * (distanceDifference * distanceDifference));

		#if BLENDING == BLENDING_ADDITIVE
			output.color *= scale;
		#else
			output.color.a *= scale;
		#endif
	#endif

	return output;
}

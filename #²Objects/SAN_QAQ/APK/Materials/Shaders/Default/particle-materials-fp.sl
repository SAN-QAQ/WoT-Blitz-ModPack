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

	#if !DRAW_WATER_DEFORMATION && RECEIVE_SHADOW
		float3 shadowColor : COLOR1;
	#endif

	#if PARTICLES_PERSPECTIVE_MAPPING
		float3 texCoord0 : TEXCOORD0;
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
			float4 texCoord4 : TEXCOORD4; // Noise uv and scale. Fresnel a.
		#else
			float3 texCoord4 : TEXCOORD4; // Noise uv and scale.
		#endif
	#elif PARTICLES_FRESNEL_TO_ALPHA
		float texCoord4 : TEXCOORD4; // Fresnel a.
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

#if PARTICLES_NOISE
	uniform sampler2D noiseTex;
#endif

#if DRAW_WATER_DEFORMATION
	[auto][a] property float4 waterDeformationParams; // xy - fadeOutRange, z - maxDeformation, w - cameraBias
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

#if BLENDING == BLENDING_FUSE_BLEND_ADD
	[material][a] property float2 fuseBlendAddEdges = float2(0.45, 0.55);
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

	float4 textureColor0 = const1List4;

	#if PARTICLES_FLOWMAP
		float2 flowDir = tex2D(flowmap, input.texCoord2.xy).xy * 2.0 - const1List2;
	#endif

	#if ALPHATEST || ALPHABLEND
		#if PARTICLES_FLOWMAP
			#if PARTICLES_NOISE
				flowDir *= tex2D(noiseTex, input.texCoord4.xy).r * input.texCoord4.z;
			#endif

			textureColor0 = lerp(tex2D(albedo, flowDir * input.texCoord2.z + input.texCoord0.xy), tex2D(albedo, flowDir * input.texCoord2.w + input.texCoord0.xy), input.texCoord3);
		#else
			float2 albedoTexCoord = input.texCoord0.xy;

			#if PARTICLES_NOISE
				#if PARTICLES_PERSPECTIVE_MAPPING
					float2 noiseSample = tex2D(noiseTex, input.texCoord4.xy * (1.0 / input.texCoord0.z)).rr * 2.0 - const1List2;
					noiseSample *= input.texCoord0.z;
				#else
					float2 noiseSample = tex2D(noiseTex, input.texCoord4.xy).rr * 2.0 - const1List2;
				#endif

				albedoTexCoord += noiseSample * input.texCoord4.z;
			#endif

			#if PARTICLES_PERSPECTIVE_MAPPING
				textureColor0 = tex2D(albedo, albedoTexCoord * (1.0 / input.texCoord0.z));
			#else
				textureColor0 = tex2D(albedo, albedoTexCoord);
			#endif
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
		#if PARTICLES_PERSPECTIVE_MAPPING
			float4 frameBlendColor = tex2D(albedo, input.texCoord1.xy * (1.0 / input.texCoord0.z));
		#else
			float4 frameBlendColor = tex2D(albedo, input.texCoord1.xy);
		#endif

		textureColor0 = lerp(textureColor0, frameBlendColor, input.texCoord1.z);
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

	output.color = textureColor0;

	#if DRAW_WATER_DEFORMATION
		output.color.r = output.color.r * 2.0 - 1.0;
	#endif

	output.color *= input.vertexColor;

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	#if DRAW_WATER_DEFORMATION
		output.color.rg *= output.color.a;
		output.color.r = clamp(output.color.r * (1.0 / waterDeformationParams.z), -1.0, 1.0);
		output.color.b = -min(output.color.r, 0.0);
		output.color.r = max(output.color.r, 0.0);
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

	#if !DRAW_WATER_DEFORMATION && RECEIVE_SHADOW
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

	#if BLENDING == BLENDING_FUSE_BLEND_ADD
		output.color.rgb *= output.color.a;
		output.color.a -= output.color.a * smoothstep(fuseBlendAddEdges.x, fuseBlendAddEdges.y, output.color.a);
	#endif

	return output;
}

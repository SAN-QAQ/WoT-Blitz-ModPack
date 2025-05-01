#include "common.slh"

#ensuredefined VEGETATION_LIT 0

#if !DRAW_DEPTH_ONLY && VEGETATION_LIT
	#include "fresnel-shlick.slh"
	#include "lighting.slh"
#endif

#if USE_SHADOW_MAP
	#include "shadow-mapping.slh"
#endif

fragment_in
{
	#if !DRAW_DEPTH_ONLY
		float3 vegetationColor : COLOR0;

		#if USE_SHADOW_MAP
			float4 projPos : POSITION0;
		#endif

		float3 worldPos : POSITION1;
		float2 texCoord : TEXCOORD0;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if !DRAW_DEPTH_ONLY
	uniform sampler2D albedo;

	#if VEGETATION_LIT
		uniform sampler2D normalmap;

		[auto][a] property float3 lightColor0;
		[auto][a] property float3 cameraPosition;
		[auto][a] property float4 lightPosition0;
		[auto][a] property float4x4 invViewMatrix;

		[material][a] property float inGlossiness = 0.35;
		[material][a] property float inSpecularity = 0.95;
		[material][a] property float normalScale = 1.0;
		[material][a] property float3 metalFresnelReflectance = float3(0.562, 0.565, 0.578);

		#if USE_SHADOW_MAP
			[material][a] property float2 grassShadowDiffuseSpecMult = const05List2;
		#endif
	#endif

	[material][a] property float grassBaseColorMult = 2.0;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = const1List4;

	#if !DRAW_DEPTH_ONLY
		output.color = tex2D(albedo, input.texCoord);

		#if USE_SHADOW_MAP
			float3 shadowInf = getShadow(input.worldPos, input.projPos.xy * (1.0 / input.projPos.w), 0.0);
			float3 shadowColor = lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
		#endif

		#if VEGETATION_LIT
			float3 N = tex2D(normalmap, input.texCoord0.xy).rgb;
			N = mixNormal(N, N);
			N.xy *= normalScale;
			N = normalize(N);

			#include "vector-compute.slh"

			float NdotL = saturate(dot(N, L));
			float NdotV = saturate(dot(N, V));
			float NdotH = saturate(dot(N, H));

			float3 diffuse = lightColor0 * (NdotL * _INVERSE_PI);
			float3 specular = lightColor0 * ((getBlinnPhongSpecular(NdotH, inGlossiness * output.color.a) * fresnel(NdotV, dot(metalFresnelReflectance, rgbMixList))) * (inSpecularity * NdotL));

			#if USE_SHADOW_MAP
				float2 diffuseSpecularShadowTerm = -grassShadowDiffuseSpecMult * shadowInf.x + (grassShadowDiffuseSpecMult + shadowInf.xx);
				output.color.rgb = output.color.rgb * input.vegetationColor * shadowColor * grassBaseColorMult + (diffuse * diffuseSpecularShadowTerm.x + specular * diffuseSpecularShadowTerm.y);
			#else
				output.color.rgb = output.color.rgb * input.vegetationColor * grassBaseColorMult + (diffuse + specular);
			#endif
		#else
			output.color.rgb *= input.vegetationColor * grassBaseColorMult;

			#if USE_SHADOW_MAP
				output.color.rgb *= shadowColor;
			#endif
		#endif

		output.color.rgb = toLinear(output.color.rgb);

		#include "color-grading.slh"

		#if USE_VERTEX_FOG
			output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
		#endif
	#endif

	return output;
}

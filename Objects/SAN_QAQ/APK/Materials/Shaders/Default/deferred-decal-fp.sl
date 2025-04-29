#include "common.slh"
#include "blending.slh"

#ensuredefined DECAL_VERTICAL_FADE 0

#define DRAW_FLORA_LAYING (PASS_NAME == PASS_FLORALAYING)

#if !DRAW_FLORA_LAYING
	#include "depth-fetch.slh"

	#if RECEIVE_SHADOW
		#include "shadow-mapping.slh"
	#endif
#endif

fragment_in
{
	float4 projPos : POSITION0;

	#if DRAW_FLORA_LAYING
		float3 worldDirStrength : TEXCOORD0;
	#else
		float4 invWorldMatrix0 : TEXCOORD0;
		float4 invWorldMatrix1 : TEXCOORD1;
		float4 invWorldMatrix2 : TEXCOORD2;
		float4 parameters : TEXCOORD3;
		float4 texCoord : TEXCOORD4;

		#if USE_VERTEX_FOG
			float4 varFog : TEXCOORD5;
		#endif
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if !DRAW_FLORA_LAYING
	uniform sampler2D albedo;

	[auto][a] property float4x4 invViewMatrix;
#endif

#if ALPHATEST
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if DECAL_VERTICAL_FADE
	[material][a] property float invDecalVerticalFadeWidth = 0.0;
#endif

#if FLATCOLOR
	[material][a] property float4 flatColor = const1List4;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 projPos = input.projPos.xyz * (1.0 / input.projPos.w);

	#if DRAW_FLORA_LAYING
		output.color = float4(input.worldDirStrength, projPos.z * 0.5 + 0.5);
	#else
		#include "deferred-pos.slh"

		#if DECAL_TREAD
			float revertedOffsetY = -input.parameters.w * localPos.x + (input.parameters.w * 0.5 + localPos.y);
			localPos.y = revertedOffsetY * (1.0 / lerp(1.0, input.parameters.z, localPos.x + 0.5));
		#endif

		float2 albedoTexCoord = float2(input.texCoord.zw * localPos.xy + (input.texCoord.zw * 0.5 + input.texCoord.xy));
		float3 localPosAbs = abs(localPos);
		float3 localPosAbsStep = step(localPosAbs, const05List3);

		#if ALBEDO_TRANSFORM
			albedoTexCoord.y *= input.parameters.y;
		#endif

		float opacity = localPosAbsStep.x * localPosAbsStep.y * input.parameters.x;

		#if DECAL_VERTICAL_FADE
			localPosAbs.z += localPosAbs.z;
			opacity *= min(1.0, -localPosAbs.z * invDecalVerticalFadeWidth + invDecalVerticalFadeWidth);
		#else
			opacity *= localPosAbsStep.z;
		#endif

		output.color = tex2D(albedo, albedoTexCoord);
		output.color.a *= opacity;

		#if FLATCOLOR
			output.color *= flatColor;
		#endif

		#if ALPHATEST
			if (output.color.a < alphatestThreshold) discard;
		#endif

		#if RECEIVE_SHADOW
			float3 shadowInf = getShadow(worldPos, projPos.xy, 0.0);
			output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
		#endif

		output.color.rgb = toLinear(output.color.rgb);

		#include "color-grading.slh"

		#if USE_VERTEX_FOG
			output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
		#endif

		#if BLENDING == BLENDING_MULTIPLICATIVE
			output.color.rgb = lerp(const1List3, output.color.rgb, output.color.a);
		#endif
	#endif

	return output;
}

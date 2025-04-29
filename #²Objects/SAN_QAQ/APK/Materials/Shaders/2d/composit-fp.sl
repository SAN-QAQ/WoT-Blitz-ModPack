#include "common.slh"

#define GRADIENT_MULTIPLY 0
#define GRADIENT_BLEND 1
#define GRADIENT_ADD 2
#define GRADIENT_SCREEN 3
#define GRADIENT_OVERLAY 4

#ifndef GRADIENT_MODE
	#define GRADIENT_MODE GRADIENT_MULTIPLY
#endif

#if COLORBLIND_MODE
	#include "colorblind-mode.slh"
#endif

blending { src=one dst=inv_src_alpha }

fragment_in
{
	float4 texCoord0 : TEXCOORD0;
	float4 texCoord1 : TEXCOORD1;
	float4 color : COLOR0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D mask;
uniform sampler2D detail;
uniform sampler2D gradient;
uniform sampler2D contour;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 detailImpact;
	float4 maskColor = tex2D(mask, input.texCoord0.xy);
	float4 detailColor = tex2D(detail, input.texCoord0.zw); 
	float4 gradientColor = tex2D(gradient, input.texCoord1.xy);
	float4 contourColor = tex2D(contour, input.texCoord1.zw);

	#if GRADIENT_MODE == GRADIENT_MULTIPLY
		detailImpact = detailColor.rgb * gradientColor.rgb;
	#elif GRADIENT_MODE == GRADIENT_BLEND
		detailImpact = lerp(detailColor.rgb, gradientColor.rgb, gradientColor.a);
	#elif GRADIENT_MODE == GRADIENT_ADD
		detailImpact = detailColor.rgb + gradientColor.rgb;
	#elif GRADIENT_MODE == GRADIENT_SCREEN
		detailImpact = (detailColor.rgb - const1List3) * (const1List3 - gradientColor.rgb) + const1List3;
	#elif GRADIENT_MODE == GRADIENT_OVERLAY
		detailImpact = lerp(detailColor.rgb * gradientColor.rgb * 2.0, (detailColor.rgb * 2.0 - const2List3) * (const1List3 - gradientColor.rgb) + const1List3, step(const05List3, detailColor.rgb));
	#endif

	detailImpact *= maskColor.a;

	output.color = float4((contourColor.rgb - detailImpact) * contourColor.a + detailImpact, -maskColor.a * contourColor.a + (maskColor.a + contourColor.a)) * float4(input.color.rgb, 1.0) * input.color.a;

	#if COLORBLIND_MODE
		output.color.rgb = getColorBlind(output.color.rgb);
	#endif

	return output;
}

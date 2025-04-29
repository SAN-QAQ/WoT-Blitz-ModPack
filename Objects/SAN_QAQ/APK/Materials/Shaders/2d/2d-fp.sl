#include "common.slh"
#include "blending.slh"

#define COLOR_MUL 0
#define COLOR_ADD 1
#define ALPHA_MUL 2
#define ALPHA_ADD 3

#ifndef COLOR_OP
	#define COLOR_OP COLOR_MUL
#endif

#if COLORBLIND_MODE
	#include "colorblind-mode.slh"
#endif

fragment_in
{
	float4 color : COLOR0;

	#if TEXTURED
		float2 texCoord : TEXCOORD0;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if TEXTURED
	uniform sampler2D tex;

	#if CLAMP
		[material][a] property float2 maxUV;
	#endif
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#if TEXTURED
		#if CLAMP
			float2 texCoord = clamp(input.texCoord, const0List2, maxUV);
		#else
			float2 texCoord = input.texCoord;
		#endif

		output.color = tex2D(tex, texCoord);

		#if ALPHA8
			output.color = float4(const1List3, output.color.a);
		#elif RED8_TO_ALPHA
			output.color = float4(const1List3, output.color.r);
		#endif

		#if COLOR_OP == COLOR_MUL
			output.color *= input.color;
		#elif COLOR_OP == COLOR_ADD
			output.color += input.color;
		#elif COLOR_OP == ALPHA_MUL
			output.color.a *= input.color.a;
		#elif COLOR_OP == ALPHA_ADD
			output.color.a += input.color.a;
		#endif
	#else
		output.color = input.color;
	#endif

	#if ALPHATEST
		if (output.color.a < 0.5) discard;
	#endif

	#if GRAYSCALE
		float lum = dot(output.color.rgb, lumCof);
		output.color.rgb = float3(lum, lum, lum);
	#endif

	#if COLORBLIND_MODE
		output.color.rgb = getColorBlind(output.color.rgb);
	#endif

	return output;
}

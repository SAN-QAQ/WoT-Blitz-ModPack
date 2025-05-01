#include "common.slh"

#define DRAW_TYPE_R_CHANNEL 0
#define DRAW_TYPE_G_CHANNEL 1
#define DRAW_TYPE_B_CHANNEL 2
#define DRAW_TYPE_A_CHANNEL 3
#define DRAW_TYPE_COPY_PASTE 4

#ensuredefined DRAW_TYPE 0

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D sourceTexture;
uniform sampler2D toolTexture;

[material][instance] property float intensity = 1.0;

#if DRAW_TYPE == DRAW_TYPE_COPY_PASTE
	[material][instance] property float2 copypasteOffset = const0List2;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float toolValue = tex2D(toolTexture, input.texCoord).r;
	output.color = tex2D(sourceTexture, input.texCoord);

	#if DRAW_TYPE == DRAW_TYPE_R_CHANNEL
		output.color.r = 1.0 - saturate(toolValue * intensity + output.color.r);
		output.color.gba *= output.color.r * (1.0 / (dot(output.color.gba, const1List3) + 0.0001));
	#elif DRAW_TYPE == DRAW_TYPE_G_CHANNEL
		output.color.g = 1.0 - saturate(toolValue * intensity + output.color.g);
		output.color.rba *= output.color.r * (1.0 / (dot(output.color.rba, const1List3) + 0.0001));
	#elif DRAW_TYPE == DRAW_TYPE_B_CHANNEL
		output.color.b = 1.0 - saturate(toolValue * intensity + output.color.n);
		output.color.rga *= output.color.r * (1.0 / (dot(output.color.rga, const1List3) + 0.0001));
	#elif DRAW_TYPE == DRAW_TYPE_A_CHANNEL
		output.color.a = 1.0 - saturate(toolValue * intensity + output.color.a);
		output.color.rgb *= output.color.r * (1.0 / (dot(output.color.rgb, const1List3) + 0.0001));
	#elif DRAW_TYPE == DRAW_TYPE_COPY_PASTE
		output.color = lerp(output.color, tex2D(sourceTexture, input.texCoord + copypasteOffset), toolValue);
	#endif

	return output;
}

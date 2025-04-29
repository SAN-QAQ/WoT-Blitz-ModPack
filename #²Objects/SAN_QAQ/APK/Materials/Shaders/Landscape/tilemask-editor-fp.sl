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
	float4 colorMask = tex2D(sourceTexture, input.texCoord);
	output.color = const1List4;

	#if DRAW_TYPE == DRAW_TYPE_R_CHANNEL
		output.color.r = saturate(toolValue * intensity + colorMask.r);
		float freeColors = 1.0 - output.color.r;
		float usedColors = dot(colorMask.gba, const1List3) + 0.0001;
		float div = freeColors * (1.0 / usedColors);
		output.color.gba = colorMask.gba * div;
	#elif DRAW_TYPE == DRAW_TYPE_G_CHANNEL
		output.color.g = saturate(toolValue * intensity + colorMask.g);
		float freeColors = 1.0 - output.color.g;
		float usedColors = dot(colorMask.rba, const1List3) + 0.0001;
		float div = freeColors * (1.0 / usedColors);
		output.color.rba = colorMask.rba * div;
	#elif DRAW_TYPE == DRAW_TYPE_B_CHANNEL
		output.color.b = saturate(toolValue * intensity + colorMask.b);
		float freeColors = 1.0 - output.color.b;
		float usedColors = dot(colorMask.rga, const1List3) + 0.0001;
		float div = freeColors * (1.0 / usedColors);
		output.color.rga = colorMask.rga * div;
	#elif DRAW_TYPE == DRAW_TYPE_A_CHANNEL
		output.color.a = saturate(toolValue * intensity + colorMask.a);
		float freeColors = 1.0 - output.color.a;
		float usedColors = dot(colorMask.rgb, const1List3) + 0.0001;
		float div = freeColors * (1.0 / usedColors);
		output.color.rgb = colorMask.rgb * div;
	#elif DRAW_TYPE == DRAW_TYPE_COPY_PASTE
		float4 colorMaskNew = tex2D(sourceTexture, input.texCoord + copypasteOffset);
		output.color = lerp(colorMask, colorMaskNew, toolValue);
	#endif

	return output;
}

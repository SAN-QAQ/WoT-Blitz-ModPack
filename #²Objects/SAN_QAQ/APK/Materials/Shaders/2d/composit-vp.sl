#include "common.slh"

vertex_in
{
	float4 localPos : POSITION;
	float2 texCoord0 : TEXCOORD0;
	float2 texCoord1 : TEXCOORD1;
	float2 texCoord2 : TEXCOORD2;
	float2 texCoord3 : TEXCOORD3;
	float4 color : COLOR0;
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 texCoord0 : TEXCOORD0;
	float4 texCoord1 : TEXCOORD1;
	float4 color : COLOR0;
};

[auto][instance] property float4x4 worldViewProjMatrix;

#if CLAMP
	[material][a] property float2 maskMaxUV;
	[material][a] property float2 detailMaxUV;
	[material][a] property float2 gradientMaxUV;
	[material][a] property float2 contourMaxUV;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	output.localPos = mul4Fast1(input.localPos.xyz, worldViewProjMatrix);

	#if CLAMP
		output.texCoord0 = float4(clamp(input.texCoord0, const0List2, maskMaxUV), clamp(input.texCoord1, const0List2, detailMaxUV));
		output.texCoord1 = float4(clamp(input.texCoord2, const0List2, gradientMaxUV), clamp(input.texCoord3, const0List2, contourMaxUV));
	#else
		output.texCoord0 = float4(input.texCoord0, input.texCoord1);
		output.texCoord1 = float4(input.texCoord2, input.texCoord3);
	#endif

	output.color = input.color;

	return output;
}

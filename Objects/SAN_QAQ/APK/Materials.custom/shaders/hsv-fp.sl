#include "blending.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
	float4 color : COLOR0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D tex;

[material][a] property float hue;
[material][a] property float saturation;
[material][a] property float value;
[material][a] property float progress;

float3 rgb2hsv(float3 C)
{
	float4 K = float4(0.0, -0.33333333, 0.66666667, -1.0);
	float4 P = lerp(float4(C.gb, K.xy), float4(C.bg, K.wz), step(C.g, C.b));
	float4 Q = lerp(float4(C.r, P.yzx), float4(P.xyw, C.r), step(C.r, P.x));
	float D = Q.x - min(Q.w, Q.y);

	return float3(abs(Q.z + (Q.w - Q.y) * (1.0 / (D * 6.0 + 0.0001))), D * (1.0 / (Q.x + 0.0001)), Q.x);
}

float3 hsv2rgb(float3 C)
{
	float4 K = float4(1.0, 0.66666667, 0.33333333, 3.0);
	float3 P = abs(frac(C.xxx + K.xyz) * 6.0 - K.www);

	return C.z * lerp(K.xxx, saturate(P - K.xxx), C.y);
}

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 hsv = float3(hue, saturation, value * 0.01 + 1.0);

	float4 resColor = tex2D(tex, input.texCoord) * input.color;
	float4 srcColor = resColor;
	float3 hsvColor = rgb2hsv(resColor.rgb);

	resColor.rgb = hsv2rgb(float3(fmod(hsvColor.x * 360.0 + hsv.x, 360.0) * 0.00277778, saturate(hsvColor.yz * hsv.yz)));

	output.color = lerp(srcColor, resColor, step(progress, input.texCoord.x));

	return output;
}
fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D image;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float depthColor = saturate(tex2D(image, input.texCoord).x * 10.0 - 9.0);
	output.color = float4(depthColor, depthColor, depthColor, depthColor);

	return output;
}

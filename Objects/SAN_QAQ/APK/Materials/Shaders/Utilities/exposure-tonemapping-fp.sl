fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D luminance;

[auto][a] property float exposure;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float4 luminanceSample = tex2D(luminance, input.texCoord) * exposure;
	float4 mappedColor = const1List4 - exp2(-luminanceSample * _LOG2_E);
	mappedColor.rgb = toSRGB(mappedColor.rgb);

	output.color = lerp(luminanceSample, mappedColor, exposure);

	return output;
}

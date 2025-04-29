fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D fromRt;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = tex2D(fromRt, input.texCoord);

	return output;
}

vertex_in
{
	float4 localPos : POSITION;
};

vertex_out
{
	float4 localPos : SV_POSITION;
};

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	output.localPos = float4(input.localPos.xyz, 1.0);

	return output;
}

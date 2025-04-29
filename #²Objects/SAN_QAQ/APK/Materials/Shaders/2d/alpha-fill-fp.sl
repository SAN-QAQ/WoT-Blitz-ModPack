#include "common.slh"

color_mask = a;

fragment_in {};

fragment_out
{
	float4 color : SV_TARGET0;
};

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = float4(const0List3, 1.0);

	return output;
}

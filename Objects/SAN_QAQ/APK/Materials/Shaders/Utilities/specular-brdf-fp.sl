#include "common.slh"
#include "ibl.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 result = const0List2;
	float3 V = float3(sqrt(-input.texCoord.x * input.texCoord.x + 1.0), 0.0, input.texCoord.x);

	for (int i = 0; i < 4096; i++)
	{
		float3 H = I_GGX(D_Hammersley(i, 4096.0), input.texCoord.y, float3(const0List2, 1.0));
		float3 L = reflect(-V, H);

		float NdotV = saturate(V.z);
		float NdotL = saturate(L.z);
		float NdotH = saturate(H.z);
		float VdotH = saturate(dot(V, H));

		float Gv = G_GGX(NdotV, NdotL, input.texCoord.y) * VdotH * (1.0 / (NdotV * NdotH + 0.0001));
		float Fc = Gv * pow5Exp(VdotH);
		result += float2(Gv - Fc, Fc);
	}

	output.color = float4(result * 0.000244140625, 0.0, 1.0);

	return output;
}

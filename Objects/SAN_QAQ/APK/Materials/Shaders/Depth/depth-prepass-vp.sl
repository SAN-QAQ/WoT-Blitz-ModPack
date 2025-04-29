#include "common.slh"

#define DRAW_DEPTH_ONLY 1
#define NEED_CHAIN_TEXCOORD_OFFSETS 0

#include "materials-vertex-properties.slh"

#if INSTANCED_CHAIN
	#include "instanced-chain.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;

	#if USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
		float3 normal : NORMAL;
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if VERTEX_VERTICAL_OFFSET
		float offsetWeight : TEXCOORD5;
	#elif WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;
};

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing.slh"

	return output;
}

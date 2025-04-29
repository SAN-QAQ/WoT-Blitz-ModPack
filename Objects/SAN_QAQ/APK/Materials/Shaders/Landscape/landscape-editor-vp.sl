#include "common.slh"
#include "materials-vertex-properties-landscape.slh"

vertex_in
{
	#if LANDSCAPE_USE_INSTANCING
		[vertex] float4 data0 : TEXCOORD0; // position + edgeShiftDirection
		[vertex] float4 data1 : TEXCOORD1; // edge mask
		[vertex] float2 data2 : TEXCOORD2; // edgeVertexIndex + edgeMaskNull
		[instance] float3 data3 : TEXCOORD3; // patch position + scale
		[instance] float4 data4 : TEXCOORD4; // neighbour patch lodOffset

		#if LANDSCAPE_LOD_MORPHING
			[instance] float4 data5 : TEXCOORD5; // neighbour patch morph
			[instance] float3 data6 : TEXCOORD6; // patch lod + morph + pixelMappingOffset
		#endif
	#else
		float4 localPos : POSITION;
		float2 texCoord : TEXCOORD0;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;
	float4 texCoord : TEXCOORD0;
};

#if LANDSCAPE_USE_INSTANCING
	uniform sampler2D heightmap;

	[auto][a] property float heightmapTextureSize;
	[auto][a] property float3 boundingBoxSize;
#endif

[material][instance] property float2 textureTiling = float2(50.0, 50.0);

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing-landscape.slh

	#if LANDSCAPE_USE_INSTANCING
		output.texCoord.xy = float2(relativePos.x, 1.0 - relativePos.y);
	#else
		output.texCoord.xy = input.texCoord;
	#endif

	output.texCoord.zw = output.texCoord.xy * textureTiling;

	return output; 
}

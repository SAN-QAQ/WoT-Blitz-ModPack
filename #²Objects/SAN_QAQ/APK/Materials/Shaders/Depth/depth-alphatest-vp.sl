#include "common.slh"

#define DRAW_DEPTH_ONLY 1
#define NEED_CHAIN_TEXCOORD_OFFSETS 1

#include "materials-vertex-properties.slh"

#if INSTANCED_CHAIN
	#include "instanced-chain.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;
	float2 texCoord0 : TEXCOORD0;
	float2 texCoord1 : TEXCOORD1;

	#if VERTEX_VERTICAL_OFFSET
		float offsetWeight : TEXCOORD5;
	#elif WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#if USE_VERTEX_DISPLACEMENT
		float3 normal : NORMAL;
	#endif

	#if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if ALPHATEST && MATERIAL_TEXTURE
		#if PARTICLES_PERSPECTIVE_MAPPING
			float3 texCoord0 : TEXCOORD0;
		#else
			float2 texCoord0 : TEXCOORD0;
		#endif

		#if ALPHA_MASK
			float2 texCoord1 : TEXCOORD1;
		#endif

		#if FLOWMAP
			float3 flowData : TEXCOORD2;
		#endif
	#endif

	#if VERTEX_COLOR
		float vertexAlpha : COLOR0;
	#endif
};

#if ALPHATEST && MATERIAL_TEXTURE
	#if FLOWMAP
		[material][a] property float flowAnimSpeed = 0.0;
		[material][a] property float flowAnimOffset = 0.0;
	#endif

	#if TEXTURE0_ANIMATION_SHIFT
		[material][a] property float2 tex0ShiftPerSecond = const0List2;
	#endif

	#if TEXTURE0_SHIFT_ENABLED
		[material][a] property float2 texture0Shift = const0List2;
	#endif
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing.slh"

	#if ALPHATEST && MATERIAL_TEXTURE
		output.texCoord0.xy = input.texCoord0;

		#if INSTANCED_CHAIN
			output.texCoord0.y = output.texCoord0.y * segmentLength * (1.0 / chunkLength) + getTexCoordOffset(instanceId + 1);
		#endif

		#if TEXTURE0_SHIFT_ENABLED
			output.texCoord0.xy += texture0Shift;
		#endif

		#if TEXTURE0_ANIMATION_SHIFT
			output.texCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
		#endif

		#if PARTICLES_PERSPECTIVE_MAPPING
			#if VERTEX_VERTICAL_OFFSET
				output.texCoord0.z = input.offsetWeight;
			#elif WIND_ANIMATION
				output.texCoord0.z = input.flexibility;
			#endif
		#endif

		#if ALPHA_MASK
			output.texCoord1 = input.texCoord1;
		#endif

		#include "flowmap-vec.slh"
	#endif

	#if VERTEX_COLOR
		output.vertexAlpha = input.color0.a;
	#endif

	return output;
}

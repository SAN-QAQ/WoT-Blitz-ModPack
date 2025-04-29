#define SHADOW_RECEIVER 1

#include "common.slh"
#include "vp-fog-props.slh"

#if !DRAW_WATER_DEFORMATION && RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;
	float4 color0 : COLOR0;
	float2 texCoord0 : TEXCOORD0;

	#if FRAME_BLEND
		float3 texCoord1 : TEXCOORD1; // uv1.xy + time
	#endif

	#if PARTICLES_FLOWMAP
		float4 texCoord2 : TEXCOORD2; // Flow speed and flow offset.
	#endif

	#if PARTICLES_NOISE
		float3 texCoord3 : TEXCOORD3; // Noise uv and scale.
	#endif

	#if PARTICLES_FRESNEL_TO_ALPHA || PARTICLES_PERSPECTIVE_MAPPING
		float3 texCoord5 : TEXCOORD5; // x - fresnel. y - alpha remap. z - perspective mapping w.
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;

	#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
		float4 projPos : POSITION0;
	#endif

	float4 vertexColor : COLOR0;

	#if !DRAW_WATER_DEFORMATION && RECEIVE_SHADOW
		float3 shadowColor : COLOR1;
	#endif

	#if PARTICLES_PERSPECTIVE_MAPPING
		float3 texCoord0 : TEXCOORD0;
	#else
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if FRAME_BLEND
		float3 texCoord1 : TEXCOORD1;
	#endif

	#if PARTICLES_FLOWMAP
		float4 texCoord2 : TEXCOORD2;
		float texCoord3 : TEXCOORD3;
	#endif

	#if PARTICLES_NOISE
		#if PARTICLES_FRESNEL_TO_ALPHA
			float4 texCoord4 : TEXCOORD4; // Noise uv and scale. Fresnel a.
		#else
			float3 texCoord4 : TEXCOORD4; // Noise uv and scale.
		#endif
	#elif PARTICLES_FRESNEL_TO_ALPHA
		float texCoord4 : TEXCOORD4; // Fresnel a.
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD5;
	#endif
};

[auto][a] property float4x4 worldViewProjMatrix;

#if (!DRAW_WATER_DEFORMATION && RECEIVE_SHADOW) || USE_VERTEX_FOG
	[auto][a] property float4x4 worldMatrix;
#endif

#if USE_VERTEX_FOG
	[auto][a] property float3 cameraPosition;
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 worldViewMatrix;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#if PARTICLES_FLOWMAP
		float2 flowPhase = frac(float2(input.texCoord2.z, input.texCoord2.z + 0.5)) - const05List2;
		output.texCoord2 = float4(input.texCoord2.xy, flowPhase * input.texCoord2.w);
		output.texCoord3 = abs(flowPhase.x) * 2.0;
	#endif

	output.localPos = mul4Fast1(input.localPos.xyz, worldViewProjMatrix);

	#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
		output.projPos = output.localPos;
	#endif

	#if (!DRAW_WATER_DEFORMATION && RECEIVE_SHADOW) || USE_VERTEX_FOG
		float3 worldPos = mul3Fast1(input.localPos.xyz, worldMatrix);
	#endif

	#if USE_VERTEX_FOG
		float3 camPos = cameraPosition;
		float3 eyePos = mul3Fast1(input.localPos.xyz, worldViewMatrix);
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir *= 1.0 / toLightDis;

		#include "vp-fog-math.slh"
	#endif

	output.vertexColor = input.color0;
	output.texCoord0.xy = input.texCoord0;

	#if PARTICLES_PERSPECTIVE_MAPPING
		output.texCoord0.z = input.texCoord5.z;
	#endif

	#if PARTICLES_NOISE
		#if PARTICLES_FRESNEL_TO_ALPHA
			output.texCoord4 = float4(input.texCoord3, input.texCoord5.x * 1.0042);
		#else
			output.texCoord4 = input.texCoord3;
		#endif
	#elif PARTICLES_FRESNEL_TO_ALPHA
		output.texCoord4 = input.texCoord5.x * 1.0042;
	#endif

	#if FRAME_BLEND
		output.texCoord1 = input.texCoord1;
	#endif

	#if FORCE_2D_MODE
		output.localPos.z = 0.0;
	#endif

	#if !DRAW_WATER_DEFORMATION && RECEIVE_SHADOW
		float3 shadowInf = getShadow(worldPos, output.localPos.xy * (1.0 / output.localPos.w), 0.0);
		output.shadowColor = lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
	#endif

	return output;
}

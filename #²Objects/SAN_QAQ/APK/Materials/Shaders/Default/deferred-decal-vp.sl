#include "common.slh"
#include "vp-fog-props.slh"

#ensuredefined DECAL_BACK_SIDE_FADE 0

#define DRAW_FLORA_LAYING (PASS_NAME == PASS_FLORALAYING)

vertex_in
{
	[vertex] float4 localPos : POSITION;
	[instance] float4 worldMatrix0 : TEXCOORD0;
	[instance] float4 worldMatrix1 : TEXCOORD1;
	[instance] float4 worldMatrix2 : TEXCOORD2;
	[instance] float4 invWorldMatrix0 : TEXCOORD3;
	[instance] float4 invWorldMatrix1 : TEXCOORD4;
	[instance] float4 invWorldMatrix2 : TEXCOORD5;
	[instance] float4 parameters : TEXCOORD6;
	[instance] float4 texCoord : TEXCOORD7;
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if DRAW_FLORA_LAYING
		float3 worldDirStrength : TEXCOORD0;
	#else
		float4 invWorldMatrix0 : TEXCOORD0;
		float4 invWorldMatrix1 : TEXCOORD1;
		float4 invWorldMatrix2 : TEXCOORD2;
		float4 parameters : TEXCOORD3;
		float4 texCoord : TEXCOORD4;

		#if USE_VERTEX_FOG
			float4 varFog : TEXCOORD5;
		#endif
	#endif
};

[auto][a] property float3 cameraPosition;
[auto][a] property float4x4 viewProjMatrix;

#if DRAW_FLORA_LAYING
	[auto][a] property float3 primaryCameraPosition;
#endif

#if FADE_OUT_WITH_TIME
	[auto][a] property float globalTime;
	[auto][a] property float treadsNearFadeDistance;
	[auto][a] property float treadsFarFadeDistance;
	[auto][a] property float2 fadeOutTimeStartEnd;
#endif

#if USE_VERTEX_FOG
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 viewMatrix;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	float3 localPos = input.localPos.xyz;
	float4x4 worldMatrix = vecToMat(input.worldMatrix0, input.worldMatrix1, input.worldMatrix2);

	#if DECAL_TREAD
		localPos.y = lerp(localPos.y, localPos.y * input.parameters.z + input.parameters.w, localPos.x + 0.5);
		float nearFadeDistance = treadsNearFadeDistance;
		float farFadeDistance = treadsFarFadeDistance;
	#else
		float nearFadeDistance = input.parameters.y;
		float farFadeDistance = input.parameters.z;
	#endif

	float3 worldPos = mul3Fast1(localPos, worldMatrix);
	output.localPos = mul4Fast1(worldPos, viewProjMatrix);
	output.projPos = output.localPos;

	#if DRAW_FLORA_LAYING
		float3 toCamDir = primaryCameraPosition - worldMatrix[3].xyz;
	#else
		float3 toCamDir = cameraPosition - worldMatrix[3].xyz;
	#endif

	float toCamDis = length(toCamDir);
	toCamDir *= 1.0 / toCamDis;

	float opacity = 1.0 - smoothstep(nearFadeDistance, farFadeDistance, toCamDis);

	#if FADE_OUT_WITH_TIME
		opacity -= opacity * smoothstep(fadeOutTimeStartEnd.x, fadeOutTimeStartEnd.y, globalTime - input.parameters.x);
	#else
		opacity *= input.parameters.x;
	#endif

	#if DRAW_FLORA_LAYING
		output.worldDirStrength = normalize(worldMatrix[2].xyz * 0.2 - worldMatrix[1].xyz) * (opacity * 0.5) + const05List3;
	#else
		output.invWorldMatrix0 = input.invWorldMatrix0;
		output.invWorldMatrix1 = input.invWorldMatrix1;
		output.invWorldMatrix2 = input.invWorldMatrix2;
		output.parameters = input.parameters;

		#if DECAL_TREAD
			output.parameters.x = opacity;
		#else
			output.parameters.x *= opacity;
		#endif

		#if DECAL_BACK_SIDE_FADE
			output.parameters.x *= smoothstep(-0.2, 0.1, saturate(dot(normalize(worldMatrix[2].xyz), toCamDir)));
		#endif

		output.texCoord = input.texCoord;

		#if USE_VERTEX_FOG
			float3 camPos = cameraPosition;
			float3 eyePos = mul3Fast1(worldPos, viewMatrix);
			float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
			float toLightDis = length(toLightDir);
			toLightDir *= 1.0 / toLightDis;
	
			#include "vp-fog-math.slh"
		#endif
	#endif

	return output;
}
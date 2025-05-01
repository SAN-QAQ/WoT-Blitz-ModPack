#include "common.slh"
#include "vp-fog-props.slh"

#ensuredefined WATER_DEFORMATION 0
#ensuredefined WATER_RENDER_OBJECT 0
#ensuredefined WATER_TESSELLATION 0

vertex_in
{
	[vertex] float4 localPos : POSITION;

	#if WATER_RENDER_OBJECT
		#if WATER_TESSELLATION
			[instance] float2 texCoord0 : TEXCOORD0;
		#elif !PIXEL_LIT
			[vertex] float2 texCoord1 : TEXCOORD1; // decal
		#endif
	#else
		[vertex] float2 texCoord0 : TEXCOORD0;

		#if !PIXEL_LIT
			[vertex] float2 texCoord1 : TEXCOORD1; // decal
		#endif

		[vertex] float3 normal : NORMAL;
		[vertex] float3 tangent : TANGENT;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if !DRAW_DEPTH_ONLY
		#if WATER_DEFORMATION
			float4 worldPos : POSITION1;
		#else
			float3 worldPos : POSITION1;
		#endif

		float4 texCoord : TEXCOORD0;

		#if PIXEL_LIT
			#if REAL_REFLECTION
				float3 eyePos : POSITION2;
				float3 waterProjPos : POSITION3;
			#else
				float3 tbnToWorld0 : TANGENTTOWORLD0;
				float3 tbnToWorld1 : TANGENTTOWORLD1;
				float3 tbnToWorld2 : TANGENTTOWORLD2;
			#endif
		#else
			float2 decalTexCoord : TEXCOORD1;
			float3 reflectTexCoord : TEXCOORD2;
		#endif
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD3;
	#endif
};

#if WATER_DEFORMATION
	uniform sampler2D dynamicWaterDeformationMap;
#endif

[auto][a] property float3 cameraPosition;
[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 viewProjMatrix;
[auto][a] property float4x4 worldMatrix;

#if USE_VERTEX_FOG
	[auto][a] property float4 lightPosition0;
#endif

#if WATER_DEFORMATION
	[auto][a] property float3 cameraDirection;
	[auto][a] property float4 waterDeformationParams; // xy - fadeOutRange, z - maxDeformation, w - cameraBias
	[auto][a] property float4x4 waterDeformationViewProj;
#endif

#if !DRAW_DEPTH_ONLY
	[auto][a] property float globalTime;
	[auto][a] property float4x4 worldInvTransposeMatrix;

	#if PIXEL_LIT && REAL_REFLECTION
		[auto][a] property float projectionFlip;
	#endif

	#if WATER_RENDER_OBJECT
		[material][a] property float3 inputTangent;
		[material][a] property float4 texCoordTransform0;
	#endif

	[material][a] property float normal0Scale = 0.0;
	[material][a] property float normal1Scale = 0.0;
	[material][a] property float2 normal0ShiftPerSecond = const0List2;
	[material][a] property float2 normal1ShiftPerSecond = const0List2;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	float3 localPos = input.localPos.xyz;
	float3 camPos = cameraPosition;

	#if WATER_RENDER_OBJECT && WATER_TESSELLATION
		localPos.xy += input.texCoord0.xy;
	#endif

	float3 worldPos = mul3Fast1(localPos, worldMatrix);

	#if WATER_DEFORMATION
		float4 wavePos = mul4Fast1(worldPos, waterDeformationViewProj);
		float waveFadeOutDiff = abs(waterDeformationParams.x - waterDeformationParams.y);
		float waveFactor = 1.0 - smoothstep(waterDeformationParams.x - waveFadeOutDiff, waterDeformationParams.y + waveFadeOutDiff, length(cameraDirection.xy * waterDeformationParams.w + (camPos.xy - worldPos.xy)));
		float offset = 0.025 * (1.0 / waterDeformationParams.y);
		float2 waveTexCoord = wavePos.xy * float2(0.5, -0.5) + const05List2;

		float4 wave0 = tex2Dlod(dynamicWaterDeformationMap, waveTexCoord + float2(offset, 0.0), 0.0);
		float4 wave1 = tex2Dlod(dynamicWaterDeformationMap, waveTexCoord + float2(0.0, -offset), 0.0);
		float4 wave2 = tex2Dlod(dynamicWaterDeformationMap, waveTexCoord, 0.0);
		float3 wave = float3(wave0.r - wave0.b, wave1.r - wave1.b, wave2.r - wave2.b) * waveFactor;

		worldPos.z += wave.z * waterDeformationParams.z;
	#endif

	float3 eyePos = mul3Fast1(worldPos, viewMatrix);
	output.localPos = mul4Fast1(worldPos, viewProjMatrix);
	output.projPos = output.localPos;

	#if USE_VERTEX_FOG
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir *= 1.0 / toLightDis;

		#include "vp-fog-math.slh"
	#endif

	#if !DRAW_DEPTH_ONLY
		output.worldPos.xyz = worldPos;

		#if WATER_DEFORMATION
			output.worldPos.w = wave2.g * waveFactor;
		#endif

		#if WATER_RENDER_OBJECT
			float2 texCoord = float2(dot(localPos.xy, texCoordTransform0.xz), dot(localPos.xy, texCoordTransform0.yw));

			#if WATER_DEFORMATION
				float3 normal = normalize(float3(wave.zz - wave.xy, 0.05));
				float3 tangent = normalize(normal * dot(-inputTangent, normal) + inputTangent);
			#else
				float3 normal = float3(const0List2, 1.0);
				float3 tangent = inputTangent;
			#endif
		#else
			float2 texCoord = input.texCoord0;
			float3 normal = input.normal;
			float3 tangent = input.tangent;
		#endif

		output.texCoord = float4(texCoord * normal0Scale + frac(normal0ShiftPerSecond * globalTime), float2(texCoord.x + texCoord.y, texCoord.y - texCoord.x) * normal1Scale + frac(normal1ShiftPerSecond * globalTime));

		#if PIXEL_LIT
			#if REAL_REFLECTION
				output.eyePos = eyePos;
				output.waterProjPos = output.projPos.xyw;
				output.waterProjPos.y *= projectionFlip;
			#else
				float3 n = normalize(mul3Fast0(normal, worldInvTransposeMatrix));
				float3 t = normalize(mul3Fast0(tangent, worldInvTransposeMatrix));
				float3 b = cross(n, t);

				output.tbnToWorld0 = float3(t.x, b.x, n.x);
				output.tbnToWorld1 = float3(t.y, b.y, n.y);
				output.tbnToWorld2 = float3(t.z, b.z, n.z);
			#endif
		#else
			output.reflectTexCoord = reflect(normalize(worldPos - camPos), normalize(mul3Fast0(normal, worldInvTransposeMatrix)));

			#if WATER_TESSELLATION
				output.decalTexCoord = const0List2;
			#else
				output.decalTexCoord = input.texCoord1;
			#endif
		#endif
	#endif

	return output;
}

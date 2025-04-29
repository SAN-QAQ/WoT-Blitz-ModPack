#include "common.slh"
#include "vp-fog-props.slh"

#ensuredefined SPEEDTREE_JOINT_LENGTHWISE_TRANSFORM 0

vertex_in
{
	float4 localPos : POSITION;
	float2 texCoord0 : TEXCOORD0;
	float4 pivot : TEXCOORD4;
	float flexibility : TEXCOORD5;
	float2 angleSinCos : TEXCOORD6;
	float4 color0 : COLOR0;

	#if PBR_SPEEDTREE
		float3 normal : NORMAL;
		float3 tangent : TANGENT;
		float3 binormal : BINORMAL;
	#endif

	#if SPEEDTREE_JOINT_TRANSFORM
		float jointIndex : BLENDINDICES;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;

	#if LOD_TRANSITION || (!DRAW_DEPTH_ONLY && RECEIVE_SHADOW)
		float4 projPos : POSITION0;
	#endif

	#if !DRAW_DEPTH_ONLY
		#if RECEIVE_SHADOW
			float3 shadowWorldPos : POSITION1;
		#endif

		#if PBR_SPEEDTREE
			float4 tbnToWorld0 : TANGENTTOWORLD0;
			float4 tbnToWorld1 : TANGENTTOWORLD1;
			float4 tbnToWorld2 : TANGENTTOWORLD2;
		#endif
	#endif

	float2 texCoord : TEXCOORD0;

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif

	float4 vertexColor : COLOR0;
};

[auto][a] property float3 worldScale;
[auto][a] property float4x4 invViewMatrix;
[auto][a] property float4x4 projMatrix;
[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 worldMatrix;
[auto][a] property float4x4 worldViewMatrix;

[material][a] property float cutLeafDistance = 1.0;
[material][a] property float cutLeafEnabled = 0.0;
[material][a] property float2 leafOscillationParams = const0List2;
[material][a] property float2 trunkOscillationParams = const0List2;

#if RECEIVE_SHADOW
	[auto][a] property float4x4 shadowViewMatrix;
#endif

#if USE_VERTEX_FOG
	[auto][a] property float3 cameraPosition;
	[auto][a] property float4 lightPosition0;
#endif

#if TEXTURE0_ANIMATION_SHIFT
	[auto][a] property float globalTime;

	[material][a] property float2 tex0ShiftPerSecond = const0List2;
#endif

#if TEXTURE0_SHIFT_ENABLED
	[material][a] property float2 texture0Shift = const0List2;
#endif

#if !DRAW_DEPTH_ONLY
	#if SPHERICAL_LIT
		[auto][a] property float speedTreeLightSmoothing;
		[auto][a] property float3 boundingBoxSize;
		[auto][a] property float3 worldViewObjectCenter;

		#if SPHERICAL_HARMONICS_9
			[auto][sh] property float4 sphericalHarmonics[7] : "bigarray";
		#elif SPHERICAL_HARMONICS_4
			[auto][sh] property float4 sphericalHarmonics[3] : "bigarray";
		#else
			[auto][sh] property float4 sphericalHarmonics;
		#endif

		#if PBR_SPEEDTREE
			[auto][a] property float4x4 worldInvTransposeMatrix;

			[material][a] property float normalSphereBendTerm = 0.0;
			[material][a] property float normalSphereBendZSquish = 1.0;
			[material][a] property float pbrSHOcclusionMult = 2.0;
			[material][a] property float2 pbrVertexAOBrightnessContrast = float2(0.0, 1.0);
			[material][a] property float3 normalSphereBendCenter = float3(const0List2, 0.0);
		#else
			[material][a] property float shOcclusionMult = 2.0;
			[material][a] property float2 vertexAOBrightnessContrast = float2(0.0, 1.0);
		#endif
	#else
		[material][a] property float treeLeafOcclusionMul = 0.5;
		[material][a] property float treeLeafOcclusionOffset = 0.0;
		[material][a] property float4 treeLeafColorMul = const05List4;
	#endif
#endif

#if SPEEDTREE_JOINT_TRANSFORM
	[material][cp] property float4 speedtreeJointViewOffsets[32] : "bigarray"; // xyz - offset, w - inverse length
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	float3 localPos = lerp(input.localPos.xyz, input.pivot.xyz, input.pivot.w);
	float3 billboardOffset = input.localPos.xyz - localPos;

	if (cutLeafEnabled != 0.0)
	{
		billboardOffset *= step(-cutLeafDistance, dot(localPos, float3(worldViewMatrix[0].z, worldViewMatrix[1].z, worldViewMatrix[2].z)) + worldViewMatrix[3].z);
	}

	localPos.xy += trunkOscillationParams * (input.flexibility * 2.25);
	float2 SinCos = leafOscillationParams * input.angleSinCos * 2.25;
	float sinT = SinCos.x + SinCos.y;
	float cosT = -sinT * sinT * 0.5 + 1.0;

	billboardOffset.xy = float2(billboardOffset.x * cosT - billboardOffset.y * sinT, billboardOffset.x * sinT + billboardOffset.y * cosT);

	float3 billboardOffsetPos = worldScale * billboardOffset;
	float3 worldPos = mul3Fast1(localPos, worldMatrix);
	float3 shadowWorldPos = worldPos;
	worldPos += mul3Fast0(billboardOffsetPos, invViewMatrix);
	float3 eyePos = mul3Fast1(worldPos, viewMatrix);

	#if SPEEDTREE_JOINT_TRANSFORM
		float3 jointViewOffset = speedtreeJointViewOffsets[int(input.jointIndex)].xyz;

		#if SPEEDTREE_JOINT_LENGTHWISE_TRANSFORM
			jointViewOffset *= length(input.localPos.xyz - input.pivot.xyz) * speedtreeJointViewOffsets[int(input.jointIndex)].w;
		#endif

		eyePos += jointViewOffset;
	#endif

	#if RECEIVE_SHADOW
		#if SPEEDTREE_JOINT_TRANSFORM
			shadowWorldPos -= mul3Fast0(billboardOffsetPos - jointViewOffset, transpose(shadowViewMatrix));
		#else
			shadowWorldPos -= mul3Fast0(billboardOffsetPos, transpose(shadowViewMatrix));
		#endif
	#endif

	output.localPos = mul4Fast1(eyePos, projMatrix);

	#if LOD_TRANSITION || (!DRAW_DEPTH_ONLY && RECEIVE_SHADOW)
		output.projPos = output.localPos;
	#endif

	output.vertexColor = input.color0;
	output.texCoord = input.texCoord0;

	#if TEXTURE0_SHIFT_ENABLED
		output.texCoord += texture0Shift;
	#endif

	#if TEXTURE0_ANIMATION_SHIFT
		output.texCoord += frac(tex0ShiftPerSecond * globalTime);
	#endif

	#if FORCE_2D_MODE
		output.localPos.z = 0.0;
	#endif

	#if !DRAW_DEPTH_ONLY
		#if SPHERICAL_LIT
			#if SPHERICAL_HARMONICS_4 || SPHERICAL_HARMONICS_9
				float3 sphericalLightFactor = sphericalHarmonics[0].xyz * 0.282094;

				if (cutLeafEnabled == 0.0)
				{
					float3x3 shMatrix = float3x3(float3(sphericalHarmonics[0].w, sphericalHarmonics[1].xy), float3(sphericalHarmonics[1].zw, sphericalHarmonics[2].x), sphericalHarmonics[2].yzw);
					
					float3 normal = normalize(mul3Fast0(eyePos - worldViewObjectCenter, invViewMatrix) * (1.0 / boundingBoxSize));
					float3 normalS = normal * normal;
					float3 localNormal = mul3Fast0(billboardOffsetPos, invViewMatrix);
					float3 localSphericalLightFactor = mul(localNormal.yzx, shMatrix) * (input.pivot.w * 0.325734) + sphericalLightFactor;
					localNormal.z += 1.0 - input.pivot.w;
					localNormal = normalize(localNormal);
					sphericalLightFactor += mul(normal.yzx, shMatrix) * 0.325734;

					#if SPHERICAL_HARMONICS_9
						sphericalLightFactor += sphericalHarmonics[3].xyz * (normal.x * normal.y * 0.273136) + float3(sphericalHarmonics[3].w, sphericalHarmonics[4].xy) * (normal.y * normal.z * 0.273136) + float3(sphericalHarmonics[4].zw, sphericalHarmonics[5].x) * (normalS.z * 0.236541 - 0.078847) + sphericalHarmonics[5].yzw * (normal.x * normal.z * 0.273136) + sphericalHarmonics[6].xyz * ((normalS.x - normalS.y) * 0.136568);
					#endif

					sphericalLightFactor = lerp(sphericalLightFactor, localSphericalLightFactor, speedTreeLightSmoothing);
				}
			#else
				float3 sphericalLightFactor = sphericalHarmonics.xyz * 0.282094;
			#endif

			#if PBR_SPEEDTREE
				float2 aoBC = pbrVertexAOBrightnessContrast;
				float aoMult = pbrSHOcclusionMult;
			#else
				float2 aoBC = vertexAOBrightnessContrast;
				float aoMult = shOcclusionMult;
			#endif

			output.vertexColor = float4(sphericalLightFactor * ((aoBC.y * (input.color0.r - 0.5) + (aoBC.x + 0.5)) * aoMult), 1.0);
		#else
			output.vertexColor = float4(input.color0.rgb * treeLeafColorMul.xyz * treeLeafOcclusionMul + float3(treeLeafOcclusionOffset, treeLeafOcclusionOffset, treeLeafOcclusionOffset), input.color0.a);
		#endif

		#if RECEIVE_SHADOW
			output.shadowWorldPos = shadowWorldPos;
		#endif

		#if PBR_SPEEDTREE
			float3 t = mul3Fast0(input.tangent, worldInvTransposeMatrix);
			float3 b = mul3Fast0(input.binormal, worldInvTransposeMatrix);
			float3 n = mul3Fast0(input.normal, worldInvTransposeMatrix);

			float3 bentNormal = normalize(lerp(n, (worldPos - mul3Fast1(normalSphereBendCenter, worldMatrix)) * float3(const1List2, normalSphereBendZSquish), normalSphereBendTerm));
			float3 bentTangent = normalize(t - bentNormal * dot(t, bentNormal));
			float3 bentBinormal = normalize(b - bentNormal * dot(b, bentNormal) - bentTangent * dot(b, bentTangent));

			output.tbnToWorld0 = float4(bentTangent.x, bentBinormal.x, bentNormal.x, worldPos.x);
			output.tbnToWorld1 = float4(bentTangent.y, bentBinormal.y, bentNormal.y, worldPos.y);
			output.tbnToWorld2 = float4(bentTangent.z, bentBinormal.z, bentNormal.z, worldPos.z);
		#endif
	#endif

	#if USE_VERTEX_FOG
		float3 camPos = cameraPosition;
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir *= 1.0 / toLightDis;

		#include "vp-fog-math.slh"
	#endif

	return output;
}

#include "common.slh"
#include "vp-fog-props.slh"

#ensuredefined FLORA_AMBIENT_ANIMATION 0
#ensuredefined FLORA_BILLBOARD 0
#ensuredefined FLORA_FAKE_SHADOW 0
#ensuredefined FLORA_LAYING 0
#ensuredefined FLORA_LOD_TRANSITION_FAR 0
#ensuredefined FLORA_LOD_TRANSITION_NEAR 0
#ensuredefined FLORA_NORMAL_MAP 0
#ensuredefined FLORA_PBR_LIGHTING 0
#ensuredefined FLORA_WAVE_ANIMATION 0
#ensuredefined FLORA_WIND_ANIMATION 0
#ensuredefined VEGETATION_BEND 0

#define FLORA_ANIMATION (FLORA_AMBIENT_ANIMATION || FLORA_WIND_ANIMATION)
#define FLORA_LOD_TRANSITION (FLORA_LOD_TRANSITION_FAR || FLORA_LOD_TRANSITION_NEAR)

#if FLORA_WAVE_ANIMATION
	#include "flora-wave-animation.slh"
#endif

vertex_in
{
	[vertex] float4 localPos : POSITION;

	#if FLORA_PBR_LIGHTING
		[vertex] float3 normal : NORMAL;
		[vertex] float3 tangent : TANGENT;
		[vertex] float3 binormal : BINORMAL;
	#endif

	[vertex] float2 texCoord : TEXCOORD0;
	[instance] float3 pivotScale : TEXCOORD1;

	#if FLORA_WIND_ANIMATION
		[instance] float2 wind : TEXCOORD2;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;
	float3 worldPos : POSITION1;
	float2 texCoord : TEXCOORD0;

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif

	#if !DRAW_DEPTH_ONLY
		#if FLORA_LAYING
			float3 vegetationTexCoord : TEXCOORD2; // .z - layingStrength
		#else
			float2 vegetationTexCoord : TEXCOORD2;
		#endif

		#if FLORA_PBR_LIGHTING
			#if FLORA_NORMAL_MAP
				float4 tbnToWorld0 : TANGENTTOWORLD0; // .w - localHeight

				#if FLORA_FAKE_SHADOW && FLORA_ANIMATION
					float4 tbnToWorld1 : TANGENTTOWORLD1; // .w - animation.x
					float4 tbnToWorld2 : TANGENTTOWORLD2; // .w - animation.y
				#else
					float3 tbnToWorld1 : TANGENTTOWORLD1;
					float3 tbnToWorld2 : TANGENTTOWORLD2;
				#endif
			#else
				float4 normal : NORMAL; // .w - localHeight

				#if FLORA_ANIMATION && FLORA_FAKE_SHADOW
					float2 animation : TEXCOORD3;
				#endif
			#endif
		#endif
	#endif
};

uniform sampler2D heightmap;

#if !DRAW_DEPTH_ONLY && FLORA_PBR_LIGHTING
	uniform sampler2D floraLandscapeNormalMap;
#endif

#if FLORA_LAYING
	uniform sampler2D dynamicFloraLayingMap;
#endif

[auto][a] property float heightmapTextureSize;
[auto][a] property float3 cameraPosition;
[auto][a] property float4x4 viewProjMatrix;

#if FLORA_AMBIENT_ANIMATION && FLORA_ANIMATION
	[auto][a] property float globalTime;
#endif

#if FLORA_LAYING
	[auto][a] property float4x4 floraLayingViewProj;
#endif

#if USE_VERTEX_FOG
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 viewMatrix;
#endif

#if VEGETATION_BEND
	[auto][a] property float2 viewportSize;
	[auto][a] property float3 cameraDirection;
	[auto][a] property float4 grassBendParams;

	[material][a] property float grassBendWeight;
#endif

[material][a] property float floraCameraBasedTilting;
[material][a] property float floraScaleFactor;
[material][a] property float2 floraScaleRange;
[material][a] property float3 floraMinScale;
[material][a] property float3 worldSize;

#if !DRAW_DEPTH_ONLY && FLORA_PBR_LIGHTING
	[material][a] property float floraLocalHeight;
	[material][a] property float floraNormalLifting;
#endif

#if FLORA_AMBIENT_ANIMATION
	[material][a] property float floraInstanceMotion;
	[material][a] property float floraVertexMotion;
#endif

#if FLORA_LAYING
	[material][a] property float2 floraLayingFadeOutRange;
#endif

#if FLORA_WIND_ANIMATION
	[material][a] property float floraWindMotion;
#else
	[material][a] property float2 floraAvgWindDisplacement;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	float3 camPos = cameraPosition;
	float2 pivot = input.pivotScale.xy;

	#if FLORA_BILLBOARD
		float2 rotatedTheta = normalize(camPos.xy - pivot);
	#else
		float theta = frac((pivot.y * 419.0 + pivot.x)) * _PI_20;
		float2 rotatedTheta = float2(cos(theta), sin(theta));
	#endif

	float3 localPos = (input.localPos.xyz * lerp(floraMinScale, const1List3, input.pivotScale.z)) * (lerp(floraScaleRange.x, floraScaleRange.y, frac(pivot.x * 419.0 + pivot.y)) * floraScaleFactor);
	localPos.xy = rotate(localPos.xy, rotatedTheta);

	float3 worldPos = localPos;
	worldPos.xy += pivot;

	float2 texCoord = worldPos.xy * (1.0 / worldSize.xy) + const05List2;
	float4 vegetationHeight = tex2Dlod(heightmap, 1.0 / (float2(heightmapTextureSize, heightmapTextureSize) * 2.0) + texCoord, 0.0);

	#if HEIGHTMAP_FLOAT_TEXTURE
		float height = vegetationHeight.r;
	#else
		float height = dot(vegetationHeight, heightList);
	#endif

	height *= worldSize.z;
	worldPos.z += height;

	float3 fromCamDir = worldPos - camPos;

	#if VEGETATION_BEND
		float grassCameraScaleWidth = grassBendParams.z * viewportSize.y * (1.0 / viewportSize.x);

		float fromCamDirDot = dot(fromCamDir, fromCamDir);
		float fromCamDirProjLength = dot(fromCamDir, normalize(cameraDirection));
		float fromCamDirRayDist = (-fromCamDirProjLength * fromCamDirProjLength + fromCamDirDot) * grassCameraScaleWidth * (1.0 / (pow(fromCamDirDot, grassBendParams.w) + grassBendParams.y));

		worldPos.z = localPos.z * lerp(1.0, clamp(fromCamDirRayDist, grassBendParams.x, 1.0), grassBendWeight) + height;
	#endif

	#if FLORA_LAYING
		float4 layingLocalPos = mul4Fast1(worldPos, floraLayingViewProj);
		layingLocalPos.xyz *= 1.0 / layingLocalPos.w;

		float4 layingSample = tex2Dlod(dynamicFloraLayingMap, layingLocalPos.xy * float2(0.5, -0.5) + const05List2, 0.0);
		float3 layingDir = layingSample.xyz * 2.0 - const1List3;
		float layingDis = length(layingDir);
		float layingStrength = layingDis;

		layingStrength = lerp(0.0, layingStrength, layingLocalPos.z * 0.5 + (1.0 - step(layingSample.w, 0.5)));
		layingStrength -= layingStrength * smoothstep(floraLayingFadeOutRange.x, floraLayingFadeOutRange.y, length(fromCamDir.xy));
		layingDir = lerp(layingDir, layingDir * (1.0 / layingDis), step(0.0, layingStrength));
		layingDir = lerp(float3(const0List2, 1.0), layingDir, layingStrength);

		worldPos += layingDir * localPos.z - float3(const0List2, localPos.z);
	#endif

	float3 toCamDir = normalize(camPos - worldPos);
	float3 displacement = float3(normalize(toCamDir.xy * 100.0) * (-toCamDir.z * floraCameraBasedTilting), 0.0);

	#if FLORA_ANIMATION
		float3 animation = const0List3;

		#if FLORA_AMBIENT_ANIMATION
			float instanceMotionPhase = sin(pivot.x + pivot.y + globalTime) * 4.5 + 2.25;
			float3 instanceMotion = float3(instanceMotionPhase, instanceMotionPhase * 0.5, 0.0);
			float3 vertexMotion = normalize(localPos) * float3(2.25, 2.25, 0.7875) * sin(dot(float4(worldPos, globalTime), float4(2.65, 2.65, 2.65, 2.65)));

			animation += instanceMotion * floraInstanceMotion;
			animation += vertexMotion * floraVertexMotion;
		#endif

		#if FLORA_WAVE_ANIMATION
			animation += getWaveAnim(worldPos);
		#endif

		#if FLORA_WIND_ANIMATION
			animation.xy += input.wind * (floraWindMotion * 2.25);
		#endif

		displacement += animation;
	#endif

	#if !FLORA_WIND_ANIMATION
		displacement.xy += floraAvgWindDisplacement * 2.25;
	#endif

	#if FLORA_LAYING
		displacement *= 1.0 - layingStrength;
	#endif

	worldPos += displacement * localPos.z;

	output.worldPos = worldPos;
	output.localPos = mul4Fast1(worldPos, viewProjMatrix);
	output.projPos = output.localPos;
	output.texCoord = input.texCoord;

	#if !DRAW_DEPTH_ONLY
		output.vegetationTexCoord.xy = float2(texCoord.x, 1.0 - texCoord.y);

		#if FLORA_LAYING
			output.vegetationTexCoord.z = layingStrength;
		#endif

		#if FLORA_PBR_LIGHTING
			float localHeight = max(input.localPos.z * (1.0 / floraLocalHeight), 0.0);
			float3 landscapeNormal = unpackNormal(tex2Dlod(floraLandscapeNormalMap, texCoord, 0.0).ga);

			#if FLORA_LAYING
				float landscapeNormalFactor = lerp(floraNormalLifting, 1.0, layingStrength);
			#else
				float landscapeNormalFactor = floraNormalLifting;
			#endif

			float3 normal = input.normal;
			normal.xy = rotate(normal.xy, rotatedTheta);
			normal = normalize(lerp(normal, landscapeNormal, landscapeNormalFactor));

			#if FLORA_NORMAL_MAP
				float3 tangent = input.tangent;
				float3 binormal = input.binormal;
				tangent.xy = rotate(tangent.xy, rotatedTheta);
				binormal.xy = rotate(binormal.xy, rotatedTheta);
				tangent = normalize(normal * dot(-tangent, normal) + tangent);
				binormal = normalize(tangent * dot(-binormal, tangent) + (normal * dot(-binormal, normal) + binormal));

				output.tbnToWorld0.xyz = float3(tangent.x, binormal.x, normal.x);
				output.tbnToWorld1.xyz = float3(tangent.y, binormal.y, normal.y);
				output.tbnToWorld2.xyz = float3(tangent.z, binormal.z, normal.z);
				output.tbnToWorld0.w = localHeight;

				#if FLORA_ANIMATION && FLORA_FAKE_SHADOW
					output.tbnToWorld1.w = animation.x;
					output.tbnToWorld2.w = animation.y;
				#endif
			#else
				output.normal = float4(normal, localHeight);

				#if FLORA_ANIMATION && FLORA_FAKE_SHADOW
					output.animation = animation.xy;
				#endif
			#endif
		#endif
	#endif

	#if USE_VERTEX_FOG
		float3 eyePos = mul3Fast1(worldPos, viewMatrix);
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir *= 1.0 / toLightDis;

		#include "vp-fog-math.slh"
	#endif

	return output;
}

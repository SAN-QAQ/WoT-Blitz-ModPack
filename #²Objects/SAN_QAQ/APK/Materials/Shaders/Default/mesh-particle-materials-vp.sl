#define SHADOW_RECEIVER 1

#include "common.slh"
#include "vp-fog-props.slh"

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

vertex_in
{
	[vertex] float4 localPos : POSITION;
	[vertex] float3 normal : NORMAL;
	[vertex] float2 texCoord0 : TEXCOORD0;

	#if VERTEX_COLOR
		[vertex] float4 color0 : COLOR0;
	#endif

	[instance] float4 color1 : COLOR1;
	[instance] float4 worldMatrix0 : TEXCOORD1;
	[instance] float4 worldMatrix1 : TEXCOORD2;
	[instance] float4 worldMatrix2 : TEXCOORD3;
	[instance] float4 spriteRect : TEXCOORD4;

	#if FRAME_BLEND
		[instance] float4 nextSpriteRect : TEXCOORD5;
	#endif

	#if FRAME_BLEND || PARTICLES_FRESNEL_TO_ALPHA
		[instance] float4 texCoord6 : TEXCOORD6; // x - animation time, y - alpha remap, z - fresnel bias, w - fresnel power.
	#endif

	#if PARTICLES_FLOWMAP
		[instance] float4 flowMapRect : TEXCOORD7;
		[instance] float2 flowSpeedAndOffset : TEXCOORD8; // x - flow speed, y - flow offset.
	#endif

	#if PARTICLES_MASK
		[instance] float4 maskSpriteRect : TANGENT;
	#endif

	#if PARTICLES_NOISE
		[instance] float4 noiseRect : NORMAL1;
		[instance] float noiseScale : NORMAL2;
	#endif

	#if PARTICLES_VERTEX_ANIMATION
		[instance] float4 vertexAnimationSpriteRect : BINORMAL;
		[instance] float vertexAnimationAmplitude : BLENDWEIGHT;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;

	#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
		float4 projPos : POSITION0;
	#endif

	float4 vertexColor : COLOR0;

	#if RECEIVE_SHADOW
		float3 shadowColor : COLOR1;
	#endif

	#if PARTICLES_MASK
		float4 texCoord0 : TEXCOORD0;
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
			float4 texCoord4 : TEXCOORD4; // xy - noise uv, z - noise scale, w - fresnel.
		#else
			float3 texCoord4 : TEXCOORD4; // xy - noise uv, z - noise scale.
		#endif
	#elif PARTICLES_FRESNEL_TO_ALPHA
		float texCoord4 : TEXCOORD4; // Fresnel.
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD5;
	#endif
};

#if PARTICLES_VERTEX_ANIMATION
	uniform sampler2D vertexAnimationTex;
#endif

[auto][a] property float4x4 viewProjMatrix;

#if PARTICLES_FRESNEL_TO_ALPHA
	[auto][a] property float3 cameraDirection;
#endif

#if RECEIVE_SHADOW || USE_VERTEX_FOG
	[auto][a] property float4 lightPosition0;
#endif

#if USE_VERTEX_FOG
	[auto][a] property float3 cameraPosition;
	[auto][a] property float4x4 viewMatrix;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	output.texCoord0.xy = float2(input.texCoord0.x * input.spriteRect.z + input.spriteRect.x, input.texCoord0.y * input.spriteRect.w + input.spriteRect.y);

	#if PARTICLES_MASK
		output.texCoord0.zw = float2(input.texCoord0.x * input.maskSpriteRect.z + input.maskSpriteRect.x, input.texCoord0.y * input.maskSpriteRect.w + input.maskSpriteRect.y);
	#endif

	#if FRAME_BLEND
		output.texCoord1 = float3(input.texCoord0.x * input.nextSpriteRect.z + input.nextSpriteRect.x, input.texCoord0.y * input.nextSpriteRect.w + input.nextSpriteRect.y, input.texCoord6.x);
	#endif

	#if PARTICLES_FLOWMAP
		float2 flowPhase = frac(float2(input.flowSpeedAndOffset.x, input.flowSpeedAndOffset.x + 0.5)) - const05List2;
		output.texCoord2 = float4(input.texCoord0.x * input.flowMapRect.z + input.flowMapRect.x, input.texCoord0.y * input.flowMapRect.w + input.flowMapRect.y, flowPhase * input.flowSpeedAndOffset.y);
		output.texCoord3 = abs(flowPhase.x) * 2.0;
	#endif

	output.vertexColor = input.color1;

	#if VERTEX_COLOR
		output.vertexColor *= input.color0;
	#endif

	#if PARTICLES_NOISE
		output.texCoord4.xyz = float3(input.texCoord0.x * input.noiseRect.z + input.noiseRect.x, input.texCoord0.y * input.noiseRect.w + input.noiseRect.y, input.noiseScale);
	#endif

	float4x4 worldMatrix = vecToMat(input.worldMatrix0, input.worldMatrix1, input.worldMatrix2);
	float3 localPos = input.localPos.xyz;

	#if PARTICLES_VERTEX_ANIMATION
		float vertexAnimationValue = tex2Dlod(vertexAnimationTex, input.texCoord0.xy * input.vertexAnimationSpriteRect.zw + input.vertexAnimationSpriteRect.xy, 0.0).x * 2.0 - 1.0;
		localPos += input.normal * (vertexAnimationValue * input.vertexAnimationAmplitude);
	#endif

	float3 worldPos = mul3Fast1(localPos, worldMatrix);
	output.localPos = mul4Fast1(worldPos, viewProjMatrix);

	#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
		output.projPos = output.localPos;
	#endif

	#if PARTICLES_FRESNEL_TO_ALPHA || RECEIVE_SHADOW
		float3 N = normalize(mul3Fast0(input.normal, worldMatrix));
	#endif

	#if PARTICLES_FRESNEL_TO_ALPHA
		float fresnelToAlpha = lerp(input.texCoord6.z, 1.0, pow(saturate(1.0 - dot(N, cameraDirection)), input.texCoord6.w));

		#if PARTICLES_NOISE
			output.texCoord4.w = fresnelToAlpha;
		#else
			output.texCoord4 = fresnelToAlpha;
		#endif
	#endif

	#if USE_VERTEX_FOG
		float3 camPos = cameraPosition;
		float3 eyePos = mul3Fast1(worldPos, viewMatrix);
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir *= 1.0 / toLightDis;

		#include "vp-fog-math.slh"
	#endif

	#if RECEIVE_SHADOW
		float NdotLShady = saturate(1.0 - dot(N, lightPosition0.xyz - worldPos));
		float3 shadowInf = getShadow(N * (shadowNormalSlopeOffset * NdotLShady) + worldPos, output.localPos.xy * (1.0 / output.localPos.w), NdotLShady);
		output.shadowColor = lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
	#endif

	return output;
}

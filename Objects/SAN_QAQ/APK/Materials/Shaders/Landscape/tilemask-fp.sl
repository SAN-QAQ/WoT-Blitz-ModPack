#include "common.slh"

#if LANDSCAPE_PBR
	#include "pbr-lighting.slh"
#endif

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

#define USE_LANDSCAPE_SCALED_TILES_NON_PBR (LANDSCAPE_SCALED_TILES_NON_PBR && LANDSCAPE_HEIGHT_BLEND_ALLOWED)

fragment_in
{
	float4 projPos : POSITION0;

	#if !DRAW_DEPTH_ONLY
		#if LANDSCAPE_PBR || RECEIVE_SHADOW
			float3 worldPos : POSITION1;
		#endif

		#if LANDSCAPE_MORPHING_COLOR
			float4 morphColor : COLOR0;
		#endif

		float4 texCoord : TEXCOORD0;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if (LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND) || LANDSCAPE_PBR
	uniform sampler2D tileMaskHeightBlend;

	#if !LANDSCAPE_PBR
		uniform sampler2D tileHeightTexture;
	#endif
#else
	uniform sampler2D tileMask;
#endif

#if LANDSCAPE_PBR
	uniform sampler2D pbrAlbedoRoughnessMap; // RGB - global Albedo attenuation, A - global Roughness attenuation
	uniform sampler2D pbrLandscapeNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - global Normal
	uniform sampler2D pbrLandscapeLightmap; // RG or AG(DXT5NM) or GA(ASTC) - baked shadow / baked AO
	uniform sampler2DArray tileAlbedoHeightArray; // RGB - Albedo, A - Height for heightblending
	uniform sampler2DArray tileNormalArray; // RG or AG(DXT5NM) or GA(ASTC) - normal
	uniform sampler2DArray tileRoughnessAOArray; // RG or AG(DXT5NM) or GA(ASTC) - roughness / AO

	[auto][a] property float lightIntensity0;
	[auto][a] property float3 cameraPosition;
	[auto][a] property float3 lightColor0;
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 invViewMatrix;
#else
	uniform sampler2D tileTexture0;
	uniform sampler2D colorTexture;

	[material][instance] property float3 tileColor0 = const1List3;
	[material][instance] property float3 tileColor1 = const1List3;
	[material][instance] property float3 tileColor2 = const1List3;
	[material][instance] property float3 tileColor3 = const1List3;
#endif

#if LANDSCAPE_USE_RELAXMAP
	uniform sampler2D relaxmap;

	[material][instance] property float relaxmapScale = 1.0;
#endif

#if LANDSCAPE_PBR || USE_LANDSCAPE_SCALED_TILES_NON_PBR
	[material][instance] property float tileScale0 = 1.0;
	[material][instance] property float tileScale1 = 1.0;
	[material][instance] property float tileScale2 = 1.0;
	[material][instance] property float tileScale3 = 1.0;
#endif

#if (LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND) || LANDSCAPE_PBR
	[material][instance] property float tilemaskWeight = 0.15;
	[material][instance] property float4 heightMapScaleColor;
	[material][instance] property float4 heightMapOffsetColor;
	[material][instance] property float4 heightMapSoftnessColor;
#endif

#if CURSOR
	uniform sampler2D cursorTexture;

	[material][instance] property float4 cursorCoordSize = float4(const0List2, const1List2);
#endif

#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
	inline float3 getHeightBlend(float3 input1, float3 input2, float3 input3, float3 input4, float4 height)
	{
		float heightMax = max(max(height.x, height.y), max(height.z, height.w));
		float4 a = max(height + heightMapSoftnessColor - float4(heightMax, heightMax, heightMax, heightMax), const00001List4);
		float4 b = a * (1.0 / dot(a, const1List4));

		return (input1 * b.x + input2 * b.y) + (input3 * b.z + input4 * b.w);
	}
#endif

#if LANDSCAPE_PBR
	inline float4 getPBRHeightBlend(float4 height)
	{
		float heightMax = max(max(height.x, height.y), max(height.z, height.w));
		float4 a = max(height + heightMapSoftnessColor - float4(heightMax, heightMax, heightMax, heightMax), const00001List4);

		return a * (1.0 / dot(a, const1List4));
	}
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 projPos = input.projPos.xyz * (1.0 / input.projPos.w);

	#if DRAW_DEPTH_ONLY
		float depthColor = projPos.z * 0.5 + 0.5;
		output.color = float4(depthColor, depthColor, depthColor, depthColor);
	#else
		float2 texCoord = input.texCoord.zw;

		#if LANDSCAPE_RELAXMAP && LANDSCAPE_USE_RELAXMAP
			texCoord *= tex2D(relaxmap, input.texCoord.xy).xy * (1.0 / relaxmapScale) - (const05List2 * (1.0 / relaxmapScale) - input.texCoord.xy);
		#endif

		#if LANDSCAPE_PBR || USE_LANDSCAPE_SCALED_TILES_NON_PBR
			float2 texCoord0 = texCoord * tileScale0;
			float2 texCoord1 = texCoord * tileScale1;
			float2 texCoord2 = texCoord * tileScale2;
			float2 texCoord3 = texCoord * tileScale3;
		#endif

		#if (LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND) || LANDSCAPE_PBR
			float4 mask = tex2D(tileMaskHeightBlend, input.texCoord.xy);
		#else
			float4 mask = tex2D(tileMask, input.texCoord.xy);
		#endif

		#if RECEIVE_SHADOW
			float3 shadowInf = getShadow(input.worldPos, projPos.xy, 0.0);
		#endif

		#if LANDSCAPE_PBR
			float2 bakedAO = tex2D(pbrLandscapeLightmap, input.texCoord.xy).ga;
			float3 polygonN = unpackNormal(tex2D(pbrLandscapeNormalMap, float2(input.texCoord.x, 1.0 - input.texCoord.y)).ga);
			float4 bakedAlbedoRoughness = tex2D(pbrAlbedoRoughnessMap, input.texCoord.xy) * 2.0;
			float4x4 baseColorMatrix = float4x4(tex2Darray(tileAlbedoHeightArray, texCoord0, 0), tex2Darray(tileAlbedoHeightArray, texCoord1, 1), tex2Darray(tileAlbedoHeightArray, texCoord2, 2), tex2Darray(tileAlbedoHeightArray, texCoord3, 3));
			float4x4 pbrMiscMatrix = float4x4(float4(tex2Darray(tileNormalArray, texCoord0, 0).ga, tex2Darray(tileRoughnessAOArray, texCoord0, 0).ga), float4(tex2Darray(tileNormalArray, texCoord1, 1).ga, tex2Darray(tileRoughnessAOArray, texCoord1, 1).ga), float4(tex2Darray(tileNormalArray, texCoord2, 2).ga, tex2Darray(tileRoughnessAOArray, texCoord2, 2).ga), float4(tex2Darray(tileNormalArray, texCoord3, 3).ga, tex2Darray(tileRoughnessAOArray, texCoord3, 3).ga));

			float4 blendFactor = getPBRHeightBlend(saturate(heightMapScaleColor * baseColorMatrix[3].w + (mask * tilemaskWeight * 2.0 + (heightMapOffsetColor - tilemaskWeight))));
			float4 blendedBaseColor = mul(blendFactor, baseColorMatrix);
			float4 blendedPBRMisc = mul(blendFactor, pbrMiscMatrix);

			float3 baseColor = saturate(blendedBaseColor.rgb * bakedAlbedoRoughness.rgb);
			float roughness = saturate(blendedPBRMisc.b * bakedAlbedoRoughness.a);
			float occlusion = saturate(blendedPBRMisc.a * bakedAO.g);

			float3 N = blendNormal(polygonN, unpackNormal(blendedPBRMisc.rg));

			#include "vector-compute.slh"

			#if RECEIVE_SHADOW
				float shadow = lerp(bakedAO.r, shadowInf.z, shadowInf.y);
			#else
				float shadow = bakedAO.r;
			#endif

			output.color.rgb = getPBR(polygonN, N, V, L, H, lightColor0 * lightIntensity0, baseColor, 0.0, roughness, occlusion, shadow, const0List3);

			#include "color-grading.slh"
		#else
			float4 colorMap = tex2D(colorTexture, input.texCoord.xy);

			#if LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL
				colorMap.rgb *= colorMap.a;
			#endif

			#if RECEIVE_SHADOW
				#if LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL
					float3 shadowColor = lerp(shadowMapShadowColor.rgb * lerp(shadowLMGateFactor.w, 1.0, saturate(colorMap.a * shadowLMGateFactor.z)), const1List3, shadowInf.x) * colorMap.rgb;
				#else
					float3 shadowColor = lerp(colorMap.rgb, lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x) * lerp(colorMap.rgb * shadowLMGateFactor.w, colorMap.rgb, saturate(dot(colorMap.rgb, rgbMixList) * shadowLMGateFactor.z)), shadowInf.y);
				#endif
			#else
				float3 shadowColor = colorMap.rgb;
			#endif

			#if USE_LANDSCAPE_SCALED_TILES_NON_PBR
				float4 tile = float4(tex2D(tileTexture0, texCoord0).r, tex2D(tileTexture0, texCoord1).g, tex2D(tileTexture0, texCoord2).b, tex2D(tileTexture0, texCoord3).a);
			#else
				float4 tile = tex2D(tileTexture0, texCoord);
			#endif

			#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
				#if USE_LANDSCAPE_SCALED_TILES_NON_PBR
					float4 heightMap = float4(tex2D(tileHeightTexture, texCoord0).r, tex2D(tileHeightTexture, texCoord1).g, tex2D(tileHeightTexture, texCoord2).b, tex2D(tileHeightTexture, texCoord3).a);
				#else
					float4 heightMap = tex2D(tileHeightTexture, texCoord);
				#endif

				output.color.rgb = getHeightBlend(tileColor0 * tile.r, tileColor1 * tile.g, tileColor2 * tile.b, tileColor3 * tile.a, saturate(heightMap * heightMapScaleColor + (mask * tilemaskWeight * 2.0 + (heightMapOffsetColor - tilemaskWeight)))) * shadowColor;
			#else
				tile = mul(tile, mask);
				output.color.rgb = (tileColor0 * tile.r + (tileColor1 * tile.g + (tileColor2 * tile.b + (tileColor3 * tile.a)))) * shadowColor;
			#endif

			output.color.rgb = toLinear(output.color.rgb * 2.0);

			#include "color-grading.slh"
		#endif

		output.color.a = 1.0;

		#if LANDSCAPE_LOD_MORPHING && LANDSCAPE_MORPHING_COLOR
			output.color = output.color * 0.25 + input.morphColor * 0.75;
		#endif

		#if CURSOR
			float4 cursorColor = tex2D(cursorTexture, input.texCoord.xy * (1.0 / cursorCoordSize.zw) + (cursorCoordSize.xy * (1.0 / cursorCoordSize.zw) + const05List2));
			output.color.rgb -= output.color.rgb * cursorColor.a;
			output.color.rgb += cursorColor.rgb * cursorColor.a;
		#endif

		#if USE_VERTEX_FOG
			output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
		#endif
	#endif

	return output;
}

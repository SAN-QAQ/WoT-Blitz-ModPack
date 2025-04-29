#include "common.slh"

fragment_in
{
	float4 projPos : POSITION0;
	float4 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D tileTexture0;
uniform sampler2D colorTexture;

#if LANDSCAPE_CURSOR
	uniform sampler2D cursorTexture;
#endif

#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
	uniform sampler2D tileHeightTexture;
	uniform sampler2D tileMaskHeightBlend;
#else
	uniform sampler2D tileMask;
#endif

#if LANDSCAPE_TOOL
	uniform sampler2D toolTexture;
#endif

[material][instance] property float3 tileColor0 = const1List3;
[material][instance] property float3 tileColor1 = const1List3;
[material][instance] property float3 tileColor2 = const1List3;
[material][instance] property float3 tileColor3 = const1List3;

#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
	[material][instance] property float4 heightMapOffsetColor;
	[material][instance] property float4 heightMapScaleColor;
	[material][instance] property float4 heightMapSoftnessColor;
#endif

#if LANDSCAPE_CURSOR
	[material][instance] property float4 cursorCoordSize = float4(const0List2, const1List2);
#endif

#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
	inline float4 getHeightBlend(float4 input1, float4 input2, float4 input3, float4 input4, float4 height)
	{
		float heightMax = max(max(height.x, height.y), max(height.z, height.w));
		float4 heightStart = heightMapSoftnessColor - float4(heightMax, heightMax, heightMax, heightMax);
		float4 a = max(height + heightStart, const00001List4);
		float4 b = a * (1.0 / dot(a, const1List4));

		return (input1 * b.x + input2 * b.y) + (input3 * b.z + input4 * b.w);
	}
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float4 color = tex2D(colorTexture, input.texCoord.xy);
	float4 tile = tex2D(tileTexture0, input.texCoord.zw);

	#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
		float4 mask = tex2D(tileMaskHeightBlend, input.texCoord.xy);
	#else
		float4 mask = tex2D(tileMask, input.texCoord.xy);
	#endif

	#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
		output.color = getHeightBlend(tileColor0 * tile.r, tileColor1 * tile.g, tileColor2 * tile.b, tileColor3 * tile.a, saturate(mask * 0.3 + (tex2D(tileHeightTexture, input.texCoord.zw) * heightMapScaleColor + (heightMapOffsetColor - float4(0.15, 0.15, 0.15, 0.15)))));
	#else
		output.color = tileColor0 * (tile.r * mask.r) + (tileColor1 * (tile.g * mask.g) + (tileColor2 * (tile.b * mask.b) + (tileColor3 * (tile.a * mask.a)))) * color;
	#endif

	output.color *= 2.0;

	#if LANDSCAPE_TOOL
		float4 toolColor = tex2D(toolTexture, input.texCoord.xy);

		#if LANDSCAPE_TOOL_MIX
			toolColor.a = 0.5;
		#endif

		output.color.rgb -= output.color.rgb * toolColor.a;
		output.color.rgb += toolColor.rgb * toolColor.a;
	#endif

	#if LANDSCAPE_CURSOR
		float4 cursorColor = tex2D(cursorTexture, input.texCoord.xy * (1.0 / cursorCoordSize.zw) - (cursorCoordSize.xy * (1.0 / cursorCoordSize.zw) - const05List2));
		output.color.rgb -= output.color.rgb * cursorColor.a;
		output.color.rgb += cursorColor.rgb * cursorColor.a;
	#endif

	return output;
}

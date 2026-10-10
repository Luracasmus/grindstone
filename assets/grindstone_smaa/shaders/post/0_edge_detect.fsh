#version 440
#extension GL_ARB_separate_shader_objects : require

#if defined GL_AMD_shader_trinary_minmax && (GL_AMD_shader_trinary_minmax == 1)
	#extension GL_AMD_shader_trinary_minmax : require
#else
	#define max3(a, b, c) max(a, max(b, c))
#endif

#include <grindstone:config.glsl>
#include <grindstone:redmean.glsl>

out lowp float gl_FragDepth;

uniform lowp sampler2D MainSampler;

layout(location = 0) out lowp vec4 fragColor;

void main() {
	const lowp ivec2 texel = ivec2(gl_FragCoord.xy);

	const lowp vec3 color = texelFetch(MainSampler, texel, 0).rgb;
	const lowp vec3 left = texelFetchOffset(MainSampler, texel, 0, ivec2(-1, 0)).rgb;
	const lowp vec3 top = texelFetchOffset(MainSampler, texel, 0, ivec2(0, -1)).rgb;

	const lowp vec2 delta = vec2(
		sq_redmean(color, left),
		sq_redmean(color, top)
	);

	// We square the contrast threshold and LCA factor to compensate for the color difference being squared,
	// making the actual color difference metric regular redmean.
	const bvec2 edges = greaterThanEqual(delta, (SMAA_THRESHOLD*SMAA_THRESHOLD).xx);

	if (any(edges)) {
		const lowp vec2 delta_max = max3(
			delta,
			vec2(
				sq_redmean(color, texelFetchOffset(MainSampler, texel, 0, ivec2(1, 0)).rgb), // Right.
				sq_redmean(color, texelFetchOffset(MainSampler, texel, 0, ivec2(0, 1)).rgb) // Bottom.
			),
			vec2(
				sq_redmean(left, texelFetchOffset(MainSampler, texel, 0, ivec2(-2, 0)).rgb), // Left-left.
				sq_redmean(top, texelFetchOffset(MainSampler, texel, 0, ivec2(0, -2)).rgb) // Top-top.
			)
		);

		const bvec2 temp = greaterThanEqual(delta, (max(delta_max.x, delta_max.y) / (SMAA_LCA*SMAA_LCA)).xx);
		const bvec2 result = bvec2(edges.x && temp.x, edges.y && temp.y); // This is required instead of `result && temp` on AMD :(

		if (any(result)) {
			fragColor = vec4(vec2(result), 0.0, 0.0);
		} else {
			discard;
		}
	} else {
		discard;
	}
}

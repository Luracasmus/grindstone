#version 440
#extension GL_ARB_separate_shader_objects : require

#if defined GL_AMD_shader_trinary_minmax && (GL_AMD_shader_trinary_minmax == 1)
	#extension GL_AMD_shader_trinary_minmax : require
#else
	#define min3(a, b, c) min(a, min(b, c))
	#define max3(a, b, c) max(a, max(b, c))
#endif

#include <grindstone:config.glsl>
#include <grindstone:srgb.glsl>

#define saturate(v) clamp(v, 0.0, 1.0)

layout(depth_unchanged) out lowp float gl_FragDepth;

uniform lowp sampler2D SwapSampler;

layout(location = 0) out lowp vec4 fragColor;

void main() {
	const lowp ivec2 texel = ivec2(gl_FragCoord.xy);

	// a b c
	// d e f
	// g h i
	const lowp vec3 b = linear(texelFetchOffset(SwapSampler, texel, 0, ivec2(0, -1)).rgb);
	const lowp vec3 d = linear(texelFetchOffset(SwapSampler, texel, 0, ivec2(-1, 0)).rgb);
	const lowp vec3 e = linear(texelFetch(SwapSampler, texel, 0).rgb);
	const lowp vec3 f = linear(texelFetchOffset(SwapSampler, texel, 0, ivec2(1, -1)).rgb);
	const lowp vec3 h = linear(texelFetchOffset(SwapSampler, texel, 0, ivec2(0, 1)).rgb);

	// Soft min. and max.
	//  a b c             b
	//  d e f * 0.5  +  d e f * 0.5
	//  g h i             h
	// These are 2.0x bigger (factored out the extra multiply).
	lowp float minimum = min3(min3(d.g, e.g, f.g), b.g, h.g);
	lowp float maximum = max3(max3(d.g, e.g, f.g), b.g, h.g);

	#ifdef CAS_BETTER_DIAGONALS
		const lowp float a = texelFetchOffset(SwapSampler, texel, 0, ivec2(-1, -1)).g;
		const lowp float c = texelFetchOffset(SwapSampler, texel, 0, ivec2(1, -1)).g;
		const lowp float g = texelFetchOffset(SwapSampler, texel, 0, ivec2(-1, 1)).g;
		const lowp float i = texelFetchOffset(SwapSampler, texel, 0, ivec2(1, 1)).g;

		// Converting to linear after the min/max here is correct,
		// since the sRGB -> linear function is increasing over [0, 1].

		minimum += min(minimum, linear(min(min3(a, c, g), i)));
		maximum += max(maximum, linear(max(max3(a, c, g), i)));
	#endif

	// Smooth minimum distance to signal limit divided by smooth max.
	const lowp float amplify = sqrt(saturate(min(minimum, 2.0 - maximum) / maximum));

	// Filter shape:
	// 0 w 0
	// w 1 w
	// 0 w 0
	const lowp float sharpness = -1.0 / mix(8.0, 5.0, CAS_SHARPNESS);
	const lowp float weight = sharpness * amplify;
	const lowp float rcp_rcp_weight = fma(weight, 4.0, 1.0); // This naming is cursed.

	fragColor = vec4(srgb(saturate(
		((b + d + f + h) * weight + e) / rcp_rcp_weight
	)), 0.0);
}

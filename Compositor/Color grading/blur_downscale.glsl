#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;


layout(set = 0, binding = 0, rgba16f) uniform image2D texture_out;
layout(set = 0, binding = 1) uniform sampler2D texture_in;


float brightness(vec3 c)
{
	return (c.x + c.y + c.z) * 0.3333;
}


void main() {
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(texture_out);
	if (texel.x >= size.x || texel.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(texel) + 0.5) / size;
	vec2 o = 0.5 / size;

	vec4 color = texture(texture_in, uv);

	// Downsample with a 4x4 box filter + anti-flicker filter
	vec4 d = vec4(o, o) * vec4(-1, -1, +1, +1);

	vec3 s1 = texture(texture_in, uv + d.xy).rgb;
	vec3 s2 = texture(texture_in, uv + d.zy).rgb;
	vec3 s3 = texture(texture_in, uv + d.xw).rgb;
	vec3 s4 = texture(texture_in, uv + d.zw).rgb;

    // Karis's luma weighted average (using brightness instead of luma)
	float s1w = 1 / (brightness(s1) + 1);
	float s2w = 1 / (brightness(s2) + 1);
	float s3w = 1 / (brightness(s3) + 1);
	float s4w = 1 / (brightness(s4) + 1);
	float one_div_wsum = 1 / (s1w + s2w + s3w + s4w);

	color.rgb = (s1 * s1w + s2 * s2w + s3 * s3w + s4 * s4w) * one_div_wsum;

	imageStore(texture_out, texel, color);
}

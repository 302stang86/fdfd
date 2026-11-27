shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 hood_color : source_color;
uniform float row_start;
uniform bool has_back = false;
varying vec3 local_normal;

void vertex() {
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(local_normal);
	vec3 fabric = texture(atlas, UV).rgb;
	float rear = 1.0 - smoothstep(-0.85, 0.25, n.z);
	float head = 1.0 - smoothstep(0.080, 0.105, UV.y - row_start);
	float luminance = dot(fabric, vec3(0.299, 0.587, 0.114));
	vec3 hair = hood_color.rgb * mix(0.65, 1.6, luminance);
	if (has_back) {
		vec3 back = texture(atlas, vec2(1.0 - UV.x, UV.y)).rgb;
		ALBEDO = mix(fabric, back, smoothstep(-0.18, 0.34, -n.z));
	} else {
		ALBEDO = mix(fabric * mix(1.0, 0.81, rear), hair, rear * head);
	}
	ROUGHNESS = 0.86;
}

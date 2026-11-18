// PS2 风格基础材质：Unlit + 顶点抖动 + affine UV + 最近邻采样。
// 光照烘进贴图或顶点色，这里不算任何光。
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform bool use_vertex_color = true;

// 顶点量化网格（屏幕纵向格数）。越小抖得越厉害。0 = 关。
uniform float snap_grid = 120.0;
// 0 = 透视正确，1 = 完全 affine。
uniform float affine = 1.0;
// 透明裁剪（贴片阴影、树叶）
uniform float alpha_cut = 0.5;

varying vec2 v_uv_w;
varying float v_w;
varying vec2 v_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap_grid > 0.0 && clip.w > 0.0) {
		vec2 grid = vec2(snap_grid * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_grid) * 0.5;
		vec2 ndc = clip.xy / clip.w;
		ndc = round(ndc * grid) / grid;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
	vec2 uv = UV * uv_scale;
	v_uv = uv;
	// 传 uv*w 和 w，片元里相除 → 屏幕空间线性插值（无透视矫正）
	v_uv_w = uv * clip.w;
	v_w = clip.w;
}

void fragment() {
	vec2 uv = mix(v_uv, v_uv_w / v_w, affine);
	vec4 tex = texture(albedo_tex, uv);
	vec3 col = tex.rgb * tint.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	ALBEDO = col;
	if (tex.a * tint.a < alpha_cut) {
		discard;
	}
}

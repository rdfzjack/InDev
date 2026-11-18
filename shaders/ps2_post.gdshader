// 低分辨率画面拉伸到窗口时的后处理：15-bit 色深 + 4x4 ordered dithering。
// 抖动按低分辨率像素对齐，不按窗口像素。
shader_type canvas_item;

uniform bool enabled = true;
uniform float levels = 31.0;        // 每通道级数，31 = 5 bit
uniform float dither_amount = 0.6;  // 0 = 只量化不抖动
uniform vec2 low_res = vec2(512.0, 384.0);

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (enabled) {
		ivec2 p = ivec2(floor(UV * low_res));
		float b = BAYER[(p.y % 4) * 4 + (p.x % 4)] / 16.0 - 0.5;
		c.rgb = floor(c.rgb * levels + 0.5 + b * dither_amount) / levels;
	}
	COLOR = c;
}

shader_type canvas_item;

#include "res://resource/default/shader/gdshaderinc/bloom.gdshaderinc"

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    color.rgb = apply_bloom(TEXTURE, UV, color.rgb, TIME, TEXTURE_PIXEL_SIZE);
    COLOR = color;
}
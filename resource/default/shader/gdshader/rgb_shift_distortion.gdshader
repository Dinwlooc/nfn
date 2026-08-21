shader_type canvas_item;

#include "res://resource/default/shader/gdshaderinc/rgb_shift.gdshaderinc"

void fragment() {
    COLOR = apply_rgb_shift(TEXTURE, UV, distortion_intensity, TEXTURE_PIXEL_SIZE);
}
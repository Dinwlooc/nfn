shader_type canvas_item;

#include "res://resource/default/shader/gdshaderinc/flash.gdshaderinc"

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    color = apply_flash(color);
    COLOR = color;
}
shader_type canvas_item;

#include "res://resource/default/shader/gdshaderinc/flash.gdshaderinc"
#include "res://resource/default/shader/gdshaderinc/sprite_frame_crossfade.gdshaderinc"

void fragment() {
    vec4 color = apply_sprite_crossfade(TEXTURE, UV);
    color = apply_flash(color);
    COLOR = color;
}
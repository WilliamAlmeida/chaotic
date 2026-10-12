// Contorno estilo desenho (técnica "casco invertido"): a malha é desenhada de novo,
// inflada na direção da normal e só com as faces de trás, em cor escura.
// A espessura é em pixels de tela, então o traço fica parecido perto e longe.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 cor_contorno : source_color = vec4(0.07, 0.04, 0.1, 1.0);
uniform float espessura_px = 2.2;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 normal_vista = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 normal_clip = (PROJECTION_MATRIX * vec4(normal_vista, 0.0)).xy;
	float comprimento = length(normal_clip);
	if (comprimento > 0.0001) {
		vec2 deslocamento = normal_clip / comprimento * espessura_px * 2.0 / VIEWPORT_SIZE;
		clip.xy += deslocamento * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = cor_contorno.rgb;
}

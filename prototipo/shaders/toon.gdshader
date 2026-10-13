// Cel shading estilo anime: luz em 2 tons com transição dura, brilho de borda
// (rim light) e um ponto de brilho especular "chapado".
shader_type spatial;

uniform vec4 cor : source_color = vec4(1.0);
// Tom multiplicado pela luz no lado da sombra (sombra colorida, nunca preta).
uniform vec4 cor_sombra : source_color = vec4(0.52, 0.48, 0.72, 1.0);
uniform float limiar : hint_range(-1.0, 1.0) = 0.05;
uniform float suavidade : hint_range(0.0, 0.3) = 0.03;
uniform float intensidade_rim : hint_range(0.0, 2.0) = 0.45;
uniform float largura_rim : hint_range(0.0, 1.0) = 0.72;
uniform float brilho_especular : hint_range(0.0, 1.0) = 0.2;
uniform vec4 emissao : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float forca_emissao = 0.0;
// 0..1: pisca branco quando o monstro leva dano.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// Modelos importados (ex.: GLB riggado) trazem a pintura nas cores de vértice.
uniform bool usar_cor_vertice = false;

void fragment() {
	// A cor de vértice do glTF chega convertida para linear duas vezes; desfaz uma.
	vec3 base = usar_cor_vertice ? cor.rgb * pow(COLOR.rgb, vec3(1.0 / 2.2)) : cor.rgb;
	ALBEDO = mix(base, vec3(1.0), flash);
	EMISSION = emissao.rgb * forca_emissao + vec3(flash * 0.6);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float sombra = LIGHT_IS_DIRECTIONAL ? smoothstep(0.35, 0.55, ATTENUATION) : 1.0;
	float queda = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	float ndl = dot(NORMAL, LIGHT);
	float iluminado = smoothstep(limiar - suavidade, limiar + suavidade, ndl) * sombra;
	vec3 tom = mix(cor_sombra.rgb, vec3(1.0), iluminado);
	DIFFUSE_LIGHT += tom * LIGHT_COLOR * queda / PI;

	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(largura_rim - 0.03, largura_rim + 0.03, rim) * iluminado;
	DIFFUSE_LIGHT += rim * intensidade_rim * LIGHT_COLOR * queda / PI;

	vec3 meio = normalize(LIGHT + VIEW);
	float especular = step(0.985, dot(NORMAL, meio)) * iluminado * brilho_especular;
	SPECULAR_LIGHT += especular * LIGHT_COLOR * queda / PI;
}

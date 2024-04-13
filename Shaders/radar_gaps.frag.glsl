#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Based on infoLOS.lua from Spring

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__


uniform sampler2D NoiseTexture;

#line 30000
in DataGS {
	vec4 g_color;
	float g_radius;
	vec4 g_worldPos; // cx, cz, fx, fz
};

out vec4 fragColor;

void main(void)
{
	float fade = length(g_worldPos.xy - g_worldPos.zw) / g_radius / 0.5;
	float noise = texture(NoiseTexture, mod(g_worldPos.zw, 256.0) / 64.0).r;
	fragColor.rgba = g_color * (1.0 - fade) * (1.0 - noise * 0.2);
}
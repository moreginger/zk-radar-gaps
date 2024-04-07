#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 30000
in DataGS {
	vec4 g_color;
};

out vec4 fragColor;

void main(void)
{
	fragColor.rgba = g_color;
}
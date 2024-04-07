#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 30000
in DataGS {
	uint g_frame;
};

out vec4 fragColor;

void main(void)
{
	fragColor.rgba = vec4(1.0, 0.0, 0.0, 0.3);
}
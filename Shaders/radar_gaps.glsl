#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 pos;
layout (location = 1) in uint frame;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out DataVS {
    vec4 v_pos;
    uint v_frame;
};

void main()
{
    v_pos = pos;
    v_frame = frame;
    // Makes something appear top middle high
    // gl_Position = cameraViewProj * vec4(100, 100, 100, 1.0);
    gl_Position = cameraViewProj * vec4(1000.0, 1000.0, 10.0, 1.0);
}

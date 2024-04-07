#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Derived from DrawPrimitiveAtUnit.geom.glsl
// Beherith (mysterme@gmail.com) claims copyright on this file. He gives the Zero-K team permission to
// use this for ZK but he would be unhappy if it were copied further without asking him, so best to ask.

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
layout(points) in;
layout(triangle_strip, max_vertices = 64) out;
#line 20000

in DataVS {
    vec4 v_pos;
    uint v_frame;
} dataIn[];

out DataGS {
    // Not required?
    uint g_frame;
};

mat3 rotY;
vec4 pos;

void offsetVertex(float x, float y, float z) {
	vec3 primitiveCoords = vec3(x, y, z);
	vec3 vecnorm = normalize(primitiveCoords);
	gl_Position = cameraViewProj * vec4(pos.xyz + rotY * (vecnorm + primitiveCoords), 1.0);
	EmitVertex();
}

#line 22000
void main() {
	pos = dataIn[0].v_pos;
    // FIXME: NO!!!
    // pos = vec4(3000, 100, 3000, 0);
    // BILLBOARD?
    rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
    // rotY = 0;

    uint frame = dataIn[0].v_frame;
    g_frame = frame;
    // float framesToShow = 30.0 * 10.0;

	// float currentFrame = timeInfo.x + timeInfo.w;
	// float radius = 20.0 * (float(frame) + framesToShow - currentFrame) / framesToShow;

    float radius = 120.0;
	
    uint numVertices = 64u;
    float internalAngle = float(numVertices - 2u) * radians(180.0) / float(numVertices);
    float addRadiusCorr = 1 / sin(internalAngle / 2.0);
    //left most vertex
    offsetVertex(-radius * 0.5, 0.0, 0.0);
    int numSides = int(numVertices) / 2;
    //for each phi in (-Pi/2, Pi/2) omit the first and last one
    for (int i = 1; i < numSides; i++){
        float phi = ((i * 3.141592) / numSides) -  1.5707963;
        float sinphi = sin(phi);
        float cosphi = cos(phi);
        offsetVertex(radius * 0.5 * sinphi, 0.0, radius * 0.5 * cosphi);
        offsetVertex(radius * 0.5 * sinphi, 0.0, -radius * 0.5 * cosphi);
    }
    // add right most vertex
    offsetVertex(radius * 0.5, 0.0, 0);
    EndPrimitive();
}
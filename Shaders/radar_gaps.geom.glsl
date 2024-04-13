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
	vec4 g_color;
	float g_radius;
	vec4 g_worldPos;
};

mat3 rotY;
vec4 pos;

void offsetVertex(float x, float y, float z) {
	vec3 primitiveCoords = vec3(x, y, z);
	vec3 vertexPos = pos.xyz + rotY * primitiveCoords;
	g_worldPos = vec4(pos.xz, vertexPos.xz);
	gl_Position = cameraViewProj * vec4(vertexPos, 1.0);
	EmitVertex();
}

#line 22000
void main() {
	pos = dataIn[0].v_pos;
	rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz

	uint frame = dataIn[0].v_frame;
	float currentFrame = timeInfo.x + timeInfo.w;
	float framesToShow = 30.0 * 30.0;
	float showFraction = (currentFrame - frame) / framesToShow;
	g_radius = 120.0 + 120.0 * showFraction;
	g_color = vec4(0.0, 0.0, 1.0, 0.5 * (1.0 - showFraction));
	
	uint numVertices = 64u;
	float internalAngle = float(numVertices - 2u) * radians(180.0) / float(numVertices);
	float addRadiusCorr = 1 / sin(internalAngle / 2.0);
	//left most vertex
	offsetVertex(-g_radius * 0.5, 0.0, 0.0);
	int numSides = int(numVertices) / 2;
	//for each phi in (-Pi/2, Pi/2) omit the first and last one
	for (int i = 1; i < numSides; i++){
		float phi = ((i * 3.141592) / numSides) -  1.5707963;
		float sinphi = sin(phi);
		float cosphi = cos(phi);
		offsetVertex(g_radius * 0.5 * sinphi, 0.0,  g_radius * 0.5 * cosphi);
		offsetVertex(g_radius * 0.5 * sinphi, 0.0, -g_radius * 0.5 * cosphi);
	}
	// add right most vertex
	offsetVertex(g_radius * 0.5, 0.0, 0);
	EndPrimitive();
}
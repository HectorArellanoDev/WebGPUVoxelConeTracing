struct Uniforms {
    cameraPosition: vec3f,
    resolution: f32,
    coneAngle: f32,
    coneRotation: f32,
}
@group(0) @binding(0) var<storage, read>  positionBuffer: array<vec4f>;
@group(0) @binding(1) var<storage, read_write>  particlesColors:   array< vec4f >;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;
@group(0) @binding(3) var texture3D: texture_3d<f32>;
@group(0) @binding(4) var textureSampler: sampler;

const MAX_DISTANCE = 500.0;
const MAX_ALPHA = 0.95;

fn sampleVoxels(pos: vec3<f32>, lod: f32) -> vec4<f32> {
    return textureSampleLevel(texture3D, textureSampler, pos, lod);
}

fn voxelConeTracing(startPos: vec3f, direction: vec3f, tanHalfAngle: f32) -> vec4<f32> {
    
    var lod = 0.;
    var color = vec3f(0.);
    var alpha = 0.;
    var occlusion = 0.;
    var voxelWorldSize = .001;
    var dist = voxelWorldSize;

    while(dist < MAX_DISTANCE && alpha < MAX_ALPHA) {
        let diameter = max(voxelWorldSize, 2. * tanHalfAngle * dist);
        let lodLevel = log2( 2 * diameter / voxelWorldSize);
        var voxelColor = sampleVoxels(startPos + dist * direction, lodLevel);
        var sub = 1. - alpha;
        var aa = voxelColor.a;
        alpha += sub * aa;
        occlusion += sub * aa / (1. + 0.03 * diameter);
        color += voxelColor.rgb * alpha;
        dist += diameter;
    }

    return vec4f(color, clamp(1. - occlusion, 0., 1.) );
}

fn shadePoint(pp: vec3f, direction: vec3f) -> vec4f {

    var ang = radians(uniforms.coneRotation);
    let s = sin(ang);
    let c = cos(ang);

    var dir1 = vec3f(0, 0, 1);
    var dir2 = vec3f(c, 0, s);
    var dir3 = vec3f(-c, 0, s);
    var dir4 = vec3f(0, c, s);
    var dir5 = vec3f(0, -c, s);

    var zAxis = normalize(direction);
    var xAxis = vec3f(1, 0, 0);
    var yAxis = vec3f(0, 1, 0);
    var UP = vec3f(0, 1, 0);
    var rot = mat3x3f(0, 0, 0, 0, 0, 0, 0, 0, 0);

    xAxis = normalize(cross(UP, zAxis));
    yAxis = normalize(cross(zAxis, xAxis));
    rot = mat3x3f(xAxis, yAxis, zAxis);

    dir1 = rot * dir1;
    dir2 = rot * dir2;
    dir3 = rot * dir3;
    dir4 = rot * dir4;
    dir5 = rot * dir5;

    var cone = voxelConeTracing(pp, dir1, uniforms.coneAngle);
    var color = cone.rgba;

    // cone = voxelConeTracing(pp, dir2, uniforms.coneAngle);
    // color += cone.rgba;

    // cone = voxelConeTracing(pp, dir3, uniforms.coneAngle);
    // color += cone.rgba;

    // cone = voxelConeTracing(pp, dir4, uniforms.coneAngle);
    // color += cone.rgba;

    // cone = voxelConeTracing(pp, dir5, uniforms.coneAngle);
    // color += cone.rgba;

    //color /= 5.;

    return color;

}


@compute @workgroup_size(256) fn main( @builtin(global_invocation_id) id: vec3<u32> ) {
    let index1D = id.x;
    var tint = particlesColors[index1D];

    //Cone tracing
    var pp = positionBuffer[index1D].rgb / uniforms.resolution;
    var direction = normalize(uniforms.cameraPosition - pp);
    direction = vec3(1, 1, 0);
    var color = vec4f(0.);

    var cone = voxelConeTracing(pp, vec3f(1, 0, 0), uniforms.coneAngle);
    color = cone.rgba;

    cone = voxelConeTracing(pp, vec3f(-1, 0, 0), uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, vec3f(0, 1, 0), uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, vec3f(0, -1, 0), uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, vec3f(0, 0, 1), uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, vec3f(0, 0, -1), uniforms.coneAngle);
    color += cone.rgba;

    color /= 6.;

    // var shade = shadePoint(pp, direction);
    // color = shade;

    color = vec4f( (color.rgb) * pow(clamp(color.a, 0, 10000), 1.), 1.);

    particlesColors[index1D] = color;
}
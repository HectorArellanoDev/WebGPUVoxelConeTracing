
struct Uniforms {
    transformMatrix: mat4x4<f32>,
    cameraPosition: vec3f,
    particleSize: f32,
    screenSize: vec2f,
    depthTest: f32,
    mixAlpha: f32,
    coneAngle: f32,
    gridRadius: f32,
    coneRotation: f32,
    scale:f32,
    amountOfColors: f32
};


@group(0) @binding(0) var<storage, read_write>  colorBuffer:    array<vec4f>;
@group(0) @binding(1) var<storage, read_write>  depthBuffer:    array<atomic<i32>>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;
@group(0) @binding(3) var<storage, read_write>  positionData:   array<vec4f>;
@group(0) @binding(4) var texture3D: texture_3d<f32>;
@group(0) @binding(5) var textureSampler: sampler;
@group(0) @binding(6) var<storage, read>  particleColor:   array< vec4f >;
@group(0) @binding(7) var<storage, read_write>  velocityBuffer:    array<vec4f>;


const MAX_DISTANCE = 128.0;
const MAX_ALPHA = 0.95;

fn sampleVoxels(pos: vec3<f32>, lod: f32) -> vec4<f32> {
    return textureSampleLevel(texture3D, textureSampler, pos, lod);
}

fn voxelConeTracing(startPos: vec3f, direction: vec3f, tanHalfAngle: f32) -> vec4<f32> {
    var lod = 0.;
    var color = vec3f(0.);
    var alpha = 0.;
    var occlusion = 0.;

    var voxelWorldSize = .05;
    var dist = voxelWorldSize;

    while(dist < MAX_DISTANCE && alpha < MAX_ALPHA) {
        let diameter = max(voxelWorldSize, 2. * tanHalfAngle * dist);
        let lodLevel = log2(2. * diameter / voxelWorldSize);
        var voxelColor = sampleVoxels(startPos + dist * direction, lodLevel);
        var sub = 1. - alpha;
        var aa = voxelColor.a;
        alpha += sub * aa;
        occlusion += sub * aa / (1. + 0.03 * diameter);
        color += sub * voxelColor.rgb;
        dist += diameter;
    }

    return vec4f(color, clamp(1. - occlusion, 0., 1.) );
}


@compute @workgroup_size(256) fn main( @builtin(global_invocation_id) id: vec3<u32> ) {
    let i = id.x;

    let rawData = positionData[i];
    let position = vec4f((rawData.rgb / uniforms.scale), rawData.a);

    var pos =  uniforms.transformMatrix * vec4f(position.rgb + vec3f(0., 0.0, 0.), 1.);
    pos.y = 1. - pos.y;
    pos.y -= 1.;

    pos.x /= pos.w;
    pos.y /= pos.w;
    pos.z /= pos.w;

    
    //Data goes in the range -1, 1
    var index2d : vec2f = pos.xy;
    index2d = floor(uniforms.screenSize * (vec2f(0.5) * index2d + vec2f(0.5)));
    
    let ii = i;
    let size = i32(uniforms.particleSize);
    let halfSize = floor( uniforms.particleSize / 2 );
    let mixer = uniforms.mixAlpha;
    let mixerInverse = 1 - mixer;
    let renderSquares = true;
    let currentDepth: i32 = i32(100000000. *  pos.z );


    //Border limits
    let limit = .99;
    if(abs(pos.x) >= limit || abs(pos.y) >= limit ) {
        return;
    }


    var direction = uniforms.cameraPosition - position.rgb;
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

    var cone = voxelConeTracing(position.rgb, dir1, uniforms.coneAngle);
    var color =  cone.aaaa;

    cone = voxelConeTracing(position.rgb, dir2, uniforms.coneAngle);
    color += cone.aaaa;

    cone = voxelConeTracing(position.rgb, dir3, uniforms.coneAngle);
    color += cone.aaaa;

    cone = voxelConeTracing(position.rgb, dir4, uniforms.coneAngle);
    color += cone.aaaa;

    cone = voxelConeTracing(position.rgb, dir5, uniforms.coneAngle);
    color += cone.aaaa;

    color /= 5.;
    //color = pow(color, vec4f(1.1));

    let textureSize = textureDimensions(texture3D).x ;

    //3d index for the 3d texture
    let pp = vec3<u32>( floor(rawData.rgb) );

    //1d index for the atomic buffer
    let index1D = pp.x + textureSize * pp.y + textureSize * textureSize * pp.z;

    let pColor = particleColor[id.x];

    var vel = normalize(velocityBuffer[id.x]);
    var angle = atan2(vel.y, vel.z);
    angle /= 3.14159265359;
    angle = abs(angle);

    let mixColor = 2. * color * mix(velocityBuffer[id.x], vec4f(1), 2. * color);
    
    let iMin = floor(angle);
    let iMax = ceil(angle * uniforms.amountOfColors);
    let mm = fract(angle);

    color *= 2.5 * mix(particleColor[ u32(iMin) ] / 255., particleColor[ u32(iMax) ] / 255., vec4f(mm) );
    color = pow(color, vec4f(2.2));


    //O(n2) speed, which means that bigger sizes of rasterization makes this thing really slow.
    //if(rawData.x > f32(textureSize)) {return;}
    for(var j = 0; j < size; j ++) {
        for(var i = 0; i < size; i ++) {

            let u = f32(i) - halfSize;
            let v = f32(j) - halfSize;
            var index : u32 = u32( (index2d.x + u + ( index2d.y + v ) * uniforms.screenSize.x) );

            let compareDepth: i32 = atomicLoad(&depthBuffer[index]);
                
            if( u * u + v * v < halfSize * halfSize) {

                var st = vec2f(u, 1. - v) / f32(halfSize);
                var z = sqrt(1. - st.x * st.x - st.y * st.y);
                var normal = vec3f(st, z);
                var diffuse = pow(max(dot(normalize(vec3f(0., 0., 1.)), normal), 0.), 2.);
                var shade = vec4f( vec3f(diffuse * 0.6 + 0.4), 1.);
                shade *= color;
                shade = pow(shade, vec4f(0.4545));

                if(currentDepth < compareDepth) {
                    
                    if(uniforms.depthTest > 0.5) {
                        atomicStore(&depthBuffer[index], currentDepth);
                        colorBuffer[index] = shade;
                    } else {
                        colorBuffer[index] = (1. - mixer) * colorBuffer[index] + mixer * color;
                    }

                } 
            }
        }
    }

    
    
}
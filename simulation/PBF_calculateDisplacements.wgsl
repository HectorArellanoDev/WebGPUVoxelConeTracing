struct Uniforms {
    uResolution: f32,
    uSearchRadius: f32,
    separation: f32,
    currentFrame: f32,
    maxParticlesPerVoxel:f32,
    vertical: f32
}

var<private> deltaPosition: vec3<f32> = vec3f(0.);

@group(0) @binding(0) var<storage, read>  positionBufferIN: array<vec4f>;
@group(0) @binding(1) var<storage, read_write> positionBufferOUT: array<vec4f>;
@group(0) @binding(2) var<storage, read>  indicesBuffer: array<u32>;
@group(0) @binding(3) var<uniform>  uniforms: Uniforms;

fn addToSum(particlePosition: vec4f, nParticlePosition: vec4f) {

    var distance = (particlePosition.rgb - nParticlePosition.rgb);
    let r = length(distance);

    let r1 = floor(particlePosition.a) / 4.;
    let r2 = floor(nParticlePosition.a) / 4.;

    let separation = 0.5 * ( r1 + r2);

    if(r > 0 && r < separation) {
        deltaPosition -= (r - separation) * normalize(distance) * r2 / (r1 + r2);
    }

}

@compute @workgroup_size(256) fn main( @builtin(global_invocation_id) id: vec3<u32> ) {

    var index1D = id.x;

    let particlePosition = positionBufferIN[index1D];
    let radius = particlePosition.a;
    let gridPosition = vec3<i32>(floor(particlePosition.rgb));
    let resolution = i32(uniforms.uResolution);

    var offsets = array<vec3<i32>, 27>();

    //Center
    offsets[0] = vec3<i32>(0, 0, 0);

    //Faces
    offsets[1] = vec3<i32>(0, 0, 1);
    offsets[2] = vec3<i32>(0, 0, -1);
    offsets[3] = vec3<i32>(0, 1, 0);
    offsets[4] = vec3<i32>(0, -1, 0);
    offsets[5] = vec3<i32>(1, 0, 0);
    offsets[6] = vec3<i32>(-1, 0, 0);

    //Aristas
    offsets[7] = vec3<i32>(0, 1, 1);
    offsets[8] = vec3<i32>(1, 0, 1);
    offsets[9] = vec3<i32>(1, 1, 0);
    offsets[10] = vec3<i32>(0, 1, -1);
    offsets[11] = vec3<i32>(1, 0, -1);
    offsets[12] = vec3<i32>(1, -1, 0);
    offsets[13] = vec3<i32>(0, -1, 1);
    offsets[14] = vec3<i32>(-1, 0, 1);
    offsets[15] = vec3<i32>(-1, 1, 0);
    offsets[16] = vec3<i32>(0, -1, -1);
    offsets[17] = vec3<i32>(-1, 0, -1);
    offsets[18] = vec3<i32>(-1, -1, 0);

    //Corners
    offsets[19] = vec3<i32>(1, 1, 1);
    offsets[20] = vec3<i32>(1, 1, -1);
    offsets[21] = vec3<i32>(1, -1, 1);
    offsets[22] = vec3<i32>(-1, 1, 1);
    offsets[23] = vec3<i32>(1, -1, -1);
    offsets[24] = vec3<i32>(-1, -1, 1);
    offsets[25] = vec3<i32>(-1, 1, -1);
    offsets[26] = vec3<i32>(-1, -1, -1);

    let maxParticlesPerVoxel = u32(uniforms.maxParticlesPerVoxel);


    for(var i = 0; i < 27; i ++) {

        let neighborsVoxel = gridPosition + offsets[i];
        let voxelIndex = neighborsVoxel.x + neighborsVoxel.y * resolution + neighborsVoxel.z * resolution * resolution;
        
        for(var j: u32 = 0; j < maxParticlesPerVoxel; j ++) {
            let index = indicesBuffer[maxParticlesPerVoxel * u32(voxelIndex) + u32(j) ];
            if(index > 0) {
                addToSum(particlePosition, positionBufferIN[index]);
            } else {
                break;
            }
        }
    
    }

    var endPosition = particlePosition.rgb + deltaPosition;
    var center = uniforms.uResolution * vec3f(0.5, 0.35, 0.3);
    var boxSize = uniforms.uResolution * vec3f(0.47, 0.245, 0.2);   
    
    if(uniforms.vertical > 0.) {
        center = uniforms.uResolution * vec3f(0.5, 0.57, 0.3);
        boxSize = uniforms.uResolution * vec3f(0.25, 0.46, 0.2);
    }

    //Collision handling
    
    let xLocal = endPosition - center;
    let contactPointLocal = min(boxSize, max(-boxSize, xLocal));
    let contactPoint = contactPointLocal + center;
    let distance = length(contactPoint - particlePosition.rgb);

    if(distance > 0.0) {endPosition = contactPoint;};



    //Check a simple sphere collisions
    // center = uniforms.mousePosition;
    // let radius = 0.1 * uniforms.uResolution;
    // let d = length(endPosition.yz - center.yz);
    // if(d < radius) {
    //     var n = normalize(vec3f(0., endPosition.yz - center.yz));
    //     endPosition = center + n * radius;
    // }

    positionBufferOUT[index1D] = vec4f(endPosition, radius);
}

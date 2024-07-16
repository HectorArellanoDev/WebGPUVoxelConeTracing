struct Uniforms {
    cameraOrientation: mat4x4f,

    acceleration: vec3f,
    deltaTime: f32,

    mousePosition: vec3f,
    textureSize: f32,

    mouseDirection: vec3f,
    currentFrame: f32,

    amountOfVoxels: f32,
    logoWave: f32,
    maxParticlesPerVoxel: f32
}

@group(0) @binding(0) var<storage, read>  initBuffer: array<vec4f>;
@group(0) @binding(1) var<storage, read_write>  positionBuffer: array<vec4f>;
@group(0) @binding(2) var<storage, read>  velocityBuffer: array<vec4f>;
@group(0) @binding(3) var<storage, read_write>  counterBuffer:    array<atomic<u32>>;
@group(0) @binding(4) var<storage, read_write>  indicesBuffer:    array<u32>;
@group(0) @binding(5) var<storage, read_write>  raytracingCounterBuffer:    array<atomic<u32>>;
@group(0) @binding(6) var<storage, read_write>  raytracingIndicesBuffer:    array<u32>;
@group(0) @binding(7) var<uniform>  uniforms: Uniforms;


//Analitic derivatives of the potentials for the curl noise, based on: http://weber.itn.liu.se/~stegu/TNM084-2019/bridson-siggraph2007-curlnoise.pdf

var<private> curlScaler: f32 = 0.0003;

fn t1() -> f32 {
    return curlScaler * uniforms.currentFrame * 10.45987602934;
}

fn t2() -> f32 {
    return curlScaler * uniforms.currentFrame * 20.0975932;
}

fn t3() -> f32 {
    return curlScaler * uniforms.currentFrame * 5.5752;
}

fn t4() -> f32 {
    return -curlScaler * uniforms.currentFrame * 13.5098745;
}

fn t5() -> f32 {
    return curlScaler * uniforms.currentFrame * 54.98752;
}

fn t6() -> f32 {
    return - curlScaler * uniforms.currentFrame * 23.535798450;
}

fn t7() -> f32 {
    return - curlScaler * uniforms.currentFrame * 45.52948;
}

fn t8() -> f32 {
    return curlScaler * uniforms.currentFrame * 23.4234521243;
}

fn dP3dY( v: vec3<f32>) -> f32 {
    var noise = 0.0;
    noise += 3. * cos(v.z * 1.8 + v.y * 3. - 194.58 + t1() ) + 4.5 * cos(v.z * 4.8 + v.y * 4.5 - 83.13 + t2() ) + 1.2 * cos(v.z * -7.0 + v.y * 1.2 -845.2 + t3() ) + 2.13 * cos(v.z * -5.0 + v.y * 2.13 - 762.185 + t4() );
    noise += 5.4 * cos(v.x * -0.48 + v.y * 5.4 - 707.916 + t5() ) + 5.4 * cos(v.x * 2.56 + v.y * 5.4 + -482.348 + t6() ) + 2.4 * cos(v.x * 4.16 + v.y * 2.4 + 9.872 + t7() ) + 1.35 * cos(v.x * -4.16 + v.y * 1.35 - 476.747 + t8() );
    return noise;
}

fn dP2dZ( v: vec3<f32>) -> f32 {
    return -0.48 * cos(v.z * -0.48 + v.x * 5.4 -125.796 + t5() ) + 2.56 * cos(v.z * 2.56 + v.x * 5.4 + 17.692 + t6() ) + 4.16 * cos(v.z * 4.16 + v.x * 2.4 + 150.512 + t7() ) -4.16 * cos(v.z * -4.16 + v.x * 1.35 - 222.137 + t8() );
}

fn dP1dZ( v: vec3<f32>) -> f32 {
    var noise = 0.0;
    noise += 3. * cos(v.x * 1.8 + v.z * 3. + t1() ) + 4.5 * cos(v.x * 4.8 + v.z * 4.5 + t2() ) + 1.2 * cos(v.x * -7.0 + v.z * 1.2 + t3() ) + 2.13 * cos(v.x * -5.0 + v.z * 2.13 + t4() );
    noise += 5.4 * cos(v.y * -0.48 + v.z * 5.4 + t5() ) + 5.4 * cos(v.y * 2.56 + v.z * 5.4 + t6() ) + 2.4 * cos(v.y * 4.16 + v.z * 2.4 + t7() ) + 1.35 * cos(v.y * -4.16 + v.z * 1.35 + t8() );
    return noise;
}

fn dP3dX( v: vec3<f32>) -> f32 {
    return -0.48 * cos(v.x * -0.48 + v.y * 5.4 - 707.916 + t5() ) + 2.56 * cos(v.x * 2.56 + v.y * 5.4 + -482.348 + t6() ) + 4.16 * cos(v.x * 4.16 + v.y * 2.4 + 9.872 + t7() ) -4.16 * cos(v.x * -4.16 + v.y * 1.35 - 476.747 + t8() );
}

fn dP2dX( v: vec3<f32>) -> f32 {
    var noise = 0.0;
    noise += 3. * cos(v.y * 1.8 + v.x * 3. - 2.82 + t1() ) + 4.5 * cos(v.y * 4.8 + v.x * 4.5 + 74.37 + t2() ) + 1.2 * cos(v.y * -7.0 + v.x * 1.2 - 256.72 + t3() ) + 2.13 * cos(v.y * -5.0 + v.x * 2.13 - 207.683 + t4() );
    noise += 5.4 * cos(v.z * -0.48 + v.x * 5.4 -125.796 + t5() ) + 5.4 * cos(v.z * 2.56 + v.x * 5.4 + 17.692 + t6() ) + 2.4 * cos(v.z * 4.16 + v.x * 2.4 + 150.512 + t7() ) + 1.35 * cos(v.z * -4.16 + v.x * 1.35 - 222.137 + t8() );
    return noise;
}

fn dP1dY( v: vec3<f32>) -> f32 {
    return -0.48 * cos(v.y * -0.48 + v.z * 5.4 + t5() ) + 2.56 * cos(v.y * 2.56 + v.z * 5.4 + t6() ) +  4.16 * cos(v.y * 4.16 + v.z * 2.4 + t7() ) -4.16 * cos(v.y * -4.16 + v.z * 1.35 + t8());
}

fn curlNoise(p : vec3<f32> ) -> vec3<f32> {
    let x = dP3dY(p) - dP2dZ(p);
    let y = dP1dZ(p) - dP3dX(p);
    let z = dP2dX(p) - dP1dY(p);
    return normalize(vec3<f32>(x, y, z));
}

const GRID_RATIO = 8;

@compute @workgroup_size(256) fn main( @builtin(global_invocation_id) id: vec3<u32> ) {

    let i = id.x;

    //Apply the forces

    var position = positionBuffer[i].rgb;
    var velocity = velocityBuffer[i].rgb;
    var logoPos = initBuffer[i].rgb;

    var pos = position;

    //Apply different noise function
    //position -= vec3f(0.16) * curlNoise( .0125 * pos );
    var dt = uniforms.deltaTime;

    var curl = .003;
    var amp = 0.16;
    var freq = 0.3 + abs(0.3 * cos(0.1 * uniforms.currentFrame * 3.1415962 / 180.));
    for(var k = 0; k < 1; k ++) {
        var c = curlNoise(freq * pos );
        position += curl * vec3f(amp) * c * (1 - uniforms.logoWave);
        amp /= 2.;
        freq *= 2.;
    } 

    //Apply the acceleration force

    let initPos = position;
    var acceleration = uniforms.acceleration; //* (1 - uniforms.logoWave);
    acceleration += 500 * (logoPos - position) * uniforms.logoWave;

    var p1 = uniforms.cameraOrientation * vec4f(position, 1.);
    var p2 = uniforms.cameraOrientation * vec4f(uniforms.mousePosition, 1.);

    var intensity = 1. - length(p1.xy - p2.xy) / (5. + 15 * clamp(length(uniforms.mouseDirection), 0, 1) );
    intensity = clamp(intensity, 0., 1.);

    acceleration += 0.07 * uniforms.mouseDirection * intensity / (dt * dt) + uniforms.acceleration;
    
    position += dt * (velocity + dt * acceleration);
    
    //Save back the position
    positionBuffer[i] = vec4f(position, positionBuffer[i].a);


    //Grid acceleration for the simulation.
    let textureSize = i32(uniforms.textureSize);
    var baseGridPosition = vec3<i32>( floor(position) );
    var voxelPosition = baseGridPosition;
    var index1D = u32(voxelPosition.x + textureSize * voxelPosition.y + textureSize * textureSize * voxelPosition.z);
    var indexGrid: u32 = 0;
    let atomicCounter = atomicAdd(&counterBuffer[index1D], 1);

    let maxParticlesPerVoxel = u32(uniforms.maxParticlesPerVoxel);
    if(atomicCounter < maxParticlesPerVoxel) {
        indicesBuffer[ u32( u32(maxParticlesPerVoxel * index1D) + u32(atomicCounter) )] = i;
    }



    //Place particles inside the grid acceleration
    let smallSize = textureSize / GRID_RATIO;

    //3d index for the grid acceleration
    var direction = vec3<i32>(sign(position - floor(position) - vec3f(0.5) ));
    
    var offsets = array<vec3<i32>, 8>();
    offsets[0] = vec3<i32>(0, 0, 0);
    offsets[1] = vec3<i32>(direction.x, 0, 0);
    offsets[2] = vec3<i32>(0, direction.y, 0);
    offsets[3] = vec3<i32>(0, 0, direction.z);
    offsets[4] = vec3<i32>(0, direction.y, direction.z);
    offsets[5] = vec3<i32>(direction.x, 0, direction.z);
    offsets[6] = vec3<i32>(direction.x, direction.y, 0);
    offsets[7] = vec3<i32>(direction.x, direction.y, direction.z);
        

    for(var j = 0; j < 8; j ++) {

        voxelPosition = baseGridPosition + offsets[j];
        index1D = u32(voxelPosition.x + textureSize * voxelPosition.y + textureSize * textureSize * voxelPosition.z);

        //Try to rasterise or voxelize the particle among possible voxels.
        let raytracerCounter = atomicAdd(&raytracingCounterBuffer[index1D], 1);

        if(raytracerCounter < 20) {
            raytracingIndicesBuffer[ u32( u32(20 * index1D) + u32(raytracerCounter) )] = i;
        }

    }


}
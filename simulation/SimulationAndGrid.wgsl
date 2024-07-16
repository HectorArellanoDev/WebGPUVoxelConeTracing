struct Uniforms{
    curlSpeed: f32,
    gridRadius: f32,
    currentFrame: f32
}

@group(0) @binding(0) var<storage, read_write>  positionData:   array<vec4f>;
@group(0) @binding(1) var<storage, read>  initialPositionData:  array<vec4f>;
@group(0) @binding(2) var<storage, read_write>  counterBuffer:    array<atomic<i32>>;
@group(0) @binding(3) var texture3D: texture_storage_3d<rgba16float, write>;
@group(0) @binding(4) var<uniform> uniforms: Uniforms;
@group(0) @binding(5) var<storage, read_write>  indicesBuffer:    array<u32>;


//Analitic derivatives of the potentials for the curl noise, based on: http://weber.itn.liu.se/~stegu/TNM084-2019/bridson-siggraph2007-curlnoise.pdf

//Analitic derivatives of the potentials for the curl noise, based on: http://weber.itn.liu.se/~stegu/TNM084-2019/bridson-siggraph2007-curlnoise.pdf

fn t1() -> f32 {
    return uniforms.currentFrame * 0.5432895;
}

fn t2() -> f32 {
    return uniforms.currentFrame * 9.5432895;
}

fn t3() -> f32 {
    return uniforms.currentFrame * 4.535463;
}

fn t4() -> f32 {
    return -uniforms.currentFrame * 1.534534;
}

fn t5() -> f32 {
    return uniforms.currentFrame * 2.42345;
}

fn t6() -> f32 {
    return - uniforms.currentFrame * 5.53450;
}

fn t7() -> f32 {
    return - uniforms.currentFrame * 5.5345354313;
}

fn t8() -> f32 {
    return uniforms.currentFrame * 4.4234521243;
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

@compute @workgroup_size(256) fn main( @builtin(global_invocation_id) id: vec3<u32> ) {

    let i = id.x;

    var particlePosition = positionData[i];

    //Run the curl simulation
    let curl = uniforms.curlSpeed * curlNoise(particlePosition.xyz);

    particlePosition.x += curl.x;
    particlePosition.y += curl.y;
    particlePosition.z += curl.z;
    particlePosition.w += 1.;

    if( particlePosition.w > 1000.) {
        
        particlePosition = initialPositionData[i]; 

    }

    positionData[i] = particlePosition; 

    //normalize the position to define the texture3D
    let minPosition = vec3f(-uniforms.gridRadius);
    let maxPosition = vec3f(uniforms.gridRadius);
    let scale = maxPosition - minPosition;
    let ae = abs(scale);
    let s = max(max(ae.x, ae.y), ae.z);
    var uvw = particlePosition.xyz; 
    uvw -= minPosition;
    uvw /= s;

    let textureSize = textureDimensions(texture3D).x ;

    //3d index for the 3d texture
    let position = vec3<u32>( floor(f32(textureSize) * uvw) );

    //1d index for the atomic buffer
    let index1D = position.x + textureSize * position.y + textureSize * textureSize * position.z;

    //Increase the counter and set the index for the 3d indices buffer
    let amountOfParticlesInVoxel = atomicLoad(&counterBuffer[index1D]);
    indicesBuffer[ u32( u32(4 * index1D) + u32(amountOfParticlesInVoxel) )] = i;
    if(amountOfParticlesInVoxel < 4) {
        atomicAdd(&counterBuffer[index1D], 1);
    }

    //Here I shouls save the color somehow, maybe setting up the
    //atomics to save an integer with the accumulated color?
    textureStore(texture3D, position, vec4f( 1. ) );

}
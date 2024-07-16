struct Uniforms {
    cameraOrientation: mat4x4f,

    mousePosition: vec3f,
    deltaTime: f32,

    textureSize: f32,
    scatter: f32,
    amountOfColors: f32,
    occlusion: f32,
    
    logoWave: f32,
    lightIntensity: f32
}

const EPSILON: f32 = 0.001;
 

@group(0) @binding(0) var<storage, read>  positionBufferOLD: array<vec4f>;
@group(0) @binding(1) var<storage, read>  positionBufferUPDATED: array<vec4f>;
@group(0) @binding(2) var<storage, read_write>  velocityBuffer: array<vec4f>;
@group(0) @binding(3) var<uniform>  uniforms: Uniforms;
@group(0) @binding(4) var texture3D: texture_storage_3d<rgba16float, write>;
@group(0) @binding(5) var<storage, read>  colorPalette:   array< vec4f >;
@group(0) @binding(6) var<storage, read_write>  particlesColors:   array< vec4f >;

@compute @workgroup_size(256) fn main( @builtin(global_invocation_id) id: vec3<u32> ) {

    let index1D = id.x;
    var tint = vec4f(0);
    var velocity = positionBufferUPDATED[index1D].rgb - positionBufferOLD[index1D].rgb;
    velocity /= (max(uniforms.deltaTime, EPSILON));

    let f = fract(positionBufferUPDATED[index1D].a);
    var angle = f;
    var mixer = angle * uniforms.amountOfColors;
    var iMin = floor(mixer);
    var iMax = ceil(mixer);
    tint = mix(colorPalette[ u32(iMin) ], colorPalette[ u32(iMax) ], f );

    velocity *= (1. - 0.1 * uniforms.logoWave);

    velocityBuffer[index1D] = vec4f(velocity, 1.);

    //tint = vec4f(1, 0, 0, 1);
    particlesColors[index1D] = tint;
    
      
    //Setting up the color information for the particles
    //this is related to the cone tracing  
    let textureSize = u32(uniforms.textureSize);
    let coneTextureSize = f32(textureDimensions(texture3D).x);
    var conePosition = vec3<u32>( floor( coneTextureSize * positionBufferUPDATED[index1D].rgb / f32(textureSize) ) );
    
    var p1 = uniforms.cameraOrientation * vec4f( positionBufferUPDATED[index1D].rgb, 1.);
    var p2 = uniforms.cameraOrientation * vec4f(uniforms.mousePosition, 1.);

    var radius = 7.;
    var lightIntensity = radius - length(p1.xy - p2.xy);
    lightIntensity = 10. * clamp(lightIntensity, 0., radius) / radius;
    
    var kk = fract(positionBufferUPDATED[index1D].a); 
    var light = f32( kk > 0.93 || (kk > 0.7 && lightIntensity > 0.));

    var scatter = uniforms.scatter;

    let ss = i32(floor(1.4 * positionBufferUPDATED[index1D].a));
    for(var i = -ss; i <= ss; i ++) {
        for(var j = -ss; j <= ss; j ++) {
            for(var k = -ss; k <= ss; k ++) {
                if(i * i + j * j + k * k < ss * ss) {
                    var conePosition = vec3<i32>(i, j , k) + vec3<i32>( floor( coneTextureSize * positionBufferUPDATED[index1D].rgb / f32(textureSize) ) );
                    textureStore(texture3D, conePosition, vec4f(uniforms.lightIntensity *  light * tint.rgb , uniforms.occlusion ) );  
                }
            }
        }
    }

}
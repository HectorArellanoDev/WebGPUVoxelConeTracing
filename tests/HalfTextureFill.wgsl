

struct Uniforms {
    lightIntensity: f32,
    occlusion: f32,
    ambientLight: f32,
    vertical: f32
}

@group(0) @binding(0) var texture3D: texture_storage_3d<rgba16float, write>;
@group(0) @binding(1) var<uniform>  uniforms: Uniforms;


@compute @workgroup_size(1, 1, 1) fn main( @builtin(global_invocation_id) id: vec3<u32> ) {

    let textureSize = textureDimensions(texture3D).x;
    let index1D = id.x + textureSize * id.y + textureSize * textureSize * id.z;

    var tSize = f32(textureSize);
    var col = vec3f(uniforms.ambientLight);
    var occlusion = 0.0;

    if(uniforms.vertical > 0.) {

        // Shape occlusion
        let l = vec3f(f32(id.x), f32(id.y), f32(id.z));
        let t = f32(textureSize);
        var ol = l.x < t * 0.25 || l.x > t * 0.75;
        ol = ol || (l.y < 0.1 * t || l.y > 0.9 * t);
        ol = ol || (l.z < 0.02 * t);

        if(ol) {
            occlusion = uniforms.occlusion;
        }
        
        //Lighting
        var ll = l.x > t * 0.27 && l.x < t * 0.73;
        ll = ll && (l.y > t * 0.9);
        ll = ll && (l.z > t * 0.1 && l.z < t * 0.5);
        if(ll) {
            col = uniforms.lightIntensity * vec3f(0.5, 0.6, .6) ; 
        }

    } else {

        // Shape occlusion
        let l = vec3f(f32(id.x), f32(id.y), f32(id.z));
        let t = f32(textureSize);
        var ol = l.x < t * 0.03 || l.x > t * 0.97;
        ol = ol || (l.y < 0.1 * t || l.y > 0.59 * t);
        ol = ol || (l.z < 0.02 * t);

        if(ol) {
            occlusion = uniforms.occlusion;
        }
        
        //Lighting
        var ll = l.x > t * 0.1 && l.x < t * 0.9;
        ll = ll && (l.y > t * 0.6);
        ll = ll && (l.z > t * 0.1 && l.z < t * 0.5);
        if(ll) {
            col = uniforms.lightIntensity * vec3f(0.5, 0.6, .6) ; 
        }
    }



    textureStore(texture3D, id, vec4f(col, occlusion));

}


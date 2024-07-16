struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
  @location(1) normal: vec3f,
  @location(2) position3D: vec3f
};

struct Uniforms {
    modelViewMatrix: mat4x4<f32>,
    perspectiveMatrix: mat4x4<f32>,
    modelMaxtrix: mat4x4<f32>,
    orientationMatrix: mat3x3<f32>,
    coneAngle: f32,
    coneRotation: f32,
    cameraPosition: vec3f,
    resolution: f32,
    IOR:f32,
    raytrace: f32,
    amountOfVoxels: f32,
    mirror: f32,
    vertical: f32
};

@group(0) @binding(0) var<storage, read>  positionBuffer:   array<vec4f>;
@group(0) @binding(1) var<storage, read>  normalBuffer:   array<vec4f>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;
@group(0) @binding(3) var texture3D: texture_3d<f32>;
@group(0) @binding(4) var textureSampler: sampler;

//For the raytracer
@group(0) @binding(5) var<storage, read>  particlesIndicesBuffer:   array<i32>;
@group(0) @binding(6) var<storage, read>  particlesPositionBuffer:   array<vec4f>;
@group(0) @binding(7) var<storage, read>  particlesColorBuffer:   array<vec4f>;
@group(0) @binding(8) var<storage, read>  velocityBuffer:   array<vec4f>;
@group(0) @binding(9) var bgTexture: texture_2d<f32>;


@vertex fn vs( @builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
    
    let positionData = positionBuffer[vertexIndex];
    let normalData = normalBuffer[vertexIndex];
    var projection = uniforms.modelViewMatrix * vec4f(positionData.rgb, 1.);
    var position3D = uniforms.modelMaxtrix * vec4f(positionData.rgb, 1.);

    projection = uniforms.perspectiveMatrix * projection;
    
    var output: VertexOutput;
    output.position = projection;
    output.position3D = position3D.rgb;
    var rot = mat3x3(1, 0, 0, 0, 1, 0, 0, 0, 1);
    if(uniforms.vertical > 0) {
        rot = mat3x3(0, -1, 0, 1, 0, 0, 0, 0, 1);
    }
    output.normal = rot * normalize(normalBuffer[vertexIndex].rgb);

    output.uv = vec2f(positionData.a, normalData.a);
    return output;
}


struct FragmentData {
  @location(0) color: vec4f,
  @location(1) velocity: vec4f
}

const MAX_DISTANCE = 800.0;
const MAX_ALPHA = 0.95;
const OUTER_RADIUS = 0.4255;
const INNER_RADIUS = 0.385;
const LIGHT_POS = 0.035;
const MAX_ITERATIONS = 200;
const GRID_RATIO = 8;
const RADIUS = .25; //0.5 * 0.5 it's squared to avoid the square root in checkHit. *1
const REFRACT_COLOR = vec4f(0.83333, 1, 1, 1.0);

const EPSILON = 1.e-10 ;
const acne = .05;
var<private> hitPosition: vec4f = vec4f(0.);
var<private> hitColor: vec4f = vec4f(0.);
var<private> hitVelocity: vec4f = vec4f(0.);
var<private> sphereD: f32 = 0;


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
        let lodLevel = log2(   diameter / voxelWorldSize);
        var voxelColor = sampleVoxels(startPos + dist * direction, lodLevel);
        var sub = 1. - alpha;
        var aa = voxelColor.a;
        alpha += sub * aa;
        occlusion += sub * aa / (1. + 0.03 * diameter);
        color +=  voxelColor.rgb * alpha;
        dist += diameter;
    }

    return vec4f(color, clamp(1. - occlusion, 0., 1.) );
}


var<private> sphereIntersection = 0.;
fn checkHit(startPos: vec3f, center: vec4f, rayDirection: vec3f) -> bool {
    var L = center.rgb - startPos;
    var l = length(L);
    var tCA = dot(L, rayDirection);
    var d = l * l - tCA * tCA;
    var radius = center.a / 10.;
    var r2 = radius * radius;
    var tHC = sqrt(r2 - d);
    sphereD = d;
    sphereIntersection = tCA - tHC;
    return d >= 0. && d <= r2 * 0.7 && tCA >= 0.;
}

fn raytrace(startPos: vec3f, rayDirection: vec3f, refractionMode: bool) -> bool {

    var index = -1000;
    var deltaDist = abs(1. / max(abs(rayDirection), vec3(EPSILON)));
    var rayStep = sign(rayDirection);
    var stepForward = vec3f(0);
    
    var initPos = uniforms.resolution * (startPos + acne * rayDirection);
    var pos = initPos;
    var mapPos = floor(pos);
    var sideDist = (rayStep * (mapPos - pos + 0.5) + 0.5) * deltaDist;
    var res = i32(uniforms.resolution);
    var limits = vec3f(uniforms.resolution);
    var dist = 0.;
    var nPos = vec3f(0.);
    var inside = false;

    //Traverse the particles
    for(var i = 0; i < MAX_ITERATIONS; i ++) {
                
        stepForward = step(sideDist.xyz, sideDist.yxy) * step(sideDist.xyz, sideDist.zzx);
        sideDist += stepForward * deltaDist;
        pos += stepForward * rayStep;
        mapPos = floor(pos);

        //Check borders
        var borders = length(pos.yz / uniforms.resolution - vec2f(0.5)) > INNER_RADIUS;
        borders = borders || mapPos.x < 0.1 * uniforms.resolution;
        borders = borders || mapPos.x > 0.4 * uniforms.resolution;
        
        if(borders) {
           // return false;
        }
        
        var d = 100000.;
        var center = vec4f(0.);
        var l = 0.;
        var sphereDistance = 0.;
        var cc = 0.;
        let MAX_SPHERES_PER_VOXEL = 3;

        let index1D = (i32(mapPos.x)) + res * (i32(mapPos.y)) + res * res * (i32(mapPos.z));

        for(var z = 0; z < 20; z ++) {
            var particleId = 20 * index1D + z;
            var voxelData = particlesIndicesBuffer[particleId];
            
            if(voxelData == 0) {
                break;
            }

            center = particlesPositionBuffer[voxelData];
            let check = checkHit(initPos, center, rayDirection);
            l = sphereIntersection;
            if(check && l < d) {
                index = voxelData;
                cc = center.a;
                sphereDistance = sphereD;
                d = l;
            }
        }

        if(index > -1000) {
            hitColor = particlesColorBuffer[index];
            hitColor = vec4f(hitColor.rgb * pow(1. - sqrt(abs(sphereDistance)) / (0.5 * cc), 2.), 1.); 
            hitVelocity = velocityBuffer[index];
            return true;
        }
        
    }

    return false;
}


fn Fresnel(incom: vec3f, normal: vec3f, index_internal: f32, index_external: f32) -> f32 {
    var eta = index_internal / index_external;
 	var cos_theta1 = dot(incom, normal);
 	var cos_theta2 = 1.0 - (eta * eta) * (1.0 - cos_theta1 * cos_theta1);

 	if (cos_theta2 < 0.0) {
        return 1.0;
    } else {
 		cos_theta2 = sqrt(cos_theta2);
 		var fresnel_rs = (index_internal * cos_theta1 - index_external * cos_theta2) / (index_internal * cos_theta1 + index_external * cos_theta2);
 		var fresnel_rp = (index_internal * cos_theta2 - index_external * cos_theta1) / (index_internal * cos_theta2 + index_external * cos_theta1);
 		return (fresnel_rs * fresnel_rs + fresnel_rp * fresnel_rp) * 0.5;
 	}
}

fn shadePoint(pp: vec3f, direction: vec3f) -> vec4f {

    var ang = radians(uniforms.coneRotation);
    let s = sin(ang);
    let c = cos(ang);

    var dir1 = vec3f(0, 0, 1);
    var dir2 = vec3f(s, 0, c);
    var dir3 = vec3f(-s, 0, c);
    var dir4 = vec3f(0, s, c);
    var dir5 = vec3f(0, -s, c);

    var UP = vec3f(0, 1, 0);
    var xAxis = vec3f(1, 0, 0);
    var yAxis = vec3f(0, 1, 0);
    var zAxis = normalize(direction);

    var rot = mat3x3f(0, 0, 0, 0, 0, 0, 0, 0, 0);

    if( abs(dot(UP, zAxis)) < 0.9) {

        xAxis = normalize(cross(UP, zAxis));
        yAxis = normalize(cross(zAxis, xAxis));
        rot = mat3x3f(xAxis, yAxis, zAxis);

    } else {

        UP = vec3f(0, 0, 1);
        xAxis = normalize(cross(UP, zAxis));
        yAxis = normalize(cross(zAxis, xAxis));
        rot = mat3x3f(xAxis, yAxis, zAxis);

        var dir1 = vec3f(0, 1, 0);
        var dir2 = vec3f(s, c, 0);
        var dir3 = vec3f(-s, c, 0);
        var dir4 = vec3f(0, c, s);
        var dir5 = vec3f(0, c, -s);

    }

    dir1 = rot * dir1;
    dir2 = rot * dir2;
    dir3 = rot * dir3;
    dir4 = rot * dir4;
    dir5 = rot * dir5;

    var cone = voxelConeTracing(pp, dir1, uniforms.coneAngle);
    var color =  cone.rgba;

    cone = voxelConeTracing(pp, dir2, uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, dir3, uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, dir4, uniforms.coneAngle);
    color += cone.rgba;

    cone = voxelConeTracing(pp, dir5, uniforms.coneAngle);
    color += cone.rgba;

    color /= 5.;

    return color;

}

fn sampleSphericalMap(v: vec3f) -> vec2f {

    var uv = vec2f(atan2(v.z, -v.x), asin(v.y));
    uv *= vec2(0.1591, 0.3183);
    uv += vec2f(0.5, 0.5);

    return vec2(1 - uv.x, 1 - uv.y);
}

@fragment fn fs(input: VertexOutput) -> FragmentData {

    // if(input.position3D.z > 0.5){
    //        discard;
    // }

    var fragmentData: FragmentData;

    var pp = input.position3D;
    var eye = normalize(pp - uniforms.cameraPosition);

    var shade = shadePoint(pp, normalize(input.normal));

    if(uniforms.raytrace > 0.) {
        pp = pp - eye * 0.2;
    }
    var rayRefract = normalize(refract(eye, input.normal, 1. / uniforms.IOR));
    var rayReflect = normalize(reflect(eye, input.normal));

    var kR = clamp(Fresnel(-eye, input.normal, 1, uniforms.IOR), 0, 1);
    var kT = 1. - kR;

    var reflectColor = vec4f(0.);
    var refractColor = vec4f(0.);
    var reflectVelocity = vec4f(0.);
    var refractVelocity = vec4f(0.);

    var color = vec4f(0.);


    //////////////////////////////////////////////
    //Regular shading
    //////////////////////////////////////////////

    if(uniforms.raytrace == 0.) {
        color = vec4f(shade.rgb * shade.a, 1.);
        if(uniforms.mirror > 0.5) {
            color *= clamp(1. - 1.5 * input.position3D.y, 0, 1);
        }

        //fragmentData.color = vec4f(0.5 * input.normal + 0.5, 1.);
        fragmentData.color = color;
        fragmentData.velocity = vec4f(0, 0, input.position.z, uniforms.mirror);
        return fragmentData;
    }


    //////////////////////////////////////////////
    //Reflections
    //////////////////////////////////////////////

    if(raytrace(pp, rayReflect, false) ) {
        reflectColor = hitColor;
        reflectVelocity = hitVelocity;
    } else {
        reflectColor = textureSampleLevel(bgTexture, textureSampler, sampleSphericalMap(rayReflect), 0);
    }

    if(raytrace(pp, rayRefract, true) ) {
        refractColor = hitColor;
        refractVelocity = hitVelocity;
    } else {
        refractColor = textureSampleLevel(bgTexture, textureSampler, sampleSphericalMap(rayRefract), 0);
    }

    refractColor *= REFRACT_COLOR;

    color = kR * reflectColor + kT * refractColor;
    
    if(uniforms.mirror > 0.5) {
        color *= clamp(1. - 1.5 * input.position3D.y, 0, 1);
    }


    fragmentData.color = color * vec4f(shade.rgb * shade.a, 1.);
    if(uniforms.vertical > 0.) {
        //fragmentData.color = color + vec4f(shade.rgb * shade.a, 1.) * step(1, dot(input.normal, vec3(0, 1, 0)));
    }

    var velocity = kR * reflectVelocity + kT * refractVelocity ;
    var vel = uniforms.orientationMatrix * velocity.rgb;
    velocity = vec4f( clamp(abs(vel.xy) / 60, vec2f(0.), vec2f(1.) ), input.position3D.y,  uniforms.mirror);


    fragmentData.velocity = vec4f(vel, 1.);
    return fragmentData;
}
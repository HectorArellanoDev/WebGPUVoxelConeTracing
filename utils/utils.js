Promise.create = function() {
    const promise = new Promise((resolve, reject) => {
        this.temp_resolve = resolve;
        this.temp_reject = reject;
    });
    promise.resolve = this.temp_resolve;
    promise.reject = this.temp_reject;
    delete this.temp_resolve;
    delete this.temp_reject;
    return promise;
};

var device = null;

let getDevice = async _ => {
    const adapter = await navigator.gpu?.requestAdapter();
    device = await adapter?.requestDevice();
    if(!device) {
        console.log("error finding device");
        return null;
    }
    return device;
}


let getShader = async path => {
    let response = await fetch(path);
    let shader = await response.text();
    return shader;
}

let getPipeline = async path => {

    //let ready = Promise.create();

    const shader = await getShader(path);
    const module = device.createShaderModule({
        label: `${path} module`,
        code: shader
    })

    let pipeline = device.createComputePipeline(
        {
            label: `${path} pipeline`,
            layout: "auto",
            compute: {
                module: module,
                entryPoint: "main"
            }
        }
    )

    //ready.resolve();

    return {
        pipeline
    }
}

const random = (min, max) => {
    if(min === undefined) {
        min = 0; 
        max = 1;
    } else {
        if(max === undefined) {
            max = min;
            min = 0;
        }
    }

    return min + Math.random() * (max - min);
}

class PipelineData {
    constructor() {
        this.label = null;
        this.passDescriptor = null;
        this.pipeline = null;
        this.bindGroup = null;
        this.uniformsData = null;
        this.uniformsBuffer = null;
    }

    setBindGroup = entries => {
        this.bindGroup = device.createBindGroup( {
            label:`${this.label} bind group`,
            layout: this.pipeline.getBindGroupLayout(0),
            entries
        })
    }
}


async function setupRenderingPipeline(label, 
                                        shaderPath, 
                                        sampleCount= 1, 
                                        _targets = [{format: navigator.gpu.getPreferredCanvasFormat()}],
                                        depthEnabled = true,
                                        _cullMode = "none") {

    let pipelineData = new PipelineData();

    const shader = await getShader(shaderPath);
    const module = device.createShaderModule(
        {
            label: `${label} module`,
            code: shader
        }
    )

    const pipelineDescriptor = {
        label: `${label} pipeline`,
        layout: 'auto',
        vertex: {
            module,
            entryPoint: 'vs'
        },
        fragment: {
            module,
            entryPoint: 'fs',
            targets: _targets
        },
        primitive: {
            topology: 'triangle-list',
            cullMode: _cullMode
          },
        multisample: {
            count: sampleCount
        }
    }

    const attachments = _targets.map(el => {
        return {
            clearView: [1, 1, 1, 1],
            storeOp: "store",
            loadOp: "clear"
        }
    })

    const renderPassDescriptor = {
        label: `${label} rendering pass descriptor`,
        colorAttachments: attachments
    }

    if(depthEnabled) {
        pipelineDescriptor.depthStencil = {
            depthWriteEnabled: true,
            depthCompare: 'less',
            format: 'depth32float'
        }

        renderPassDescriptor.depthStencilAttachment = {
            depthClearValue: 1.0,
            depthStoreOp: 'store',
            depthLoadOp: "clear"
        }
    }

    const pipeline = device.createRenderPipeline(pipelineDescriptor)

    pipelineData.label = label;
    pipelineData.pipeline = pipeline;
    pipelineData.passDescriptor = renderPassDescriptor;

    return pipelineData;
}


async function setupPipeline(label, 
                            shaderPath, 
                            uniforms = null,
                            bindingBuffers = null) {

    let pipelineData = new PipelineData();
    let pipelineReady = Promise.create();

    getPipeline(shaderPath).then(
        response => {
            pipelineData.pipeline = response.pipeline;
            pipelineReady.resolve();
        }
    );

    await pipelineReady;

    pipelineData.label = label;

    if(uniforms) {
        pipelineData.uniformsData = new Float32Array(uniforms);

        pipelineData.uniformsBuffer = device.createBuffer(
            {
                label:`${label} uniforms buffer`,
                size: pipelineData.uniformsData.byteLength,
                usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
            }
        )

        device.queue.writeBuffer(pipelineData.uniformsBuffer, 0, pipelineData.uniformsData);
    }


    if(bindingBuffers) {
        let entries = bindingBuffers.map( (data, index) => {return {binding: index, resource: {buffer: data == "uniforms" ? pipelineData.uniformsBuffer : data}} });

        pipelineData.bindGroup = device.createBindGroup( {
            label:`${label} bind group`,
            layout: pipelineData.pipeline.getBindGroupLayout(0),
            entries
        })
    }

    // console.log(`${label} ready`);

    return pipelineData;

}

async function get(path) {

    let result;
    let ready = Promise.create();
    fetch(path).then(data => {
        data.json().then( response => {
            result = response;
            ready.resolve();
        })
    })
    
    await ready;
    return result;
}

async function loadGeometry(label, path) {

    let result = await get(path);

    let buffersData = {}
    let buffers = {};

    for(let id in result) {
        const data = new Float32Array(result[id]);
        let orderedData = data;

        if(id == "position" || id == "normal") {

            orderedData = [];
            for(let i = 0; i < data.length; i += 3) {
                orderedData.push(data[i + 0]);
                orderedData.push(data[i + 1]);
                orderedData.push(data[i + 2]);
                orderedData.push(1);
            }
            buffers.length = orderedData.length / 4;
            orderedData = new Float32Array(orderedData);
        }

        buffersData[id] = orderedData;

    }

    //Encode the UV into the position and normal

    let posIndex = 0;
    for(let i = 0; i < buffersData.uv.length; i += 2) {
        buffersData.position[posIndex + 3] = buffersData.uv[i + 0];
        buffersData.normal[posIndex + 3] = buffersData.uv[i + 1];
        posIndex += 4;
    }

    let ids = {position: "", normal: ""}

    for(let id in ids) {

        buffers[id] = device.createBuffer({
            label: `${label} ${id} buffer`,
            size: buffersData[id].byteLength,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
        });
    
        device.queue.writeBuffer(buffers[id], 0, buffersData[id]);
    }

    return buffers;
}

async function loadImageBitmap(url) {
    const res = await fetch(url);
    const blob = await res.blob();
    return await createImageBitmap(blob, { colorSpaceConversion: 'none' });
}


async function textureFromImage(url) {
    const source = await loadImageBitmap(url);
    const texture = device.createTexture({
      label: url,
      format: 'rgba8unorm',
      size: [source.width, source.height],
      usage: GPUTextureUsage.TEXTURE_BINDING |
             GPUTextureUsage.COPY_DST |
             GPUTextureUsage.RENDER_ATTACHMENT,
    });

    device.queue.copyExternalImageToTexture(
        { source, flipY: true },
        { texture },
        { width: source.width, height: source.height },
    );

    return texture;
}


export {
    getDevice,
    getShader,
    random,
    getPipeline,
    setupPipeline,
    setupRenderingPipeline,
    loadGeometry,
    textureFromImage
}

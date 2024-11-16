/** @type { HTMLCanvasElement } */
let canvas;
/** @type { WebGLRenderingContext } */
let webgl;
/** @type { WebAssembly.Instance } */
let wasm_instance;
/** @type { WebAssembly.Memory } */
let wasm_memory;
/** @type { Map<number, WebGLShader> } */
let shaders = new Map(); 
let next_shader = 0;

/**
 * @typedef {{
 *    index: number,
 *    info: WebGLActiveInfo}
 * } Attribute
 * 
 * @typedef {{
 *    gl: WebGLProgram, 
 *    attributes: Map<string, Attribute>, 
 *    uniforms: Map<string, WebGLActiveInfo>}
 * } Program
 * */

/** @type { Map<number, Program> } */
let programs = new Map(); 
let next_program = 0;
/** @type { Map<number, WebGLBuffer> } */
let buffers = new Map(); 
let next_buffer = 0;

function call(ptr, fnPtr) {
   wasm_instance.exports.callPtr(ptr, fnPtr);
}

function getData (c_ptr, len) {
   return new Uint8Array(
      wasm_memory.buffer,
      c_ptr,
      len
   );
}

function getStr (c_ptr, len) {
   return new TextDecoder().decode(getData(c_ptr, len));
}

const env = {
   _log: function (ptr, len) {
      console.log(getStr(ptr, len));
   },
   init: function () {
      const body = document.getElementsByTagName("body").item(0);
      canvas = document.createElement("canvas");
      webgl = canvas.getContext("webgl");
      if(webgl == null) {
         throw new Error('No WebGL support on browser');
      }
      body.append(canvas);
   },
   deinit: function () {
      webgl.finish();
   },
   clear: function (r, g, b, a) {
      webgl.clearColor(r, g, b, a);
      webgl.clear(webgl.COLOR_BUFFER_BIT);
   },
   run: function (ptr, fnPtr) {
      function frame() {
         canvas.width = canvas.clientWidth;
         canvas.height = canvas.clientHeight;
         webgl.viewport(0, 0, canvas.width, canvas.height);
         call(ptr, fnPtr);
         requestAnimationFrame(frame);
      }
      requestAnimationFrame(frame);
      throw new Error("Dummy error");
   },
   time: function () {
      return performance.now() / 1000;
   },
   initShader: function (type, source_ptr, source_len) {
      const shader = ({
         0 : webgl.createShader(webgl.VERTEX_SHADER),
         1 : webgl.createShader(webgl.FRAGMENT_SHADER)
      }) [type] || null;

      if(shader == null) {
         throw new Error('Invalid shader type');
      }

      webgl.shaderSource(shader, `precision mediump float;\n${getStr(source_ptr, source_len)}`);
      webgl.compileShader(shader);


      if(!webgl.getShaderParameter(shader, webgl.COMPILE_STATUS)){
         throw new Error(`Failed to compile shader ${webgl.getShaderInfoLog(shader)}`)
      }
      const handle = next_shader++;
      shaders.set(handle, shader);
      return handle;
   },
   deinitShader: function (handle) {
      webgl.deleteShader(shaders.get(handle) ?? null);
   },
   initProgram: function (shader1_handle, shader2_handle) {
      const program = webgl.createProgram();
      if(program == null) {
         throw new Error(`Failed to create program}`);
      }

      const shader1 = shaders.get(shader1_handle);
      const shader2 = shaders.get(shader2_handle);

      if(!shader1 || !shader2) {
         throw new Error("Failed to shaders attach, shader is not");
      }
      webgl.attachShader(program, shader1);
      webgl.attachShader(program, shader2);
      webgl.linkProgram(program);
      
      if(!webgl.getProgramParameter(program, webgl.LINK_STATUS)) {
         throw new Error(`Failed to link program:${gl.getProgramInfoLog(program)}`);
      }
      
      const attribute_count = webgl.getProgramParameter(program, webgl.ACTIVE_ATTRIBUTES);

      /** @type {Map<string, Attribute>}*/
      const attributes = new Map();

      for(let i = 0; i < attribute_count; i++) {
         const attribute = webgl.getActiveAttrib(program, i);
         if(attribute) {
            attributes.set(attribute.name, {index: i, info: attribute});
         }
      }
      const uniform_count = webgl.getProgramParameter(program, webgl.ACTIVE_UNIFORMS);

      /** @type {Map<string, WebGLActiveInfo>}*/
      const uniforms = new Map();

      for(let i = 0; i < uniform_count; i++) {
         const uniform = webgl.getActiveUniform(program, i);
         if(uniform) {
            uniforms.set(uniform.name, uniform);
         }
      }

      webgl.useProgram(program);

      const handle = next_program++;
      programs.set(handle, {gl: program, attributes: attributes, uniforms: uniforms});
      return handle;
   },
   useProgram: function(handle) {
      const program = programs.get(handle);
      if(program) {
         webgl.useProgram(program.gl);
      }
   },
   deinitProgram: function (handle) {
      const program = programs.get(handle);
      if(program) {
         return;
      }
      programs.delete(handle);
      webgl.deleteProgram(program.gl);
   },
   initVertexBuffer: function(data_ptr, data_len) {
      const vertex_buffer = webgl.createBuffer();
      if(vertex_buffer == null) {
         throw new Error("Failed to create buffer");
      }

      webgl.bindBuffer(webgl.ARRAY_BUFFER, vertex_buffer);
      webgl.bufferData(webgl.ARRAY_BUFFER, getData(data_ptr, data_len), webgl.STATIC_DRAW);

      const handle = next_buffer++;
      buffers.set(handle, vertex_buffer);
      return handle;
   },
   deinitVertexBuffer: function(js_handle) {
      const buffer = buffers.get(js_handle) ?? null;
      buffers.delete(js_handle);
      webgl.deleteBuffer(buffer);
   },
   bindVertexBuffer: function(js_handle){
      const vertex_buffer = buffers.get(js_handle) ?? null;
      webgl.bindBuffer(webgl.ARRAY_BUFFER, vertex_buffer);
   },
   vertexAttribPointer: function(
      program_handle,
      name_ptr,
      name_len,
      size,
      type,
      normalized,
      stride,
      offset,
   ) {
      const program = programs.get(program_handle);
      
      if(!program) {
        return;
      }
      let gl_type;
      const attribute = program.attributes.get(getStr(name_ptr, name_len));

      if(!attribute) {
         return;
      }

      switch(type) {
         case 0: 
            gl_type = webgl.FLOAT;
            break;
         default:
            throw new Error("Unknown type");
      }

      webgl.enableVertexAttribArray(attribute.index);
      webgl.vertexAttribPointer(
         attribute.index,
         size,
         gl_type,
         normalized,
         stride,
         offset,
      );
   },
   drawArrays: function(mode, first, count) {
      let gl_mode;
      switch(mode) {
         case 0:
            gl_mode = webgl.POINTS;
            break;
         case 1:
            gl_mode = webgl.LINES;
            break;
         case 2:
            gl_mode = webgl.LINE_LOOP;
            break;
         case 3:
            gl_mode = webgl.LINE_STRIP;
            break;
         case 4:
            gl_mode = webgl.TRIANGLES;
            break;
         case 5:
            gl_mode = webgl.TRIANGLE_STRIP;
            break;
         case 6:
            gl_mode = webgl.TRIANGLE_FAN;
            break;
         default:
            throw new Error("No support for modes beside triangles");
      }

      webgl.drawArrays(gl_mode, first, count);
   },
};

export async function init(wasmPath) {
   let promise = fetch(wasmPath);
   WebAssembly.instantiateStreaming(promise, {
      env: env
   }).then((result) => {
      wasm_instance = result.instance;
      wasm_memory = wasm_instance.exports.memory;
      wasm_instance.exports._start();
   });
}
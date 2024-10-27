/** @type { HTMLCanvasElement } */
let canvas;
/** @type { WebGLRenderingContext } */
let webgl;
/** @type { WebAssembly.Instance } */
let wasm_instance;
/** @type { WebAssembly.Memory } */
let wasm_memory;

function call(ptr, fnPtr) {
   wasm_instance.exports.callPtr(ptr, fnPtr);
}

function get_c_str (c_ptr, len) {
   const slice = new Uint8Array(
      wasm_memory.buffer,
      c_ptr,
      len
   );
   return new TextDecoder().decode(slice);
}

const env = {
   printSlice: function (ptr, len) {
      console.log(get_c_str(ptr, len));
   },
   geocInit: function () {
      const body = document.getElementsByTagName("body").item(0);
      canvas = document.createElement("canvas");
      webgl = canvas.getContext("webgl");
      body.append(canvas);
   },
   geocDeinit: function () {
      webgl.finish();
   },
   compileGLShader: function (gl) {
      if (!gl) {
         alert('No WebGL support on browser');
         throw new Error('No WebGL support on browser');
      }
   },
   clearColor: function (r, g, b, a) {
      webgl.clearColor(r, g, b, a);
   },
   clearBits: function (bits) {
      webgl.clear(bits);
      // webgl.clear(webgl.COLOR_BUFFER_BIT);
   },
   geocRun: function (ptr, fnPtr) {
      function frame() {
         call(ptr, fnPtr);
         requestAnimationFrame(frame);
      }
      requestAnimationFrame(frame);
   },
   geocTime: function () {
      return performance.now / 1000;
   }
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
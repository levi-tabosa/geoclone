/** @type { HTMLCanvasElement } */
let canvas;
/** @type { WebGLRenderingContext } */
let webgl;

export function geocInit() {
   const body = document.getElementsByTagName("body").item(0);
   canvas = document.createElement("canvas");
   webgl = canvas.getContext("webgl");
   body.append(canvas);
}

export function geoDeinit() {
   webgl.finish();
}

export function compileGLShader(gl) {
   if (!gl) {
      alert('No WebGL support on browser');
      throw new Error('No WebGL support on browser');
   }
}

export function glClearColor(r, g, b, a) {
   webgl.clearColor(r, g, b, a);
   webgl.clear(webgl.COLOR_BUFFER_BIT);
}

export function glClearBits(bits) {
   webgl.clear(webgl.COLOR_BUFFER_BIT);
}

export function printSlice(ptr, len) {
   console.log(String.fromCharCode(new Uint8Array(ptr, len)));
}

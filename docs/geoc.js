/** WebGL and WASM Definitions **/
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
*
* @typedef {{
*    x: number,
*    y: number}
* } Pos
*
* @typedef {{
*    ptr: number,
*    angles_fn_ptr: number,
*    get_ax_fn_ptr: number,
*    zoom_fn_ptr: number,
*    insert_fn_ptr: number,
*    clear_fn_ptr: number,
*    cube_fn_ptr: number,
*    pyramid_fn_ptr: number,
*    sphere_fn_ptr: number,
*    cone_fn_ptr: number,
*    rotate_fn_ptr: number,
*    scale_fn_ptr: number,
*    translate_fn_ptr: number
*    }
* } Scene
* */

/** Context and Globals **/
/** @type { HTMLCanvasElement } */
let canvas;
/** @type { WebGLRenderingContext } */
let webgl;
/** @type { WebAssembly.Instance } */
let wasm_instance;
/** @type { WebAssembly.Memory } */
let wasm_memory;
/** @type { Map<number, WebGLShader> } */
const shaders = new Map();
let next_shader = 0;
/** @type { Map<number, Program> } */
const programs = new Map();
let next_program = 0;
/** @type { Map<number, WebGLBuffer> } */
const buffers = new Map();
let next_buffer = 0;

const interval = 30,
 frames = 25,
 fps = 200;
let is_pressed = false;

/** @type { Scene } */
const scene = {
 ptr: 0,
 angles_fn_ptr: 0,
 get_ax_fn_ptr: 0,
 zoom_fn_ptr: 0,
 insert_fn_ptr: 0,
 clear_fn_ptr: 0,
 cube_fn_ptr: 0,
 pyramid_fn_ptr: 0,
 sphere_fn_ptr: 0,
 cone_fn_ptr: 0,
 rotate_fn_ptr: 0,
 scale_fn_ptr: 0,
 translate_fn_ptr: 0,
};

function getData(c_ptr, len) {
 return new Uint8Array(wasm_memory.buffer, c_ptr, len);
}

function getStr(c_ptr, len) {
 return new TextDecoder().decode(getData(c_ptr, len));
}

function call(ptr, fnPtr) {
 wasm_instance.exports.draw(ptr, fnPtr);
}

const up_listener = () => {
 is_pressed = false;
};

const down_listener = () => {
 is_pressed = true;
};

const mouse_listener = (e) => {
 const { left, top, width, height } = canvas.getBoundingClientRect();
 if (is_pressed) {
   wasm_instance.exports.setAngles(
     scene.ptr,
     scene.angles_fn_ptr,
     ((e.clientY - top) * Math.PI * 2) / height,
     ((e.clientX - left) * Math.PI * 2) / width
   );
 }
};

const swipe_listener = (e) => {
 const { left, top, width, height } = canvas.getBoundingClientRect();
 if (is_pressed) {
   wasm_instance.exports.setAngles(
     scene.ptr,
     scene.angles_fn_ptr,
     ((e.touches[0].clientY - top) * Math.PI * 2) / height,
     ((e.touches[0].clientX - left) * Math.PI * 2) / width
   );
 }
};

const wheel_listener = (e) => {
 wasm_instance.exports.setZoom(
   scene.ptr,
   scene.zoom_fn_ptr,
   (e.deltaY >> 6) * 0.1
 );
};

const resize_listener = (entries) => {
 const { width, height } = entries[0].contentRect;
 canvas.width = width;
 canvas.height = height;
 webgl.viewport(0, 0, width, height);

 const program = programs.get(0);
 const u_aspect_ratio = webgl.getUniformLocation(program.gl, "aspect_ratio");
 webgl.uniform1f(u_aspect_ratio, width / height);
};

function createButtonListeners(scene_handler) {
 return [
   () => {
     const x = input1.value;
     const y = input2.value;
     const z = input3.value;
     scene_handler.addVector(x, y, z);
     input1.value = input2.value = input3.value = "";
   },
   () => scene_handler.clear(),
   () => {
     const x = input1.value;
     const y = input2.value;
     const z = input3.value;
     if (x || y || z) {
       scene_handler.rotate(x, y, z);
     } else {
       scene_handler.toggleAutoRotation();
     }
   },
   () => scene_handler.insertCube(),
   () => console.log("Toggle"),
   () => {
     const factor = input1.value;
     if (factor) {
       scene_handler.scale(factor);
     } else {
       alert("Use the left input box to input factor");
     }
   },
   () => scene_handler.insertPyramid(),
   () => {},
   () => {
     const x = input1.value;
     const y = input2.value;
     const z = input3.value;
     if (x || y || z) {
       scene_handler.translate(x, y, z);
     }
   },
   () => scene_handler.insertSphere(),
   () => {},
   () => {},
   () => scene_handler.insertCone(),
   () => scene_handler.project(),
   () => {},
   () => {},
   () => scene_handler.reflect(),
   () => {},
 ];
}

const btn_listeners = [];

function createButtonGrid() {
 const grid = document.createElement("div");
 grid.id = "button-grid";

 const labels = [
   "Insert",
   "Clear",
   "Rotate",
   "Cube",
   "Toggle",
   "Scale",
   "Pyramid",
   "Text",
   "Translate",
   "Sphere",
   "Text",
   "Text",
   "Cone",
   "Projection",
   "Text",
   "Text",
   "Reflection",
   "Text",
 ];

 labels.forEach((label, index) => {
   const btn = createButton(
     `grid-btn-${index + 1}`,
     label,
     btn_listeners[index]
   );
   btn.className = "floating-button";
   grid.appendChild(btn);
 });

 return grid;
}

function createToggleGridButton() {
 return createButton("toggle-grid-btn", "Btns", () => {
   document.getElementById("button-grid").classList.toggle("hidden");
 });
}

function createVectorList() {
 const vectorList = document.createElement("div");
 vectorList.id = "vector-list";
 vectorList.className = "floating-list";
 return vectorList;
}

function createToggleVectorListButton() {
 return createButton("toggle-vector-list-btn", "VECTORS", () => {
   document.getElementById("vector-list").classList.toggle("hidden");
 });
}

function createButton(id, text, onClick) {
 const btn = document.createElement("button");
 btn.id = id;
 btn.textContent = text;
 btn.addEventListener("click", onClick);
 return btn;
} // Delegate methods matching Zig Scene/Handler methods
class SceneHandler {
 /**
  * Creates an instance of SceneHandler.
  * @param {Object} wasm_instance - The WebAssembly instance.
  * @param {Object} scene - The scene object.
  */
 constructor(wasm_instance, scene) {
   this.wasm_instance = wasm_instance;
   this.scene = scene;
   this.vectors = [];
   this.shapes = [];
   this.selected_indexes = [];
   this.is_rotating = false;
   this.rotation_interval = null;
 }

 addVector(x, y, z) {
   const [xf, yf, zf] = [parseFloat(x), parseFloat(y), parseFloat(z)];
   if (![xf, yf, zf].some(isNaN)) {
     this.wasm_instance.exports.insertVector(
       this.scene.ptr,
       this.scene.insert_fn_ptr,
       xf,
       yf,
       zf
     );
     this.vectors.push({ x: xf, y: yf, z: zf });
     this.addVectorToList(xf.toFixed(2), yf.toFixed(2), zf.toFixed(2));
   }
 }

 clear() {
   this.wasm_instance.exports.clear(this.scene.ptr, this.scene.clear_fn_ptr);
   this.clearVectorList();
   this.vectors = [];
 }

 insertShape(shape) {
   const shapeMap = {
     Cube: this.scene.cube_fn_ptr,
     Pyramid: this.scene.pyramid_fn_ptr,
     Sphere: this.scene.sphere_fn_ptr,
     Cone: this.scene.cone_fn_ptr,
   };

   if (shapeMap[shape]) {
     this.wasm_instance.exports[`insert${shape}`](
       this.scene.ptr,
       shapeMap[shape]
     );
     this.shapes.push(shape);
   } else {
     console.error(`Shape ${shape} is not supported.`);
   }
 }

 insertCube() {
   this.insertShape("Cube");
 }

 insertPyramid() {
   this.insertShape("Pyramid");
 }

 insertSphere() {
   this.insertShape("Sphere");
 }

 insertCone() {
   this.insertShape("Cone");
 }
 rotate(angle_x, angle_y, angle_z) {
   const idxs_len = this.selected_indexes.length;
   if (idxs_len > 0) {
     const r_step = {
       x: angle_x / frames,
       y: angle_y / frames,
       z: angle_z / frames,
     };
     let curr = 0;
     const buffer = new Uint32Array(this.wasm_instance.exports.memory.buffer);
     const offset = buffer.length - idxs_len;

     buffer.set(this.selected_indexes, offset);

     const rotateAxis = (axis, step) => {
       this.wasm_instance.exports.rotate(
         this.scene.ptr,
         this.scene.rotate_fn_ptr,
         offset * 4,
         idxs_len,
         axis === "x" ? step : 0,
         axis === "y" ? step : 0,
         axis === "z" ? step : 0
       );
     };

     const r_interval = setInterval(() => {
       if (curr <= frames) {
         if (angle_x !== 0) rotateAxis("x", r_step.x);
       } else if (curr <= frames * 2) {
         if (angle_y !== 0) rotateAxis("y", r_step.y);
       } else {
         if (angle_z !== 0) rotateAxis("z", r_step.z);
       }
       curr++;
     }, interval);
     setTimeout(() => clearInterval(r_interval), frames * 3 * interval);

     this.selected_indexes.forEach((idx) => {
       let { x, y, z } = this.vectors[idx];

       const rotateVector = (x, y, z, angle, axis) => {
         switch (axis) {
           case "x":
             return {
               x,
               y: y * Math.cos(angle) - z * Math.sin(angle),
               z: y * Math.sin(angle) + z * Math.cos(angle),
             };
           case "y":
             return {
               x: z * Math.sin(angle) + x * Math.cos(angle),
               y,
               z: z * Math.cos(angle) - x * Math.sin(angle),
             };
           case "z":
             return {
               x: x * Math.cos(angle) - y * Math.sin(angle),
               y: x * Math.sin(angle) + y * Math.cos(angle),
               z,
             };
         }
       };

       ({ x, y, z } = rotateVector(x, y, z, angle_z, "z"));
       ({ x, y, z } = rotateVector(x, y, z, angle_y, "y"));
       ({ x, y, z } = rotateVector(x, y, z, angle_x, "x"));

       this.vectors[idx] = { x, y, z };
     });
     this.updateVectorList();
   } else {
     alert("Please select elements for rotation");
   }
 }

 scale(factor) {
   const idxs_len = this.selected_indexes.length;
   if (idxs_len > 0) {
     const s_step = Math.pow(factor, 1 / frames);

     const buffer = new Uint32Array(wasm_memory.buffer);
     const offset = buffer.length - idxs_len;

     buffer.set(this.selected_indexes, offset);
     const s_interval = setInterval(() => {
       this.wasm_instance.exports.scale(
         this.scene.ptr,
         this.scene.scale_fn_ptr,
         offset * 4, // u32 4 bytes pointer alignment
         idxs_len,
         s_step
       );
     }, interval);
     setTimeout(() => clearInterval(s_interval), frames * interval);

     this.selected_indexes.forEach((idx) => {
       let { x, y, z } = this.vectors[idx];
       x *= factor;
       y *= factor;
       z *= factor;
       this.vectors[idx] = { x, y, z };
     });

     this.updateVectorList();
   } else {
     alert("Please select elements for scaling");
   }
 }

 translate(dx, dy, dz) {
   const idxs_len = this.selected_indexes.length;
   if (idxs_len > 0) {
     const t_step = { x: dx / frames, y: dy / frames, z: dz / frames };
     const buffer = new Uint32Array(wasm_memory.buffer);
     const offset = buffer.length - idxs_len;

     buffer.set(this.selected_indexes, offset);
     const t_interval = setInterval(() => {
       this.wasm_instance.exports.translate(
         this.scene.ptr,
         this.scene.translate_fn_ptr,
         offset * 4,
         idxs_len,
         t_step.x,
         t_step.y,
         t_step.z
       );
     }, interval);
     setTimeout(() => clearInterval(t_interval), frames * interval);

     this.selected_indexes.forEach((idx) => {
       let { x, y, z } = this.vectors[idx];
       x += dx;
       y += dy;
       z += dz;
       this.vectors[idx] = { x, y, z };
     });
     this.updateVectorList();
   } else {
     alert("Please select elements translation");
   }
 }

 addVectorToList(x, y, z) {
   const list = document.getElementById("vector-list");
   const item = document.createElement("div");
   item.textContent = `${x}, ${y}, ${z}`;
   item.className = "vector-item";

   item.addEventListener("click", (event) => {
     if (event.ctrlKey) {
       item.classList.toggle("selected");
     } else {
       document.querySelectorAll(".vector-item").forEach((item) => {
         item.classList.remove("selected");
       });
       item.classList.add("selected");
     }

     this.updateSelectedIndexes();
   });

   list.appendChild(item);
 }

 updateSelectedIndexes() {
   this.selected_indexes = Array.from(
     document.querySelectorAll(".vector-item.selected")
   ).map((item) => Array.from(item.parentElement.children).indexOf(item));
 }

 updateVectorList() {
   const vectorList = document.getElementById("vector-list");
   vectorList.innerHTML = "";

   this.vectors.forEach((vector) => {
     this.addVectorToList(
       vector.x.toFixed(2),
       vector.y.toFixed(2),
       vector.z.toFixed(2)
     );
   });
 }

 toggleAutoRotation() {
   if (this.is_rotating) {
     clearInterval(this.rotation_interval);
     this.is_rotating = false;
     return;
   }

   const selectedVectors = document.querySelectorAll(".vector-item.selected");
   if (selectedVectors.length === 0) {
     this.is_rotating = true;
     let angle_z = 0;

     this.rotation_interval = setInterval(() => {
       const angle_x = wasm_instance.exports.getAngleX(
         scene.ptr,
         scene.get_ax_fn_ptr
       );
       angle_z += 0.03;
       angle_z %= Math.PI * 2;
       wasm_instance.exports.setAngles(
         scene.ptr,
         scene.angles_fn_ptr,
         angle_x,
         angle_z
       );
     }, interval);
   }
 }

 clearVectorList() {
   const list = document.getElementById("vector-list");
   list.innerHTML = "";
   this.updateSelectedIndexes();
 }
}

const env = {
 init: function () {
   const scene_handler = new SceneHandler(wasm_instance, scene);

   btn_listeners.splice(
     0,
     btn_listeners.length,
     ...createButtonListeners(scene_handler)
   );

   canvas = document.createElement("canvas");
   webgl = canvas.getContext("webgl");
   if (webgl == null) {
     throw new Error("No WebGL support on browser");
   }

   const body = document.body;
   const container = document.createElement("div");
   const text_fields = document.createElement("div");
   const inputs = ["input1", "input2", "input3"].map((id) => {
     const input = document.createElement("input");
     input.id = id;
     return input;
   });

   canvas.id = "canvas";
   container.id = "container";
   text_fields.id = "text-inputs";

   canvas.addEventListener("mousedown", down_listener);
   canvas.addEventListener("mouseup", up_listener);
   canvas.addEventListener("touchstart", down_listener);
   canvas.addEventListener("touchend", up_listener);
   canvas.addEventListener("touchmove", swipe_listener);
   canvas.addEventListener("mousemove", mouse_listener);
   canvas.addEventListener("wheel", wheel_listener);

   new ResizeObserver(resize_listener).observe(canvas);

   body.appendChild(container);
   container.append(
     canvas,
     text_fields,
     createButtonGrid(),
     createToggleGridButton(),
     createVectorList(),
     createToggleVectorListButton()
   );
   text_fields.append(...inputs);
 },

 deinit: function () {
   webgl.finish();
 },

 run: function (ptr, fnPtr) {
   function frame() {
     call(ptr, fnPtr);
     setTimeout(() => requestAnimationFrame(frame), 1000 / fps);
   }
   requestAnimationFrame(frame);
   throw new Error("Not an error");
 },
 setScene: function (ptr) {
   const state = new DataView(wasm_memory.buffer, ptr, 52);

   scene.ptr = state.getUint32(0, true);
   scene.angles_fn_ptr = state.getUint32(4, true);
   scene.get_ax_fn_ptr = state.getUint32(8, true);
   scene.zoom_fn_ptr = state.getUint32(12, true);
   scene.insert_fn_ptr = state.getUint32(16, true);
   scene.clear_fn_ptr = state.getUint32(20, true);
   scene.cube_fn_ptr = state.getUint32(24, true);
   scene.pyramid_fn_ptr = state.getUint32(28, true);
   scene.sphere_fn_ptr = state.getUint32(32, true);
   scene.cone_fn_ptr = state.getUint32(36, true);
   scene.rotate_fn_ptr = state.getUint32(40, true);
   scene.scale_fn_ptr = state.getUint32(44, true);
   scene.translate_fn_ptr = state.getUint32(48, true);
   console.log(scene); // printa ponteiros invalidos
 },
 setSceneCallBack: function (
   ptr,
   angles_fn_ptr,
   get_ax_fn_ptr,
   zoom_fn_ptr,
   insert_fn_ptr,
   clear_fn_ptr,
   cube_fn_ptr,
   pyramid_fn_ptr,
   sphere_fn_ptr,
   cone_fn_ptr,
   rotate_fn_ptr,
   scale_fn_ptr,
   translate_fn_ptr
 ) {
   Object.assign(scene, {
     ptr,
     angles_fn_ptr,
     get_ax_fn_ptr,
     zoom_fn_ptr,
     insert_fn_ptr,
     clear_fn_ptr,
     cube_fn_ptr,
     pyramid_fn_ptr,
     sphere_fn_ptr,
     cone_fn_ptr,
     rotate_fn_ptr,
     scale_fn_ptr,
     translate_fn_ptr,
   });
   console.log(scene);

 },
 _log(ptr, len) {
   console.log(getStr(ptr, len));
 },
 initShader(type, source_ptr, source_len) {
   const shaderType = type === 0 ? webgl.VERTEX_SHADER : webgl.FRAGMENT_SHADER;
   const shader = webgl.createShader(shaderType);
   if (!shader) throw new Error("Invalid shader type");

   webgl.shaderSource(
     shader,
     `precision mediump float;\n${getStr(source_ptr, source_len)}`
   );
   webgl.compileShader(shader);

   if (!webgl.getShaderParameter(shader, webgl.COMPILE_STATUS)) {
     throw new Error(
       `Failed to compile shader ${webgl.getShaderInfoLog(shader)}`
     );
   }

   const handle = next_shader++;
   shaders.set(handle, shader);
   return handle;
 },
 deinitShader(handle) {
   webgl.deleteShader(shaders.get(handle) ?? null);
   next_shader--;
 },
 initProgram(shader1_handle, shader2_handle) {
   const program = webgl.createProgram();
   if (!program) throw new Error("Failed to create program");

   const shader1 = shaders.get(shader1_handle);
   const shader2 = shaders.get(shader2_handle);
   if (!shader1 || !shader2) throw new Error("Failed to attach shaders");

   webgl.attachShader(program, shader1);
   webgl.attachShader(program, shader2);
   webgl.linkProgram(program);

   if (!webgl.getProgramParameter(program, webgl.LINK_STATUS)) {
     throw new Error(
       `Failed to link program: ${webgl.getProgramInfoLog(program)}`
     );
   }

   const attributes = new Map();
   const attributeCount = webgl.getProgramParameter(
     program,
     webgl.ACTIVE_ATTRIBUTES
   );
   for (let i = 0; i < attributeCount; i++) {
     const attribute = webgl.getActiveAttrib(program, i);
     if (attribute)
       attributes.set(attribute.name, { index: i, info: attribute });
   }

   const uniforms = new Map();
   const uniformCount = webgl.getProgramParameter(
     program,
     webgl.ACTIVE_UNIFORMS
   );
   for (let i = 0; i < uniformCount; i++) {
     const uniform = webgl.getActiveUniform(program, i);
     if (uniform) uniforms.set(uniform.name, uniform);
   }

   webgl.useProgram(program);
   webgl.uniform1f(
     webgl.getUniformLocation(program, "aspect_ratio"),
     canvas.width / canvas.height
   );
   webgl.uniform1f(webgl.getUniformLocation(program, "near"), 10);
   webgl.uniform1f(webgl.getUniformLocation(program, "far"), 45);

   const handle = next_program++;
   programs.set(handle, { gl: program, attributes, uniforms });
   return handle;
 },
 useProgram(handle) {
   const program = programs.get(handle);
   if (program) webgl.useProgram(program.gl);
 },
 deinitProgram(handle) {
   const program = programs.get(handle);
   if (program) {
     programs.delete(handle);
     webgl.deleteProgram(program.gl);
     next_program--;
   }
 },
 initVertexBuffer(data_ptr, data_len) {
   const vertex_buffer = webgl.createBuffer();
   if (!vertex_buffer) throw new Error("Failed to create buffer");

   webgl.bindBuffer(webgl.ARRAY_BUFFER, vertex_buffer);
   webgl.bufferData(
     webgl.ARRAY_BUFFER,
     getData(data_ptr, data_len),
     webgl.STATIC_DRAW
   );

   const handle = next_buffer++;
   buffers.set(handle, vertex_buffer);
   return handle;
 },
 deinitVertexBuffer(handle) {
   const buffer = buffers.get(handle) ?? null;
   buffers.delete(handle);
   webgl.deleteBuffer(buffer);
   next_buffer--;
 },
 bindVertexBuffer(handle) {
   const vertex_buffer = buffers.get(handle) ?? null;
   webgl.bindBuffer(webgl.ARRAY_BUFFER, vertex_buffer);
 },
 vertexAttribPointer(
   program_handle,
   name_ptr,
   name_len,
   size,
   type,
   normalized,
   stride,
   offset
 ) {
   const program = programs.get(program_handle);
   if (!program) return;

   const attribute = program.attributes.get(getStr(name_ptr, name_len));
   if (!attribute) return;

   const gl_type = type === 0 ? webgl.FLOAT : null;
   if (!gl_type) throw new Error("Unknown type");

   webgl.enableVertexAttribArray(attribute.index);
   webgl.vertexAttribPointer(
     attribute.index,
     size,
     gl_type,
     normalized,
     stride,
     offset
   );
 },
 drawArrays(mode, first, count) {
   const gl_mode = [
     webgl.POINTS,
     webgl.LINES,
     webgl.LINE_LOOP,
     webgl.LINE_STRIP,
     webgl.TRIANGLES,
     webgl.TRIANGLE_STRIP,
     webgl.TRIANGLE_FAN,
   ][mode];
   if (gl_mode === undefined) throw new Error("Unsupported draw mode");

   webgl.drawArrays(gl_mode, first, count);
 },
};

export async function init(wasm_path) {
 const response = await fetch(wasm_path);
 const result = await WebAssembly.instantiateStreaming(response, { env });
 wasm_instance = result.instance;
 wasm_memory = wasm_instance.exports.memory;
 wasm_instance.exports._start();
}

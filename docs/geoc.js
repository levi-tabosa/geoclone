/**
 * WebGL and WASM Definitions
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

/** Context and Globals **/
/** @type { HTMLCanvasElement[] } */
let canvases = [];
/** @type { WebGLRenderingContext[] } */
let webgls = [];
/** @type { WebAssembly.Instance[] } */
let wasm_instances = [];
/** @type { WebAssembly.Memory[] } */
let wasm_memories = [];
/** @type { ArrayBufferView<Uint8Array>[] } */
let memory_views = [];
/** @type { Map<number, WebGLShader>[] } */
const shaders = [new Map(), new Map(), new Map(), new Map()];
/** @type { Map<number, Program>[] } */
const programs = [new Map(), new Map(), new Map(), new Map()];
/** @type { Map<number, WebGLBuffer>[] } */
const buffers = [new Map(), new Map(), new Map(), new Map()];
let next_shader = [0, 0, 0, 0];
let next_program = [0, 0, 0, 0];
let next_buffer = [0, 0, 0, 0];
/** @type { SceneController[] } */
let scene_controllers = [];
/** @type { number[] } */
let state_ptrs = [];
/** @type { Map<String, number>[] } */
const fn_ptrs = [new Map(), new Map(), new Map(), new Map()];



/** @type {ArrayBufferView<Uint8Array>} */
let memory_view;

const INTERVAL = 30,
   FRAMES = 25,
   FPS = 100;

let state = {
   is_pressed: false,
   last_x: 0,
   last_y: 0,
   initial_pinch_distance: -1,
};

let scene_config = {
   fov: 1.4,
   near: 0.1,
   far: 100.0,
   aspect_ratio: 1.0,
};

const CONFIG = {
   ZOOM_SENSITIVITY: 0.1,
   PINCH_ZOOM_SENSITIVITY: 2000, //TODO: test with gh pages
};


/** @type { Array<{ fov: number, near: number, far: number, aspect_ratio: number }> } */
let scene_configs = [
   { fov: 1.4, near: 0.1, far: 100.0, aspect_ratio: 1.0 },
   { fov: 1.4, near: 0.1, far: 100.0, aspect_ratio: 1.0 },
   { fov: 1.4, near: 0.1, far: 100.0, aspect_ratio: 1.0 },
   { fov: 1.4, near: 0.1, far: 100.0, aspect_ratio: 1.0 },
];

/** @type { Array<{ is_pressed: boolean, last_x: number, last_y: number, initial_pinch_distance: number }> } */
let states = [
   { is_pressed: false, last_x: 0, last_y: 0, initial_pinch_distance: -1 },
   { is_pressed: false, last_x: 0, last_y: 0, initial_pinch_distance: -1 },
   { is_pressed: false, last_x: 0, last_y: 0, initial_pinch_distance: -1 },
   { is_pressed: false, last_x: 0, last_y: 0, initial_pinch_distance: -1 },
];

class SceneController {
   constructor(qid) {
      this.qid = qid;
      this.wasm_interface = new WasmInterface(qid);
      this.vectors = [];
      this.shapes = [];
      this.cameras = [];
      this.selected_vectors = [];
      this.selected_shapes = [];
      this.selected_cameras = [];
      this.is_rotating = false;
      this.rotation_interval = null;

      this.handleMouseMove = this.handleMouseMove.bind(this);
      this.handleTouch = this.handleTouch.bind(this);
      this.handleWheel = this.handleWheel.bind(this);
      this.handleMouseUp = this.handleMouseUp.bind(this);
      this.handleMouseDown = this.handleMouseDown.bind(this);
      this.handleTouchStart = this.handleTouchStart.bind(this);
      this.handleTouchEnd = this.handleTouchEnd.bind(this);

      this.setupEventListeners();
   }

   setupEventListeners() {
      const canvas = canvases[this.qid];
      if(!canvas) throw new Error(`Canvas for quadrant ${this.qid} not found`);
      canvas.addEventListener("mouseup", this.handleMouseUp, { passive: true });
      canvas.addEventListener("mousedown", this.handleMouseDown, { passive: true });
      canvas.addEventListener("mousemove", this.handleMouseMove, { passive: true });
      canvas.addEventListener("touchstart", this.handleTouchStart, { passive: true });
      canvas.addEventListener("touchend", this.handleTouchEnd, { passive: true });
      canvas.addEventListener("touchmove", this.handleTouch, { passive: true });
      canvas.addEventListener("wheel", this.handleWheel, { passive: true });
   }

   handleMouseUp(_e) {
      states[this.qid].is_pressed = false;
   }

   handleMouseDown(_e) {
      states[this.qid].is_pressed = true;
   }

   handleMouseMove(e) {
      if (!states[this.qid].is_pressed) return;

      const { left, top, width, height } = canvases[this.qid].getBoundingClientRect();
      this.wasm_interface.setAngles(
         ((e.clientY - top) * Math.PI * 2) / height,
         ((e.clientX - left) * Math.PI * 2) / width
      );
   }

   handleTouchStart(e) {
      if (e.touches.length === 2) {
         states[this.qid].initial_pinch_distance = Math.hypot(
            e.touches[0].clientX - e.touches[1].clientX,
            e.touches[0].clientY - e.touches[1].clientY
         );
      } else if (e.touches.length === 1) {
         states[this.qid].is_pressed = true;
      }
   }

   handleTouchEnd(e) {
      states[this.qid].is_pressed = false;
      states[this.qid].initial_pinch_distance = -1;
      e.preventDefault();
   }

   handleTouch(e) {
      if (e.touches.length === 2) {
         const current_distance = Math.hypot(
            e.touches.item(0).clientX - e.touches.item(1).clientX,
            e.touches.item(0).clientY - e.touches.item(1).clientY
         );

         if (states[this.qid].initial_pinch_distance < 0) {
            const pinch_delta =
               (current_distance - states[this.qid].initial_pinch_distance) /
               CONFIG.PINCH_ZOOM_SENSITIVITY;
            this.updateZoom(-pinch_delta);
            states[this.qid].initial_pinch_distance = current_distance;
         }
      } else if (e.touches.length === 1 && states[this.qid].is_pressed) {
         const { left, top, width, height } = canvases[this.qid].getBoundingClientRect();
         this.wasm_interface.setAngles(
            ((e.touches.item(0).clientY - top) * Math.PI * 2) / height,
            ((e.touches.item(0).clientX - left) * Math.PI * 2) / width
         );
      }
      e.preventDefault();
   }

   handleWheel(e) {
      const zoom_delta = -e.deltaY / CONFIG.ZOOM_SENSITIVITY;
      this.wasm_interface.setZoom(zoom_delta);
   }

   updateZoom(delta) {
      this.wasm_interface.setZoom(delta);
   }

   insertVector(x, y, z) {
      const [xf, yf, zf] = [
         parseFloat(x) || 0,
         parseFloat(y) || 0,
         parseFloat(z) || 0,
      ];
      if (xf === 0 && yf === 0 && zf === 0) {
         for (let i = 0; i < 5; i++) {
            const randomX = Math.random() * 20 - 10;
            const randomY = Math.random() * 20 - 10;
            const randomZ = Math.random() * 20 - 10;
            this.wasm_interface.insertVector(randomX, randomY, randomZ);
            this.vectors.push({ x: randomX, y: randomY, z: randomZ });
         }
         this.updateUI();
      } else {
         this.wasm_interface.insertVector(xf, yf, zf);
         this.vectors.push({ x: xf, y: yf, z: zf });
         this.updateUI();
      }

      if ([x, y, z].some((isNaN))) {
         console.log("Invalid input", wasm_memory.grow(0));
      }
   }

   insertCamera(x, y, z) {
      this.wasm_interface.insertCamera(
         parseFloat(x) || 0,
         parseFloat(y) || 0,
         parseFloat(z) || 0
      );
      this.cameras.push(`Camera@${this.cameras.length}`);
      this.updateUI();
   }

   insertShape(/** @type { String } */ shape) {
      this.wasm_interface.insertShape(shape);
      this.shapes.push(shape);
      this.updateUI();
   }

   clear() {
      this.clearTable();
      this.wasm_interface.clear();
      this.vectors = [];
      this.shapes = [];
      this.cameras = [];
      this.updateSelectedIndexes();
   }

   setResolution(/** @type { number } */ resolution) {
      this.wasm_interface.setResolution(resolution);
   }

   scale(factor) {
      if (isNaN(parseFloat(factor))) return;
      const combined = this.concatAndGetSelected();
      const len = combined.length;

      const shorts =
         (this.selected_vectors.length << 16) + this.selected_shapes.length;

      if (len === 0) return;

      const buffer = new Uint32Array(wasm_memories[this.qid].buffer);
      const offset = buffer.length - len;
      buffer.set(combined, offset);

      this.wasm_interface.scale(offset * 4, len, shorts, factor);

      this.selected_vectors.forEach((idx) => {
         let { x, y, z } = this.vectors[idx];
         x *= factor;
         y *= factor;
         z *= factor;
         this.vectors[idx] = { x, y, z };
      });

      this.updateUI();
   }

   rotate(
   /** @type {String} */ angle_x,
   /** @type {String} */ angle_y,
   /** @type {String} */ angle_z
   ) {
      const combined = this.concatAndGetSelected();
      const len = combined.length;

      if (
         len === 0 ||
         [angle_x, angle_y, angle_z].some(isNaN) ||
         (angle_x.length | angle_y.length | angle_z.length) == 0
      ) {
         this.toggleAutoRotation();
         return;
      }

      const shorts =
         (this.selected_vectors.length << 16) + this.selected_shapes.length;

      const buffer = new Uint32Array(wasm_memories[this.qid].buffer);
      const offset = buffer.length - len;
      buffer.set(combined, offset);

      this.wasm_interface.rotate(offset * 4, len, shorts, angle_x, angle_y, angle_z);

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

      this.selected_vectors.forEach((idx) => {
         let { x, y, z } = this.vectors[idx];

         ({ x, y, z } = rotateVector(x, y, z, angle_z, "z"));
         ({ x, y, z } = rotateVector(x, y, z, angle_y, "y"));
         ({ x, y, z } = rotateVector(x, y, z, angle_x, "x"));

         this.vectors[idx] = { x, y, z };
      });

      this.updateUI();
   }

   translate(dx, dy, dz) {
      const combined = this.concatAndGetSelected();
      const len = combined.length;
      if (len === 0 || [dx, dy, dz].some(isNaN)) return;

      const shorts =
         (this.selected_vectors.length << 16) + this.selected_shapes.length;

      const buffer = new Uint32Array(wasm_memories[this.qid].buffer);
      const offset = buffer.length - len;
      buffer.set(combined, offset);

      this.wasm_interface.translate(offset * 4, len, shorts, dx, dy, dz);

      this.selected_vectors.forEach((idx) => {
         let { x, y, z } = this.vectors[idx];
         x += parseFloat(dx) || 0;
         y += parseFloat(dy) || 0;
         z += parseFloat(dz) || 0;

         this.vectors[idx] = { x, y, z };
      });
      this.updateUI();
   }

   reflect(flags) {
      const combined = this.concatAndGetSelected();
      const len = combined.length;
      if (len === 0) return;

      const shorts =
         (this.selected_vectors.length << 16) + this.selected_shapes.length;

      const buffer = new Uint32Array(wasm_memories[this.qid].buffer);
      const offset = buffer.length - len;
      buffer.set(combined, offset);


      this.wasm_interface.reflect(offset * 4, len, shorts, flags);
      this.selected_vectors.forEach((idx) => {
         let { x, y, z } = this.vectors[idx];

         if (flags & 1) x = -x;
         if (flags & 2) y = -y;
         if (flags & 4) z = -z;

         this.vectors[idx] = { x, y, z };
      });

      this.updateUI();
   }

   updateUI() {
      const vectors_column = document.getElementById(`vectors-column-${this.qid}`) || document.getElementById("vectors-column");
      const shapes_column = document.getElementById(`shapes-column-${this.qid}`) || document.getElementById("shapes-column");
      const cameras_column = document.getElementById(`cameras-column-${this.qid}`) || document.getElementById("cameras-column");

      vectors_column.innerHTML = "";
      shapes_column.innerHTML = "";
      cameras_column.innerHTML = "";

      this.vectors.forEach((vector) => {
         this.addColumnItem(
            vectors_column,
            "vector-item",
            `${vector.x.toFixed(2)}, ${vector.y.toFixed(2)}, ${vector.z.toFixed(2)}`
         );
      });

      this.shapes.forEach((shape) => {
         this.addColumnItem(shapes_column, "shape-item", shape);
      });

      this.cameras.forEach((camera) => {
         this.addColumnItem(cameras_column, "camera-item", camera);
      });
   }

   addColumnItem(
      /** @type {HTMLElement} */ column,
      /** @type {String} */ item_class_name,
      /** @type {String} */ text
   ) {
      const item = document.createElement("div");
      item.textContent = text;
      item.className = item_class_name;
      item.addEventListener("click", (e) => {
         if (e.ctrlKey) {
            item.classList.toggle("selected");
         } else {
            column
               .querySelectorAll(item_class_name)
               .forEach((item) => item.classList.remove("selected"));
            item.classList.add("selected");
         }

         this.updateSelectedIndexes();
      });
      column.appendChild(item);
   }

   updateSelectedIndexes() {
      const vector_items = document.querySelectorAll(".vector-item.selected");
      const shape_items = document.querySelectorAll(".shape-item.selected");
      const camera_items = document.querySelectorAll(".camera-item.selected");

      this.selected_vectors = Array.from(vector_items).map((vector) =>
         Array.from(vector.parentElement.children).indexOf(vector)
      );
      this.selected_shapes = Array.from(shape_items).map((shape) =>
         Array.from(shape.parentElement.children).indexOf(shape)
      );
      this.selected_cameras = Array.from(camera_items).map((camera) =>
         Array.from(camera.parentElement.children).indexOf(camera)
      );

      const last_selected_camera =
         this.selected_cameras.length > 0
            ? this.selected_cameras[this.selected_cameras.length - 1]
            : -1;
      this.wasm_interface.setCamera(last_selected_camera);
   }

   toggleAutoRotation() {
      if (this.is_rotating) {
         clearInterval(this.rotation_interval);
         this.is_rotating = false;
      } else if (
         document.querySelectorAll(".vector-item.selected").length === 0
      ) {
         this.is_rotating = true;
         let y_angle = 0;

         this.rotation_interval = setInterval(() => {
            const p_angle = this.wasm_interface.getPitch();
            y_angle = (y_angle + 0.03) % (Math.PI * 2);
            this.wasm_interface.setAngles(p_angle, y_angle);
         }, INTERVAL);
      }
   }

   clearTable() {
      const vectors_column = document.getElementById("vectors-column");
      const shapes_column = document.getElementById("shapes-column");
      const cameras_column = document.getElementById("cameras-column");

      vectors_column.innerHTML = "";
      shapes_column.innerHTML = "";
      cameras_column.innerHTML = "";
   }

   concatAndGetSelected() {
      return [
         ...this.selected_vectors,
         ...this.selected_shapes,
         ...this.selected_cameras,
      ];
   }
}
class WasmInterface {
   constructor(qid) {
      this.qid = qid;
      if (!wasm_instances[qid]) {
         throw new Error(`WASM instance for quadrant ${qid} is not initialized`);
      }
      this.wasm_exports = wasm_instances[qid].exports;
   }

   setAngles(p_angle, y_angle) {
      this.wasm_exports.setAngles(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("set_angles_fn_ptr"),
         p_angle,
         y_angle
      );
   }

   setZoom(zoom_delta) {
      this.wasm_exports.setZoom(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("set_zoom_fn_ptr"),
         zoom_delta
      );
   }

   getPitch() {
      return this.wasm_exports.getPitch(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("get_pitch_fn_ptr")
      );
   }

   insertVector(x, y, z) {
      this.wasm_exports.insertVector(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("insert_vector_fn_ptr"),
         x,
         y,
         z
      );
   }

   insertCamera(x, y, z) {
      this.wasm_exports.insertCamera(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("insert_camera_fn_ptr"),
         x,
         y,
         z
      );
   }

   insertShape(shape) {
      const shape_fn_ptr = fn_ptrs[this.qid].get(`${shape.toLowerCase()}_fn_ptr`);
      this.wasm_exports[`insert${shape}`](state_ptrs[this.qid], shape_fn_ptr);
   }

   clear() {
      this.wasm_exports.clear(state_ptrs[this.qid], fn_ptrs[this.qid].get("clear_fn_ptr"));
   }

   setResolution(resolution) {
      this.wasm_exports.setResolution(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("set_res_fn_ptr"),
         resolution
      );
   }

   setCamera(index) {
      this.wasm_exports.setCamera(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("set_camera_fn_ptr"),
         index
      );
   }

   rotate(indexes_ptr, indexes_len, shorts, x, y, z) {
      this.wasm_exports.rotate(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("rotate_fn_ptr"),
         indexes_ptr,
         indexes_len,
         shorts,
         x,
         y,
         z
      );
   }

   scale(indexes_ptr, indexes_len, shorts, factor) {
      this.wasm_exports.scale(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("scale_fn_ptr"),
         indexes_ptr,
         indexes_len,
         shorts,
         factor
      );
   }

   translate(indexes_ptr, indexes_len, shorts, dx, dy, dz) {
      this.wasm_exports.translate(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("translate_fn_ptr"),
         indexes_ptr,
         indexes_len,
         shorts,
         dx,
         dy,
         dz
      );
   }

   reflect(indexes_ptr, indexes_len, shorts, coord_idx, factor) {
      this.wasm_exports.reflect(
         state_ptrs[this.qid],
         fn_ptrs[this.qid].get("reflect_fn_ptr"),
         indexes_ptr,
         indexes_len,
         shorts,
         coord_idx,
         factor
      );
   }
}

const resize_listener = (entries, qid) => {
   const { width, height } = entries[0].contentRect;
   canvases[qid].width = width;
   canvases[qid].height = height;

   webgls[qid].viewport(0, 0, width, height);
   webgls[qid].clear(webgls[qid].COLOR_BUFFER_BIT);
   setAspectRatioUniform(width / height, qid);
   scene_configs[qid].aspect_ratio = width / height;
};

const env = {
   init() {
   },
   deinit(qid) {
      webgls[qid].finish();
   },
   run(ptr, fnPtr, qid) {
      console.log("Running animation loop for quadrant", qid);
      function frame() {
         try {
            call(ptr, fnPtr, qid);
            requestAnimationFrame(frame);
         } catch (e) {
            console.error(`Error in quadrant ${qid} animation loop:`, e);
         }
      }
      requestAnimationFrame(frame);
   },
   setStatePtr(ptr, qid) {
      state_ptrs[qid] = ptr;
   },
   setFnPtr(fn_name_ptr, fn_ptrs_len, value, qid) {
      fn_ptrs[qid].set(getStr(fn_name_ptr, fn_ptrs_len, qid), value);
   },
   time() {
      return performance.now();
   },
   print(ptr, len, qid) {
      console.log(getStr(ptr, len, qid));
   },
   initShader(type, source_ptr, source_len, qid) {
      console.log(`initShader: qid=${qid}, type=${type}, shader created with webgls[${qid}]`);
      const shaderType = type === 0 ? webgls[qid].VERTEX_SHADER : webgls[qid].FRAGMENT_SHADER;
      const shader = webgls[qid].createShader(shaderType);
      if (!shader) throw new Error("Shader is not");

      webgls[qid].shaderSource(
         shader,
         `precision mediump float;\n${getStr(source_ptr, source_len, qid)}`
      );
      webgls[qid].compileShader(shader);

      if (!webgls[qid].getShaderParameter(shader, webgls[qid].COMPILE_STATUS)) {
         throw new Error(
            `Failed to compile shader ${webgls[qid].getShaderInfoLog(shader)}`
         );
      }


      const handle = next_shader[qid]++;
      shaders[qid].set(handle, shader);
      return handle;
   },
   deinitShader(handle, qid) {
      webgls[qid].deleteShader(shaders[qid].get(handle) ?? null);
   },
   initProgram(shader1_handle, shader2_handle, qid) {
      console.log(`initProgram: qid=${qid}`);
      const program = webgls[qid].createProgram();
      if (!program) throw new Error(`Failed to create program for qid=${qid}`);
      const shader1 = shaders[qid].get(shader1_handle);
      const shader2 = shaders[qid].get(shader2_handle);
      if (!shader1 || !shader2) throw new Error(`Invalid shaders for qid=${qid}`);
      webgls[qid].attachShader(program, shader1);
      webgls[qid].attachShader(program, shader2);
      webgls[qid].linkProgram(program);
      if (!webgls[qid].getProgramParameter(program, webgls[qid].LINK_STATUS)) {
         throw new Error(`Program link failed for qid=${qid}: ${webgls[qid].getProgramInfoLog(program)}`);
      }

      if (!webgls[qid].getProgramParameter(program, webgls[qid].LINK_STATUS)) {
         throw new Error(
            `Failed to link program: ${webgls[qid].getProgramInfoLog(program)}`
         );
      }

      const attribute_count = webgls[qid].getProgramParameter(
         program,
         webgls[qid].ACTIVE_ATTRIBUTES
      );
      const attributes = new Map();

      for (let i = 0; i < attribute_count; i++) {
         const attribute = webgls[qid].getActiveAttrib(program, i);
         if (attribute) {
            attributes.set(attribute.name, { index: i, info: attribute });
         }
      }

      const uniform_count = webgls[qid].getProgramParameter(
         program,
         webgls[qid].ACTIVE_UNIFORMS
      );
      const uniforms = new Map();

      for (let i = 0; i < uniform_count; i++) {
         const uniform = webgls[qid].getActiveUniform(program, i);
         if (uniform) {
            uniforms.set(uniform.name, uniform);
         }
      }

      webgls[qid].useProgram(program);

      const fov = 1.4;
      const aspect_ratio = canvases[qid].width / canvases[qid].height;
      const near = 0.1;
      const far = 100.0;

      webgls[qid].uniformMatrix4fv(
         webgls[qid].getUniformLocation(program, "projection_matrix"),
         false,
         createProjectionMatrix(fov, aspect_ratio, near, far)
      );

      const handle = next_program[qid]++;
      console.log(`initProgram: qid=${qid}, storing program with handle=${handle}`);
      programs[qid].set(handle, { gl: program, attributes, uniforms });

      return handle;
   },
   useProgram(handle, qid) {
      const program = programs[qid].get(handle);
      if (program) {
         if (!webgls[qid].isProgram(program.gl)) {
            throw new Error(`Program for qid=${qid}, handle=${handle} is invalid or from another context`);
         }
         webgls[qid].useProgram(program.gl);
      } else {
         console.error(`No program found for qid=${qid}, handle=${handle}`);
      }
   },
   deinitProgram(handle, qid) {
      const program = programs[qid].get(handle);
      if (program) {
         programs[qid].delete(handle);
         webgls[qid].deleteProgram(program.gl);
      }
   },
   initVertexBuffer(data_ptr, data_len, usage, qid) {
      const gl_usage = [
         webgls[qid].STATIC_DRAW,
         webgls[qid].DYNAMIC_DRAW,
         webgls[qid].STREAM_DRAW,
      ][usage];
      const vertex_buffer = webgls[qid].createBuffer();

      webgls[qid].bindBuffer(webgls[qid].ARRAY_BUFFER, vertex_buffer);
      webgls[qid].bufferData(
         webgls[qid].ARRAY_BUFFER,
         getData(data_ptr, data_len, qid),
         gl_usage
      );

      const handle = next_buffer[qid]++;
      buffers[qid].set(handle, vertex_buffer);
      return handle;
   },
   deinitVertexBuffer(handle, qid) {
      const buffer = buffers[qid].get(handle);
      if (buffers[qid].delete(handle)) {
         webgls[qid].deleteBuffer(buffer);
      } else {
         console.error("Failed to delete buffer\nhandle : " + handle);
      }
   },
   bindVertexBuffer(handle, qid) {
      const vertex_buffer = buffers[qid].get(handle);
      if (vertex_buffer) {
         if (!webgls[qid].isBuffer(vertex_buffer)) {
            console.error(`Buffer for qid=${qid}, handle=${handle} is invalid or from another context`);
            return;
         }
         webgls[qid].bindBuffer(webgls[qid].ARRAY_BUFFER, vertex_buffer);
      } else {
         console.error(`Failed to bind handle: ${handle} for qid=${qid}`);
      }
   },
   bufferSubData(handle, idxs_ptr, idxs_len, data_ptr, data_len, qid) {
      const vertex_buffer = buffers[qid].get(handle);

      const data = new Float32Array(wasm_memories[qid].buffer, data_ptr, data_len / 4);
      const idxs = new Uint32Array(wasm_memories[qid].buffer, idxs_ptr, idxs_len);

      webgls[qid].bindBuffer(webgls[qid].ARRAY_BUFFER, vertex_buffer);

      for (let i = 0; i < idxs_len; i++) {
         const idx = idxs[i];
         const offset = idx * 6 * 4;
         const vertexData = data.subarray(i * 6, (i + 1) * 6);
         webgls[qid].bufferSubData(webgls[qid].ARRAY_BUFFER, offset, vertexData);
      }
   },
   bufferData(handle, data_ptr, data_len, usage, qid) {
      const gl_usage = [
         webgls[qid].STATIC_DRAW,
         webgls[qid].DYNAMIC_DRAW,
         webgls[qid].STREAM_DRAW,
      ][usage];
      const vertex_buffer = buffers[qid].get(handle);
      webgls[qid].bindBuffer(webgls[qid].ARRAY_BUFFER, vertex_buffer);
      webgls[qid].bufferData(
         webgls[qid].ARRAY_BUFFER,
         getData(data_ptr, data_len, qid),
         gl_usage
      );
   },
   setInterval(fn_ptr, args_ptr, args_len, delay, timeout, qid) {
      const handle = setInterval(() => {
         wasm_instances[qid].exports.apply(state_ptrs[qid], fn_ptr, args_ptr, args_len);
      }, delay);

      if (timeout > 0) {
         setTimeout(() => {
            clearInterval(handle);
            wasm_instances[qid].exports.free(
               state_ptrs[qid],
               fn_ptrs[qid].get("free_args_fn_ptr"),
               args_ptr,
               args_len
            );
         }, timeout);
      }

      return handle;
   },
   clearInterval(handle) {
      clearInterval(handle);
   },
   vertexAttribPointer(
      program_handle,
      name_ptr,
      name_len,
      size,
      type,
      normalized,
      stride,
      offset,
      qid
   ) {
      const program = programs[qid].get(program_handle);
      if (!program) return;

      const attribute = program.attributes.get(getStr(name_ptr, name_len, qid));
      if (!attribute) return;

      const gl_type = type === 0 ? webgls[qid].FLOAT : null;
      if (!gl_type) throw new Error("Unknown type");

      webgls[qid].enableVertexAttribArray(attribute.index);
      webgls[qid].vertexAttribPointer(
         attribute.index,
         size,
         gl_type,
         normalized,
         stride,
         offset
      );
   },
   drawArrays(mode, first, count, qid) {
      const gl_mode = [
         webgls[qid].POINTS,
         webgls[qid].LINES,
         webgls[qid].LINE_LOOP,
         webgls[qid].LINE_STRIP,
         webgls[qid].TRIANGLES,
         webgls[qid].TRIANGLE_STRIP,
         webgls[qid].TRIANGLE_FAN,
      ][mode];
      if (gl_mode === undefined) throw new Error("Unsupported draw mode");
      webgls[qid].drawArrays(gl_mode, first, count);
   },
   uniformMatrix4fv(location_ptr, location_len, transpose, value_ptr, qid) {
      const location = getStr(location_ptr, location_len, qid);
      const value = new Float32Array(wasm_memories[qid].buffer, value_ptr, 16);
      for (let i = 0; i < next_program[qid]; i++) {
         const program = programs[qid].get(i);
         webgls[qid].useProgram(program.gl);
         webgls[qid].uniformMatrix4fv(
            webgls[qid].getUniformLocation(program.gl, location),
            transpose,
            value
         );
      }
   },
};

function createToggleButtonGrid() {
   return createButton("toggle-grid-btn", "Btns", () => {
      document.getElementById("button-grid").classList.toggle("hidden");
   });
}

function updateMemoryView(qid) {
   memory_views[qid] = new Uint8Array(wasm_memories[qid].buffer);
}

function createButton(id, text, on_click) {
   const btn = document.createElement("button");
   btn.id = id;
   btn.textContent = text;
   btn.addEventListener("click", on_click);
   return btn;
}

function createColorButtonGrid() {
   const container = document.createElement("div");
   container.id = "color-button-container";

   const grid = document.createElement("div");
   grid.id = "color-button-grid";
   container.appendChild(grid);

   const toggle = document.createElement("button");
   toggle.id = "toggle-color-grid-btn";
   toggle.textContent = "▼";
   container.appendChild(toggle);

   const colors = [
      "#d6d6d6",
      "#1e1e1e",
      "#b0c4de",
      "#0a1128",
      "#2b2b2b",
      "#143d2e",
      "#2c1f3c",
      "linear-gradient(to right, #1e3a8a, #6b21a8)",
      "linear-gradient(to right, #000000, #434343)",
      "linear-gradient(to right, #00c6ff, #0072ff)",
   ];

   colors.forEach((color, index) => {
      const btn = document.createElement("button");
      btn.className = "color-button";
      btn.style.background = color;
      btn.onclick = () => {
         canvas.style.background = color;
      };

      if (index > 1) {
         btn.style.display = "none";
      }

      grid.appendChild(btn);
   });

   toggle.addEventListener("click", () => {
      const is_expanded = grid.style.maxHeight !== "30px";

      if (is_expanded) {
         grid.style.maxHeight = "30px";
         Array.from(grid.children).forEach((btn, index) => {
            if (index > 1) btn.style.display = "none";
         });
         toggle.classList.remove("expanded");
      } else {
         grid.style.maxHeight = "300px";
         Array.from(grid.children).forEach((btn) => {
            btn.style.display = "block";
         });
         toggle.classList.add("expanded");
      }
   });

   return container;
}
function createQuadrantCanvases() {
   const container = document.createElement("div");
   container.id = "quadrant-container";
   container.style.display = "grid";
   container.style.gridTemplateColumns = "50% 50%";
   container.style.gridTemplateRows = "50% 50%";
   container.style.width = "100vw";
   container.style.height = "100vh";
   container.style.position = "fixed";
   container.style.top = "0";
   container.style.left = "0";
   container.style.margin = "0";
   container.style.padding = "0";

   const canvases = [];
   for (let i = 0; i < 4; i++) {
      const canvas = document.createElement("canvas");
      canvas.id = `canvas-${i}`;
      canvas.style.width = "100%";
      canvas.style.height = "100%";
      container.appendChild(canvas);
      canvases.push(canvas);
   }

   document.body.appendChild(container);
   console.log("Created canvases:", canvases);
   return canvases;
}

function getStr(c_ptr, len, qid) {
   return new TextDecoder().decode(getData(c_ptr, len, qid));
}

function call(ptr, fnPtr, qid) {
   wasm_instances[qid].exports.draw(ptr, fnPtr);
}

function getData(ptr, len, qid) {
   updateMemoryView(qid); // Ensure memory view is current
   return new Uint8Array(wasm_memories[qid].buffer, ptr, len);
}

function setAspectRatioUniform(aspect_ratio, qid) {
   for (let i = 0; i < next_program[qid]; i++) {
      const program = programs[qid].get(i);
      webgls[qid].useProgram(program.gl);
      webgls[qid].uniformMatrix4fv(
         webgls[qid].getUniformLocation(program.gl, "projection_matrix"),
         false,
         createProjectionMatrix(
            scene_configs[qid].fov,
            aspect_ratio,
            scene_configs[qid].near,
            scene_configs[qid].far
         )
      );
   }
}

function setPerspectiveUniforms(fov, near, far, qid) {
   for (let i = 0; i < next_program[qid]; i++) {
      const program = programs[qid].get(i);
      webgls[qid].useProgram(program.gl);
      webgls[qid].uniformMatrix4fv(
         webgls[qid].getUniformLocation(program.gl, "projection_matrix"),
         false,
         createProjectionMatrix(fov, scene_configs[qid].aspect_ratio, near, far)
      );
   }
}

function createProjectionMatrix(fov, aspect_ratio, near, far) {
   const tan_half_FOV = Math.tan(fov / 2.0);
   const projection = new Float32Array(16);
   projection[0] = 1.0 / (tan_half_FOV * aspect_ratio);
   projection[5] = 1.0 / tan_half_FOV;
   projection[10] = -(far + near) / (far - near);
   projection[11] = -1.0;
   projection[14] = -(2.0 * far * near) / (far - near);
   return projection;
}

function createQuadrantUI(qid, scene_handler) {
   const container = document.createElement("div");
   container.id = `ui-container-${qid}`;
   container.style.position = "absolute";
   container.style.top = qid < 2 ? "10px" : "calc(50% + 10px)";
   container.style.left = qid % 2 === 0 ? "10px" : "calc(50% + 10px)";
   container.style.background = "rgba(0, 0, 0, 0.5)";
   container.style.padding = "10px";
   container.style.color = "white";

   const text_fields = document.createElement("div");
   text_fields.id = `text-inputs-${qid}`;
   const inputs = [`input1-${qid}`, `input2-${qid}`, `input3-${qid}`].map((id) => {
      const input = document.createElement("input");
      input.id = id;
      input.placeholder = id.split('-')[0];
      input.type = "text";
      return input;
   });
   text_fields.append(...inputs);
   container.appendChild(text_fields);

   document.body.appendChild(container);
   console.log(`Appended container for quadrant ${qid}, inputs:`, text_fields.querySelectorAll("input"));

   const buttonGrid = createButtonGrid(qid, scene_handler);
   container.appendChild(buttonGrid);

   const table = createFloatingTable(qid);
   container.appendChild(table);

   const toggleTableBtn = createToggleTableButton(qid);
   container.appendChild(toggleTableBtn);

   const perspectiveInputs = createPerspectiveInputs(scene_handler, qid);
   container.appendChild(perspectiveInputs);

   return container;
}
function createButtonGrid(qid, scene_handler) {
   const grid = document.createElement("div");
   grid.id = `button-grid-${qid}`;
   grid.className = "button-grid";

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
      "Reflect",
      "Project-XY",
      "Cone",
      "Text",
      "Project-YZ",
      "Camera",
      "Text",
      "Project-XZ",
   ];

   const listeners = createButtonListeners(scene_handler, qid);
   labels.forEach((label, index) => {
      const btn = createButton(`grid-btn-${qid}-${index + 1}`, label, listeners[index]);
      btn.className = "floating-button";
      grid.appendChild(btn);
   });
   return grid;
}

function createButtonListeners(scene_handler, qid) {
   const inputs = [
      document.getElementById(`input1-${qid}`),
      document.getElementById(`input2-${qid}`),
      document.getElementById(`input3-${qid}`),
   ];
   console.log(`Looking for inputs in quadrant ${qid}:`, inputs);
   if (inputs.some(input => !input)) {
      console.error(`Input elements missing for quadrant ${qid}:`, inputs);
      console.log(`DOM state for quadrant ${qid}:`, document.getElementById(`text-inputs-${qid}`)?.innerHTML);
      return Array(18).fill(() => console.warn(`UI for quadrant ${qid} not ready`));
   }
   return [
      () => {
         scene_handler.insertVector(
            inputs[0].value || "0",
            inputs[1].value || "0",
            inputs[2].value || "0"
         );
         inputs.forEach((input) => (input.value = ""));
      },
      () => scene_handler.clear(),
      () => {
         scene_handler.rotate(
            inputs[0].value || "0",
            inputs[1].value || "0",
            inputs[2].value || "0"
         );
         inputs.forEach((input) => (input.value = ""));
      },
      () => scene_handler.insertShape("Cube"),
      () => console.log(`Toggle quadrant ${qid}`),
      () => {
         scene_handler.scale(inputs[0].value || "1");
         inputs[0].value = "";
      },
      () => scene_handler.insertShape("Pyramid"),
      () => { },
      () => {
         scene_handler.translate(
            inputs[0].value || "0",
            inputs[1].value || "0",
            inputs[2].value || "0"
         );
         inputs.forEach((input) => (input.value = ""));
      },
      () => scene_handler.insertShape("Sphere"),
      () => scene_handler.reflect(
         0 |
         (inputs[0].value ? 1 : 0) |
         (inputs[1].value ? 2 : 0) |
         (inputs[2].value ? 4 : 0)
      ),
      () => scene_handler.projectXY?.(),
      () => scene_handler.insertShape("Cone"),
      () => { },
      () => scene_handler.projectYZ?.(),
      () => {
         scene_handler.insertCamera(
            inputs[0].value || "0",
            inputs[1].value || "0",
            inputs[2].value || "0"
         );
         inputs.forEach((input) => (input.value = ""));
      },
      () => { },
      () => scene_handler.projectXZ?.(),
   ];
}
function createFloatingTable(qid) {
   const table = document.createElement("div");
   table.id = `floating-table-${qid}`;
   table.className = "floating-table";

   const header = document.createElement("div");
   header.className = "table-header";
   ["Vectors", "Shapes", "Cameras"].forEach((title) => {
      const column = document.createElement("div");
      column.className = "header-column";
      column.textContent = title;
      header.appendChild(column);
   });

   const content = document.createElement("div");
   content.className = "table-content";

   const vectorsColumn = document.createElement("div");
   vectorsColumn.id = `vectors-column-${qid}`;
   vectorsColumn.className = "table-column";

   const shapesColumn = document.createElement("div");
   shapesColumn.id = `shapes-column-${qid}`;
   shapesColumn.className = "table-column";

   const camerasColumn = document.createElement("div");
   camerasColumn.id = `cameras-column-${qid}`;
   camerasColumn.className = "table-column";

   content.appendChild(vectorsColumn);
   content.appendChild(shapesColumn);
   content.appendChild(camerasColumn);

   table.appendChild(header);
   table.appendChild(content);
   return table;
}

function createToggleTableButton(qid) {
   const btn = createButton(`toggle-table-btn-${qid}`, "▼", () => {
      btn.classList.toggle("expanded");
      document.getElementById(`floating-table-${qid}`).classList.toggle("hidden");
   });
   return btn;
}

function createPerspectiveInputs(scene_handler, qid) {
   const container = document.createElement("div");
   container.id = `perspective-inputs-${qid}`;

   const input1 = document.createElement("input");
   input1.id = `near-input-${qid}`;
   input1.placeholder = "Near";

   const input2 = document.createElement("input");
   input2.id = `far-input-${qid}`;
   input2.placeholder = "Far";

   const input3 = document.createElement("input");
   input3.id = `grid-input-${qid}`;
   input3.placeholder = "Grid resolution";

   const input4 = document.createElement("input");
   input4.id = `fov-input-${qid}`;
   input4.placeholder = "FOV";

   const button = createButton(`perspective-input-button-${qid}`, "Set", () => {
      const near = parseFloat(input1.value) || scene_configs[qid].near;
      const far = parseFloat(input2.value) || scene_configs[qid].far;
      const fov = (parseFloat(input4.value) * Math.PI) / 180 || scene_configs[qid].fov;
      const resolution = parseFloat(input3.value);

      setPerspectiveUniforms(fov, near, far, qid);

      if (!isNaN(resolution)) {
         scene_handler.setResolution(resolution);
      }

      scene_configs[qid].near = near;
      scene_configs[qid].far = far;
      scene_configs[qid].fov = fov;

      input1.value = input2.value = input3.value = input4.value = "";
   });

   container.append(input1, input2, input3, input4, button);
   return container;
}

export async function init(wasm_path) {
   console.log("Fetching WASM module...");
   const bytes = await fetch(wasm_path).then((response) => response.arrayBuffer());
   const mod = new WebAssembly.Module(bytes);

   console.log("Initializing WASM instances...");
   wasm_instances = new Array(4);
   wasm_memories = new Array(4);
   memory_views = new Array(4);

   console.log("Creating canvases...");
   canvases = createQuadrantCanvases();

   webgls = canvases.map((canvas, qid) => {
      const gl = canvas.getContext("webgl");
      return gl;
   });

   for (let qid = 0; qid < 4; qid++) {
      const envInstance = {};
      for (const [key, fn] of Object.entries(env)) {
         envInstance[key] = (...args) => fn(...args, qid);
      }
      wasm_instances[qid] = new WebAssembly.Instance(mod, { env: envInstance });
      wasm_memories[qid] = wasm_instances[qid].exports.memory;
      memory_views[qid] = new Uint8Array(wasm_memories[qid].buffer);
   }

   scene_controllers = canvases.map((_, qid) => {
      return new SceneController(qid);
   });

   scene_controllers.forEach((controller, qid) => {
      createQuadrantUI(qid, controller);
   });

   canvases.forEach((canvas, qid) => {
      new ResizeObserver((entries) => resize_listener(entries, qid)).observe(canvas);
   });

   for (let qid = 0; qid < 4; qid++) {
      wasm_instances[qid].exports._start();
   }

   console.log("WASM instances initialized:", wasm_instances);
}
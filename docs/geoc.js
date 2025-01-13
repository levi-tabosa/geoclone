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
* @typedef  {{
*    ptr: number,
*    set_angles_fn_ptr: number,
*    get_pitch_fn_ptr: number,
*    get_yaw_fn_ptr: number,
*    zoom_fn_ptr: number,
*    insert_vector_fn_ptr: number,
*    insert_camera_fn_ptr: number,
*    cube_fn_ptr: number,
*    pyramid_fn_ptr: number,
*    sphere_fn_ptr: number,
*    cone_fn_ptr: number,
*    clear_fn_ptr: number,
*    set_res_fn_ptr: number,
*    set_camera_fn_ptr: number,
*    scale_fn_ptr: number,
*    rotate_fn_ptr: number,
*    translate_fn_ptr: number}
* } Scene
*
* @typedef {{
*    x: number,
*    y: number,
*    z: number}
* } V3
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

/** @type { Scene } */
const scene = {
 ptr: 0,
 set_angles_fn_ptr: 1,
 get_pitch_fn_ptr: 2,
 get_yaw_fn_ptr: 3,
 zoom_fn_ptr: 4,
 insert_vector_fn_ptr: 5,
 insert_camera_fn_ptr: 6,
 cube_fn_ptr: 7,
 pyramid_fn_ptr: 8,
 sphere_fn_ptr: 9,
 cone_fn_ptr: 10,
 clear_fn_ptr: 11,
 set_res_fn_ptr: 12,
 set_camera_fn_ptr: 13,
 scale_fn_ptr: 14,
 rotate_fn_ptr: 15,
 translate_fn_ptr: 16,
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
// Delegate methods matching Zig Scene/Handler methods
class SceneController {
 /**
  * Creates an instance of SceneHandler.
  * @param { WebAssembly.Instance } wasm_instance - The WebAssembly instance.
  * @param { Scene } scene - The scene object.
  */
 constructor(wasm_instance, scene) {
   // Instance properties
   this.wasm_interface = new WasmInterface(wasm_instance, scene);
   this.scene = scene;
   this.wasm_memory = wasm_memory;
   this.vectors = [];
   this.shapes = [];
   this.cameras = [];
   this.selected_vectors = [];
   this.selected_shapes = [];
   this.selected_cameras = [];
   this.is_rotating = false;
   this.rotation_interval = null;
   // Event listeners
   this.handleMouseUp = this.handleMouseUp.bind(this);
   this.handleMouseDown = this.handleMouseDown.bind(this);
   this.handleMouseMove = this.handleMouseMove.bind(this);
   this.handleTouch = this.handleTouch.bind(this);
   this.handleWheel = this.handleWheel.bind(this);
   this.setupEventListeners();
 }

 setupEventListeners() {
   canvas.addEventListener("mouseup", this.handleMouseUp, { passive: true });
   canvas.addEventListener("mousedown", this.handleMouseDown, {
     passive: true,
   });
   canvas.addEventListener("mousemove", this.handleMouseMove, {
     passive: true,
   });
   // canvas.addEventListener("mouseleave", this.handleMouseUp);
   canvas.addEventListener("touchstart", this.handleMouseDown, {
     passive: true,
   });
   canvas.addEventListener("touchend", this.handleMouseUp, { passive: true });
   canvas.addEventListener("touchmove", this.handleTouch);
   canvas.addEventListener("wheel", this.handleWheel, { passive: true });
 }

 handleMouseUp(/** @type { MouseEvent} */ _e) {
   state.is_pressed = false;
 }

 handleMouseDown(/** @type { MouseEvent} */ _e) {
   state.is_pressed = true;
 }

 handleMouseMove(/** @type { MouseEvent} */ e) {
   if (!state.is_pressed) return;

   const { left, top, width, height } = canvas.getBoundingClientRect();
   this.wasm_interface.setAngles(
     ((e.clientY - top) * Math.PI * 2) / height,
     ((e.clientX - left) * Math.PI * 2) / width
   );
 }

 handleTouchStart(/** @type { TouchEvent } */ e) {
   if (e.touches.length === 2) {
     state.initial_pinch_distance = Math.hypot(
       e.touches[0].clientX - e.touches[1].clientX,
       e.touches[0].clientY - e.touches[1].clientY
     );
   } else if (e.touches.length === 1) {
     state.is_pressed = true;
   }
 }

 handleTouchEnd(/** @type { TouchEvent } */ e) {
   state.is_pressed = false;
   state.initial_pinch_distance = -1;
   e.preventDefault();
 }

 handleTouch(/** @type { TouchEvent } */ e) {
   if (e.touches.length === 2) {
     const current_distance = Math.hypot(
       e.touches.item(0).clientX - e.touches.item(1).clientX,
       e.touches.item(0).clientY - e.touches.item(1).clientY
     );

     if (state.initial_pinch_distance < 0) {
       const pinch_delta =
         (current_distance - state.initial_pinch_distance) /
         CONFIG.PINCH_ZOOM_SENSITIVITY;
       this.updateZoom(-pinch_delta);
       state.initial_pinch_distance = current_distance;
     }
   } else if (e.touches.length === 1 && state.is_pressed) {
     const { left, top, width, height } = canvas.getBoundingClientRect();
     this.wasm_interface.setAngles(
       ((e.touches.item(0).clientY - top) * Math.PI * 2) / height,
       ((e.touches.item(0).clientX - left) * Math.PI * 2) / width
     );
   }
   e.preventDefault();
 }

 handleWheel(/** @type { WheelEvent }*/ e) {
   const zoom_delta = -e.deltaY / CONFIG.ZOOM_SENSITIVITY;
   this.wasm_interface.setZoom(zoom_delta);
 }

 insertVector(x, y, z) {
   const [xf, yf, zf] = [parseFloat(x), parseFloat(y), parseFloat(z)];
   if ([xf, yf, zf].some(isNaN)) return;

   this.wasm_interface.insertVector(xf, yf, zf);
   this.vectors.push({ x: xf, y: yf, z: zf });
   this.updateTable();
 }

 insertCamera(x, y, z) {
   this.wasm_interface.insertCamera(
     parseFloat(x) || 0,
     parseFloat(y) || 0,
     parseFloat(z) || 0
   );
   this.cameras.push(`Camera@${this.cameras.length}`);
   this.updateTable();
 }

 insertShape(/** @type { String } */ shape) {
   this.wasm_interface.insertShape(shape);
   this.shapes.push(shape);
   this.updateTable();
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

   const s_step = Math.pow(factor, 1 / FRAMES);

   const buffer = new Uint32Array(wasm_memory.buffer);
   const offset = buffer.length - len;
   buffer.set(combined, offset);

   const s_interval = setInterval(() => {
     this.wasm_interface.scale(
       offset * 4, // u32 4 bytes pointer alignment
       len,
       shorts,
       s_step
     );
   }, INTERVAL);
   setTimeout(() => clearInterval(s_interval), FRAMES * INTERVAL);

   this.selected_vectors.forEach((idx) => {
     let { x, y, z } = this.vectors[idx];
     x *= factor;
     y *= factor;
     z *= factor;
     this.vectors[idx] = { x, y, z };
   });

   this.updateTable();
 }

 rotate(angle_x, angle_y, angle_z) {
   const combined = this.concatAndGetSelected();

   const len = combined.length;
   if (len === 0 || [angle_x, angle_y, angle_z].some(isNaN)) {
     this.toggleAutoRotation();
     return;
   }

   const shorts =
     (this.selected_vectors.length << 16) + this.selected_shapes.length;

   const buffer = new Uint32Array(this.wasm_memory.buffer);
   const offset = buffer.length - len;
   buffer.set(combined, offset);

   const rotateAxis = (axis, step) => {
     this.wasm_interface.rotate(
       offset * 4,
       len,
       shorts,
       axis === "x" ? step : 0,
       axis === "y" ? step : 0,
       axis === "z" ? step : 0
     );
   };

   const r_step = {
     x: angle_x / FRAMES,
     y: angle_y / FRAMES,
     z: angle_z / FRAMES,
   };

   const flags =
     0 | (r_step.x ? 1 : 0) | (r_step.y ? 2 : 0) | (r_step.z ? 4 : 0);

   let count = 0;
   const r_interval = setInterval(() => {
     if (count < FRAMES) {
       if ((flags & 1) == 1) rotateAxis("x", r_step.x);
       else count += FRAMES;
     } else if (count < FRAMES * 2) {
       if ((flags & 2) == 2) rotateAxis("y", r_step.y);
       else count += FRAMES;
     } else if (count < FRAMES * 3) {
       if ((flags & 4) == 4) rotateAxis("z", r_step.z);
       else count += FRAMES;
     } else clearInterval(r_interval);
     count++;
   }, INTERVAL);

   this.selected_vectors.forEach((idx) => {
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

   this.updateTable();
 }

 translate(dx, dy, dz) {
   const combined = this.concatAndGetSelected();
   const len = combined.length;
   if (len === 0 || [dx, dy, dz].some(isNaN)) return;

   const shorts =
     (this.selected_vectors.length << 16) + this.selected_shapes.length;

   const buffer = new Uint32Array(this.wasm_memory.buffer);
   const offset = buffer.length - len;
   buffer.set(combined, offset);
   
   const t_step = { x: dx / FRAMES, y: dy / FRAMES, z: dz / FRAMES };
   const t_interval = setInterval(() => {
     this.wasm_interface.translate(
       offset * 4,
       len,
       shorts,
       t_step.x,
       t_step.y,
       t_step.z
     );
   }, INTERVAL);
   setTimeout(() => clearInterval(t_interval), FRAMES * INTERVAL);

   this.selected_vectors.forEach((idx) => {
     let { x, y, z } = this.vectors[idx];
     x += parseFloat(dx) || 0;
     y += parseFloat(dy) || 0;
     z += parseFloat(dz) || 0;

     this.vectors[idx] = { x, y, z };
   });
   this.updateTable();
 }

 updateTable() {
   const vectors_column = document.getElementById("vectors-column");
   const shapes_column = document.getElementById("shapes-column");
   const cameras_column = document.getElementById("cameras-column");

   vectors_column.innerHTML = ""; //TODO: maybe change later
   shapes_column.innerHTML = "";
   cameras_column.innerHTML = "";

   this.vectors.forEach((vector) => {
     this.addColumnItem(
       vectors_column,
       "vector-item",
       `${vector.x.toFixed(2)},
       ${vector.y.toFixed(2)},
       ${vector.z.toFixed(2)}`
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
   /** @type {String} */ text,
   listener
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
   const new_selected_cameras = Array.from(camera_items).map((camera) =>
     Array.from(camera.parentElement.children).indexOf(camera)
   );
   new_selected_cameras.forEach((index) => {
     if (!this.selected_cameras.includes(index)) {
       this.wasm_interface.setCamera(index);
     }
   });

   if(new_selected_cameras.length === 0) this.wasm_interface.setCamera(-1);

   this.selected_cameras = new_selected_cameras;
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
   return this.selected_vectors.concat(
     this.selected_shapes,
     this.selected_cameras
   );
 }
}

class WasmInterface {
 constructor(wasm_instance, scene) {
   this.wasm_exports = wasm_instance.exports;
   this.scene = scene;
 }

 setAngles(p_angle, y_angle) {
   this.wasm_exports.setAngles(
     this.scene.ptr,
     this.scene.set_angles_fn_ptr,
     p_angle,
     y_angle
   );
 }

 setZoom(zoom_delta) {
   this.wasm_exports.setZoom(
     this.scene.ptr,
     this.scene.zoom_fn_ptr,
     zoom_delta
   );
 }

 getPitch() {
   return wasm_instance.exports.getPitch(
     scene.ptr,
     scene.get_pitch_fn_ptr
   );
 }

 insertVector(x, y, z) {
   this.wasm_exports.insertVector(
     this.scene.ptr,
     this.scene.insert_vector_fn_ptr,
     x,
     y,
     z
   );
 }

 insertCamera(x, y, z) {
   this.wasm_exports.insertCamera(
     this.scene.ptr,
     this.scene.insert_camera_fn_ptr,
     x,
     y,
     z
   );
 }

 insertShape(shape) {
   const shapeFnPtr = this.scene[`${shape.toLowerCase()}_fn_ptr`];
   this.wasm_exports[`insert${shape}`](this.scene.ptr, shapeFnPtr);
 }

 clear() {
   this.wasm_exports.clear(this.scene.ptr, this.scene.clear_fn_ptr);
 }

 setResolution(resolution) {
   this.wasm_exports.setResolution(
     this.scene.ptr,
     this.scene.set_res_fn_ptr,
     resolution
   );
 }

 setCamera(index) {
   this.wasm_exports.setCamera(
     this.scene.ptr,
     this.scene.set_camera_fn_ptr,
     index
   );
 }

 rotate(indexes_ptr, indexes_len, shorts, x, y, z) {
   this.wasm_exports.rotate(
     this.scene.ptr,
     this.scene.rotate_fn_ptr,
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
     this.scene.ptr,
     this.scene.scale_fn_ptr,
     indexes_ptr,
     indexes_len,
     shorts,
     factor
   );
 }

 translate(indexes_ptr, indexes_len, shorts, dx, dy, dz) {
   this.wasm_exports.translate(
     this.scene.ptr,
     this.scene.translate_fn_ptr,
     indexes_ptr,
     indexes_len,
     shorts,
     dx,
     dy,
     dz
   );
 }
}

const resize_listener = (entries) => {
 const { width, height } = entries[0].contentRect;
 canvas.width = width;
 canvas.height = height;

 webgl.viewport(0, 0, width, height);
 setAspectRatioUniform(width / height);
 scene_config.aspect_ratio = width / height;
};

function setAspectRatioUniform(/** @type { number} */ aspect_ratio) {
 for (let i = 0; i < next_program; i++) {
   const program = programs.get(i);

   webgl.useProgram(program.gl);
   webgl.uniformMatrix4fv(
     webgl.getUniformLocation(program.gl, "projection_matrix"),
     false,
     createProjectionMatrix(
       scene_config.fov,
       aspect_ratio,
       scene_config.near,
       scene_config.far
     )
   );
 }
}

function setPerspectiveUniforms(
 /** @type { number} */ fov,
 /** @type { number} */ near,
 /** @type { number} */ far
) {
 for (let i = 0; i < next_program; i++) {
   const program = programs.get(i);
   webgl.useProgram(program.gl);
   webgl.uniformMatrix4fv(
     webgl.getUniformLocation(program.gl, "projection_matrix"),
     false,
     createProjectionMatrix(fov, scene_config.aspect_ratio, near, far)
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

function createButtonListeners(/** @type { SceneController } */ scene_handler) {
 return [
   () => {
     scene_handler.insertVector(input1.value, input2.value, input3.value);
     input1.value = input2.value = input3.value = "";
   },
   () => scene_handler.clear(),
   () => {
     scene_handler.rotate(input1.value, input2.value, input3.value);
     input1.value = input2.value = input3.value = "";
   },
   () => scene_handler.insertShape("Cube"),
   () => console.log("Toggle"),
   () => {
     scene_handler.scale(input1.value);
     input1.value = "";
   },
   () => scene_handler.insertShape("Pyramid"),
   () => {},
   () => {
     scene_handler.translate(input1.value, input2.value, input3.value);
     input1.value = input2.value = input3.value = "";
   },
   () => scene_handler.insertShape("Sphere"),
   () => {},
   () => {},
   () => scene_handler.insertShape("Cone"),
   () => scene_handler.project(),
   () => {},
   () => {
     scene_handler.insertCamera(input1.value, input2.value, input3.value);
     input1.value = input2.value = input3.value = "";
   },
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
   "Camera",
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

function createToggleButtonGrid() {
 return createButton("toggle-grid-btn", "Btns", () => {
   document.getElementById("button-grid").classList.toggle("hidden");
 });
}

function createFloatingTable() {
 const table = document.createElement("div");
 table.id = "floating-table";

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
 vectorsColumn.id = "vectors-column";
 vectorsColumn.className = "table-column";

 const shapesColumn = document.createElement("div");
 shapesColumn.id = "shapes-column";
 shapesColumn.className = "table-column";

 const camerasColumn = document.createElement("div");
 camerasColumn.id = "cameras-column";
 camerasColumn.className = "table-column";

 content.appendChild(vectorsColumn);
 content.appendChild(shapesColumn);
 content.appendChild(camerasColumn);

 table.appendChild(header);
 table.appendChild(content);
 return table;
}

function createToggleTableButton() {
 const btn = document.createElement("button");
 btn.id = "toggle-table-btn";
 btn.textContent = "▼";
 btn.addEventListener("click", () => {
   btn.classList.toggle("expanded");
   document.getElementById("floating-table").classList.toggle("hidden");
 });
 return btn;
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

function createPerspectiveInputs(/** @type {SceneController} */ scene_handler) {
 const container = document.createElement("div");
 container.id = "perspective-inputs";

 const input1 = document.createElement("input");
 input1.id = "near-input";
 input1.placeholder = "Near";

 const input2 = document.createElement("input");
 input2.id = "far-input";
 input2.placeholder = "Far";

 const input3 = document.createElement("input");
 input3.id = "grid-input";
 input3.placeholder = "Grid resolution";

 const input4 = document.createElement("input");
 input4.id = "fov-input";
 input4.placeholder = "FOV";

 const button = document.createElement("button");
 button.id = "perspective-input-button";
 button.textContent = "Set";

 button.addEventListener("click", () => {
   const near = parseFloat(input1.value) || scene_config.near;
   const far = parseFloat(input2.value) || scene_config.far;
   const fov = (parseFloat(input4.value) * Math.PI) / 180 || scene_config.fov;
   const resolution = parseFloat(input3.value);

   setPerspectiveUniforms(fov, near, far);

   if (!isNaN(resolution)) {
     scene_handler.setResolution(resolution);
   }

   scene_config.near = near;
   scene_config.far = far;
   scene_config.fov = fov;

   input1.value = input2.value = input3.value = input4.value = "";
 });

 container.append(input1, input2, input3, input4, button);

 return container;
}

const env = {
 init: function () {
   canvas = document.createElement("canvas");
   webgl = canvas.getContext("webgl");
   if (webgl == null) {
     throw new Error("No WebGL support on browser");
   }

   const scene_handler = new SceneController(wasm_instance, scene);

   btn_listeners.splice(
     0,
     btn_listeners.length,
     ...createButtonListeners(scene_handler)
   );

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

   new ResizeObserver(resize_listener).observe(canvas);

   body.appendChild(container);
   container.append(
     canvas,
     text_fields,
     createButtonGrid(),
     createToggleButtonGrid(),
     createFloatingTable(),
     createToggleTableButton(),
     createColorButtonGrid(),
     createPerspectiveInputs(scene_handler)
   );
   text_fields.append(...inputs);
 },
 deinit: function () {
   webgl.finish();
 },
 run: function (ptr, fnPtr) {
   function frame() {
     call(ptr, fnPtr);
     setTimeout(() => requestAnimationFrame(frame), 1000 / FPS);
   }
   requestAnimationFrame(frame);
   throw new Error("Not an error");
 },
 setScene: function (ptr) {
   scene.ptr = ptr;
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
   // if (!program) throw new Error("Failed to create program");

   const shader1 = shaders.get(shader1_handle);
   const shader2 = shaders.get(shader2_handle);
   // if (!shader1 || !shader2) throw new Error("Failed to attach shaders");

   webgl.attachShader(program, shader1);
   webgl.attachShader(program, shader2);
   webgl.linkProgram(program);

   // if (!webgl.getProgramParameter(program, webgl.LINK_STATUS)) {
   //   throw new Error(
   //     `Failed to link program: ${webgl.getProgramInfoLog(program)}`
   //   );
   // }

   const attribute_count = webgl.getProgramParameter(
     program,
     webgl.ACTIVE_ATTRIBUTES
   );
   const attributes = new Map();

   for (let i = 0; i < attribute_count; i++) {
     const attribute = webgl.getActiveAttrib(program, i);
     if (attribute)
       attributes.set(attribute.name, { index: i, info: attribute });
   }

   const uniform_count = webgl.getProgramParameter(
     program,
     webgl.ACTIVE_UNIFORMS
   );
   const uniforms = new Map();

   for (let i = 0; i < uniform_count; i++) {
     const uniform = webgl.getActiveUniform(program, i);
     if (uniform) uniforms.set(uniform.name, uniform);
   }

   webgl.useProgram(program);

   const fov = 1.4;
   const aspect_ratio = canvas.width / canvas.height;
   const near = 0.1;
   const far = 100.0;

   webgl.uniformMatrix4fv(
     webgl.getUniformLocation(program, "projection_matrix"),
     false,
     createProjectionMatrix(fov, aspect_ratio, near, far)
   );

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
   // if (!vertex_buffer) throw new Error("Failed to create buffer");

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
 uniformMatrix4fv(location_ptr, location_len, transpose, value_ptr) {
   const location = new TextDecoder().decode(
     getData(location_ptr, location_len)
   );
   const value = new Float32Array(wasm_memory.buffer, value_ptr, 16);
   for (let i = 0; i < next_program; i++) {
     const program = programs.get(i);
     webgl.useProgram(program.gl);
     webgl.uniformMatrix4fv(
       webgl.getUniformLocation(program.gl, location),
       transpose,
       value
     );
   }
 },
};

export async function init(wasm_path) {
 const promise = fetch(wasm_path);
 const result = await WebAssembly.instantiateStreaming(promise, { env });
 wasm_instance = result.instance;
 wasm_memory = wasm_instance.exports.memory;
 wasm_instance.exports._start();
}

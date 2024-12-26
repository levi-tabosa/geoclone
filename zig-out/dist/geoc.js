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
 *    zoom_fn_ptr: number,
 *    insert_fn_ptr: number,
 *    clear_fn_ptr: number,
 *    set_res_fn_ptr: number,
 *    cube_fn_ptr: number,
 *    pyramid_fn_ptr: number,
 *    sphere_fn_ptr: number,
 *    cone_fn_ptr: number,
 *    rotate_fn_ptr: number,
 *    scale_fn_ptr: number,
 *    translate_fn_ptr: number}
 * } Scene
 *
 * @typedef {{
 *    x: number,
 *    y: number,
 *    z: number}
 * } Vector
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
  fps = 100;

/**
 * @typedef {Object} State
 * @property {boolean} is_pressed - Indicates if a press action is active.
 * @property {number} last_x - The last recorded x-coordinate.
 * @property {number} last_y - The last recorded y-coordinate.
 * @property {number} initial_pinch_distance - The initial distance between two touch points for pinch gestures.
 */
const state = {
  is_pressed: false,
  last_x: 0,
  last_y: 0,
  initial_pinch_distance: -1,
};

const CONFIG = {
  ZOOM_SENSITIVITY: 5e-4,
  PINCH_ZOOM_SENSITIVITY: 2000,
};

/** @type { Scene } */
const scene = {
  ptr: 0,
  set_angles_fn_ptr: 1,
  get_pitch_fn_ptr: 2,
  zoom_fn_ptr: 3,
  insert_fn_ptr: 4,
  clear_fn_ptr: 5,
  set_res_fn_ptr: 6,
  cube_fn_ptr: 7,
  pyramid_fn_ptr: 8,
  sphere_fn_ptr: 9,
  cone_fn_ptr: 10,
  rotate_fn_ptr: 11,
  scale_fn_ptr: 12,
  translate_fn_ptr: 13,
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
    this.wasm_instance = wasm_instance;
    this.scene = scene;
    this.wasm_memory = wasm_instance.exports.memory;
    this.vectors = [];
    this.shapes = [];
    this.shapes_map = {
      Cube: scene.cube_fn_ptr,
      Pyramid: scene.pyramid_fn_ptr,
      Sphere: scene.sphere_fn_ptr,
      Cone: scene.cone_fn_ptr,
    };
    this.selected_indexes = [];
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
    canvas.addEventListener("mouseup", this.handleMouseUp);
    canvas.addEventListener("mousedown", this.handleMouseDown);
    canvas.addEventListener("mousemove", this.handleMouseMove);
    canvas.addEventListener("mouseleave", this.handleMouseUp);
    canvas.addEventListener("touchstart", this.handleMouseDown);
    canvas.addEventListener("touchend", this.handleMouseUp, { passive: true });
    canvas.addEventListener("touchmove", this.handleTouch, { passive: true });
    canvas.addEventListener("wheel", this.handleWheel);
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
    this.setAngles(
      ((e.clientX - left) * Math.PI * 2) / width,
      ((e.clientY - top) * Math.PI * 2) / height
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
        e.touches[0].clientX - e.touches[1].clientX,
        e.touches[0].clientY - e.touches[1].clientY
      );

      if (state.initial_pinch_distance < 0) {
        const pinch_delta =
          (current_distance - state.initial_pinch_distance) /
          CONFIG.PINCH_ZOOM_SENSITIVITY;
        this.updateZoom(-pinch_delta); // Natural zoom direction is inverted
        state.initial_pinch_distance = current_distance;
      }
    } else if (e.touches.length === 1 && state.is_pressed) {
      const { left, top, width, height } = canvas.getBoundingClientRect();

      this.setAngles(
        ((e[0].clientX - left) * Math.PI * 2) / width,
        ((e[0].clientY - top) * Math.PI * 2) / height
      );
    }
    e.preventDefault();
  }

  handleWheel(/** @type { WheelEvent }*/ e) {
    const zoom_delta = e.deltaY / CONFIG.ZOOM_SENSITIVITY;
    console.log("on JS \n zoom_delta : ", zoom_delta);
    this.setZoom(zoom_delta);
  }

  setAngles(/** @type { number } */ y_angle, /** @type { number } */ p_angle) {
    this.wasm_instance.exports.setAngles(
      this.scene.ptr,
      this.scene.set_angles_fn_ptr,
      p_angle,
      y_angle
    );
  }

  setZoom(/** @type { number } */ delta) {
    this.wasm_instance.exports.setZoom(
      this.scene.ptr,
      this.scene.zoom_fn_ptr,
      delta
    );
  }

  insertVector(x, y, z) {
    const [xf, yf, zf] = [parseFloat(x), parseFloat(y), parseFloat(z)];
    if ([xf, yf, zf].some(isNaN)) return;

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

  clear() {
    this.wasm_instance.exports.clear(this.scene.ptr, this.scene.clear_fn_ptr);
    this.clearVectorList();
    this.vectors = [];
  }

  setResolution(/** @type { number } */ res) {
    console.log("on JS \n res : ", res, "\t ptr : ", this.scene.set_res_fn_ptr);
    this.wasm_instance.exports.setResolution(
      this.scene.ptr,
      this.scene.set_res_fn_ptr,
      res
    );
  }

  insertShape(/** @type { String } */ shape) {
    if (this.shapes_map[shape]) {
      this.wasm_instance.exports[`insert${shape}`](
        this.scene.ptr,
        this.shapes_map[shape]
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
    const len = this.selected_indexes.length;
    if (len === 0 || [angle_x, angle_y, angle_z].some(isNaN)) return;

    const r_step = {
      x: angle_x / frames,
      y: angle_y / frames,
      z: angle_z / frames,
    };
    let count = 0;
    const buffer = new Uint32Array(this.wasm_memory.buffer);
    const offset = buffer.length - len;

    buffer.set(this.selected_indexes, offset);

    const rotateAxis = (axis, step) => {
      this.wasm_instance.exports.rotate(
        this.scene.ptr,
        this.scene.rotate_fn_ptr,
        offset * 4,
        len,
        axis === "x" ? step : 0,
        axis === "y" ? step : 0,
        axis === "z" ? step : 0
      );
    };

    const r_interval = setInterval(() => {
      if (count < frames) {
        if (!isNaN(parseFloat(angle_x))) rotateAxis("x", r_step.x);
        else count += frames;
      } else if (count < frames * 2) {
        if (!isNaN(parseFloat(angle_y))) rotateAxis("y", r_step.y);
        else count += frames;
      } else if (count <= frames * 3) {
        if (!isNaN(parseFloat(angle_z))) rotateAxis("z", r_step.z);
        else count += frames;
      } else clearInterval(r_interval);
      count++;
    }, interval);

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

    this.updateList();
  }

  scale(factor) {
    const len = this.selected_indexes.length;
    if (len === 0 || isNaN(parseFloat(factor))) return;
    const s_step = Math.pow(factor, 1 / frames);

    const buffer = new Uint32Array(wasm_memory.buffer);
    const offset = buffer.length - len;

    buffer.set(this.selected_indexes, offset);
    const s_interval = setInterval(() => {
      this.wasm_instance.exports.scale(
        this.scene.ptr,
        this.scene.scale_fn_ptr,
        offset * 4, // u32 4 bytes pointer alignment
        len,
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

    this.updateList();
  }

  translate(dx, dy, dz) {
    const len = this.selected_indexes.length;
    if (len === 0 || [dx, dy, dz].some(isNaN)) return;

    const t_step = { x: dx / frames, y: dy / frames, z: dz / frames };
    const buffer = new Uint32Array(wasm_memory.buffer);
    const offset = buffer.length - len;

    buffer.set(this.selected_indexes, offset);
    const t_interval = setInterval(() => {
      this.wasm_instance.exports.translate(
        this.scene.ptr,
        this.scene.translate_fn_ptr,
        offset * 4,
        len,
        t_step.x,
        t_step.y,
        t_step.z
      );
    }, interval);
    setTimeout(() => clearInterval(t_interval), frames * interval);

    this.selected_indexes.forEach((idx) => {
      let { x, y, z } = this.vectors[idx];
      x += parseFloat(dx) || 0;
      y += parseFloat(dy) || 0;
      z += parseFloat(dz) || 0;

      this.vectors[idx] = { x, y, z };
    });
    this.updateList();
  }

  addVectorToList(
    /** @type { number } */ x,
    /** @type { number } */ y,
    /** @type { number } */ z
  ) {
    const list = document.getElementById("vector-list");
    const item = document.createElement("div");
    item.textContent = `${x}, ${y}, ${z}`;
    item.className = "vector-item";

    item.addEventListener("click", (event) => {
      if (event.ctrlKey) {
        item.classList.toggle("selected");
      } else {
        document
          .querySelectorAll(".vector-item")
          .forEach((item) => item.classList.remove("selected"));
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

  updateList() {
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
    } else if (
      document.querySelectorAll(".vector-item.selected").length === 0
    ) {
      this.is_rotating = true;
      let angle_z = 0;

      this.rotation_interval = setInterval(() => {
        const angle_x = wasm_instance.exports.getPitch(
          scene.ptr,
          scene.get_pitch_fn_ptr
        );
        angle_z += 0.03;
        angle_z %= Math.PI * 2;
        wasm_instance.exports.setAngles(
          scene.ptr,
          scene.set_angles_fn_ptr,
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

const resize_listener = (entries) => {
  const { width, height } = entries[0].contentRect;
  canvas.width = width;
  canvas.height = height;
  webgl.viewport(0, 0, width, height);
  _setAspectRatioUniform(width / height);
};

function _setPerspectiveUniforms(near, far) {
  for (let i = 0; i < next_program; i++) {
    const program = programs.get(i);
    if (!program || !program.uniforms.has("near")) continue;
    const u_near = webgl.getUniformLocation(program.gl, "near");
    const u_far = webgl.getUniformLocation(program.gl, "far");
    webgl.useProgram(program.gl);
    webgl.uniform1f(u_near, near);
    webgl.uniform1f(u_far, far);
  }
}

function _setAspectRatioUniform(/** @type { number} */ aspect_ratio) {
  for (let i = 0; i < next_program; i++) {
    const program = programs.get(i);

    if (!program || !program.uniforms.has("near")) continue;
    const u_aspect_ratio = webgl.getUniformLocation(program.gl, "aspect_ratio");
    webgl.useProgram(program.gl);
    webgl.uniform1f(u_aspect_ratio, aspect_ratio);
  }
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
    },
    () => scene_handler.insertCube(),
    () => console.log("Toggle"),
    () => {
      scene_handler.scale(input1.value);
      input1.value = "";
    },
    () => scene_handler.insertPyramid(),
    () => {},
    () => {
      scene_handler.translate(input1.value, input2.value, input3.value);
      input1.value = input2.value = input3.value = "";
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
}

function createColorButtonGrid() {
  const grid = document.createElement("div");
  grid.id = "color-button-grid";

  const colors = ["black", "gray", "green"];

  colors.forEach((color) => {
    const btn = createButton(`color-btn-${color}`, "", () => {
      document.getElementById("canvas").style.backgroundColor = color;
    });
    btn.className = `color-button ${color}`;
    grid.appendChild(btn);
  });

  return grid;
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
  input3.placeholder = "11";

  const button = document.createElement("button");
  button.id = "perspective-input-button";
  button.textContent = "Set";
  button.addEventListener("click", () => {
    const near = parseFloat(input1.value);
    const far = parseFloat(input2.value);
    const resolution = parseFloat(input3.value);

    if (!isNaN(near) && !isNaN(far)) {
      console.log("on JS \n near : ", near, "\t far : ", far);
      _setPerspectiveUniforms(near, far);
    }

    if (!isNaN(resolution)) {
      scene_handler.setResolution(resolution);
    }

    input1.value = input2.value = input3.value = "";
  });

  container.append(input1, input2, input3, button);

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
      createToggleGridButton(),
      createVectorList(),
      createToggleVectorListButton(),
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
      setTimeout(() => requestAnimationFrame(frame), 1000 / fps);
    }
    requestAnimationFrame(frame);
    throw new Error("Not an error");
  },
  setScene: function (ptr) {
    Object.assign(scene, {
      ptr: ptr,
    });
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

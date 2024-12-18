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
 *    angles_fn_ptr: number
 *    get_ax_fn_ptr: number
 *    zoom_fn_ptr: number
 *    insert_fn_ptr: number
 *    clear_fn_ptr: number
 *    cube_fn_ptr: number
 *    pyramid_fn_ptr: number
 *    sphere_fn_ptr: number
 *    cone_fn_ptr: number
 *    rotate_fn_ptr: number
 *    scale_fn_ptr: number
 *    }
 * } Scene
 * */

/** Context and Globals **/
let canvas, webgl, wasm_instance, wasm_memory;
let shaders = new Map(),
  programs = new Map(),
  buffers = new Map();
let next_shader = 0,
  next_program = 0,
  next_buffer = 0;

let isAutoRotating = false;
let autoRotationInterval = null;
let is_pressed = false;

/** @type { Scene } */
let scene = {
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
};

function getData(c_ptr, len) {
  //TODO: move to scene handler
  return new Uint8Array(wasm_memory.buffer, c_ptr, len);
}

function getStr(c_ptr, len) {
  //TODO: move to scene handler
  return new TextDecoder().decode(getData(c_ptr, len));
}

function call(ptr, fnPtr) {
  //TODO: move to scene handler
  wasm_instance.exports.draw(ptr, fnPtr);
}

const up_listener = () => {
  is_pressed = false;
};

const down_listener = () => {
  is_pressed = true;
};

const move_listener = (e) => {
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

function toggleAutoRotation() {
  if (isAutoRotating) {
    clearInterval(autoRotationInterval);
    isAutoRotating = false;
    return;
  }

  const selectedVectors = document.querySelectorAll(".vector-item.selected");
  if (selectedVectors.length == 0) {
    isAutoRotating = true;
    let angle_z = 0;

    autoRotationInterval = setInterval(() => {
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
    }, 15);
  }
}

class SceneHandler {
  constructor(wasm_instance, scene) {
    this.wasm_instance = wasm_instance;
    this.scene = scene;
    this.vectors = [];
    this.shapes = [];
    this.selected_indexes = [];
    this.interval = null;
  }

  // Delegate methods matching Zig Scene/Handler methods
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
      console.log({ xf, yf, zf });
      this.vectors.push({ x: xf, y: yf, z: zf });
      this.addVectorToList(xf.toFixed(2), yf.toFixed(2), zf.toFixed(2));
      console.log(this.vectors);
    }
  }

  clear() {
    this.wasm_instance.exports.clear(this.scene.ptr, this.scene.clear_fn_ptr);
    this.clearVectorList();
    this.vectors = [];
  }

  insertCube() {
    this.wasm_instance.exports.insertCube(
      this.scene.ptr,
      this.scene.cube_fn_ptr
    );
    this.shapes.push("Cube");
  }

  insertPyramid() {
    this.wasm_instance.exports.insertPyramid(
      this.scene.ptr,
      this.scene.pyramid_fn_ptr
    );
    this.shapes.push("Pyramid");
  }

  insertSphere() {
    this.wasm_instance.exports.insertSphere(
      this.scene.ptr,
      this.scene.sphere_fn_ptr
    );
    this.shapes.push("Sphere");
  }

  insertCone() {
    this.wasm_instance.exports.insertCone(
      this.scene.ptr,
      this.scene.cone_fn_ptr
    );
    this.shapes.push("Cone");
  }

  rotate(angle_x, angle_y, angle_z) {
    const idxs_len = this.selected_indexes.length;
    if (idxs_len > 0) {
      const buffer = new Uint32Array(this.wasm_instance.exports.memory.buffer);
      const offset = buffer.length - idxs_len;
      buffer.set(this.selected_indexes, offset);
      this.wasm_instance.exports.rotate(
        this.scene.ptr,
        this.scene.rotate_fn_ptr,
        offset * 4,
        idxs_len,
        angle_x,
        angle_y,
        angle_z
      );
      this.selected_indexes.forEach((idx) => {
        let { x, y, z } = this.vectors[idx];
        let tmp_x = x * Math.cos(angle_z) - y * Math.sin(angle_z);
        let tmp_y = x * Math.sin(angle_z) + y * Math.cos(angle_z);

        x = tmp_x;
        y = tmp_y;
        let tmp_z = z * Math.cos(angle_y) - x * Math.sin(angle_y);

        x = z * Math.sin(angle_y) + x * Math.cos(angle_y);
        z = tmp_z;
        tmp_y = y * Math.cos(angle_x) - z * Math.sin(angle_x);

        z = y * Math.sin(angle_x) + z * Math.cos(angle_x);
        y = tmp_y;
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
      const buffer = new Uint32Array(wasm_memory.buffer);
      const offset = buffer.length - idxs_len;

      buffer.set(this.selected_indexes, offset);

      this.wasm_instance.exports.scale(
        this.scene.ptr,
        this.scene.scale_fn_ptr,
        offset * 4, // u32 4 bytes pointer alignment
        idxs_len,
        factor
      );

      this.updateVectorList();
    } else {
      alert("Please select elements for scaling");
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

  clearVectorList() {
    const list = document.getElementById("vector-list");
    list.innerHTML = "";
    // this.vectors = [];
    this.updateSelectedIndexes();
  }
}

function createButtonListeners(scene_handler) {
  return [
    // Insert Vector
    () => {
      const x = input1.value;
      const y = input2.value;
      const z = input3.value;
      scene_handler.addVector(x, y, z);

      input1.value = input2.value = input3.value = "";
    },
    // Clear
    () => scene_handler.clear(),
    // Rotate
    () => {
      const x = input1.value;
      const y = input2.value;
      const z = input3.value;

      if (x || y || z) {
        scene_handler.rotate(x, y, z);
      } else {
        toggleAutoRotation();
      }
    },
    // Insert Cube
    () => scene_handler.insertCube(),
    // Toggle
    () => {
      console.log("Toggle");
    },
    // Scale
    () => {
      const factor = input1.value;
      if (factor) {
        scene_handler.scale(factor);
      } else {
        alert("Use the left input box to input factor");
      }
    },
    // Insert Pyramid
    () => scene_handler.insertPyramid(),
    () => {},
    // Translate
    () => {
      const x = input1.value;
      const y = input2.value;
      const z = input3.value;
      scene_handler.translate(x, y, z);
    },
    // Insert Sphere
    () => {
      scene_handler.insertSphere();
    },
    () => {},
    () => {},
    // Insert Cone
    () => {
      scene_handler.insertCone();
    },
    () => {},
    () => {},
    () => {},
    () => {},
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
    "Text",
    "Text",
    "Text",
    "Text",
    "Text",
  ];

  labels.forEach((label, index) => {
    const btn = document.createElement("button");
    btn.textContent = label;
    btn.className = "floating-button";
    btn.id = `grid-btn-${index + 1}`;
    btn.addEventListener("click", btn_listeners[index]);
    grid.appendChild(btn);
  });

  return grid;
}

function createToggleGridButton() {
  const toggleBtn = document.createElement("button");
  toggleBtn.id = "toggle-grid-btn";
  toggleBtn.textContent = "Btns";

  toggleBtn.addEventListener("click", () => {
    const buttonGrid = document.getElementById("button-grid");
    buttonGrid.classList.toggle("hidden");
  });

  return toggleBtn;
}

function createVectorList() {
  const vectorList = document.createElement("div");
  vectorList.id = "vector-list";
  vectorList.className = "floating-list";
  return vectorList;
}

function createToggleVectorListButton() {
  const toggleBtn = document.createElement("button");
  toggleBtn.id = "toggle-vector-list-btn";
  toggleBtn.textContent = "VECTORS";
  toggleBtn.addEventListener("click", () => {
    const vectorList = document.getElementById("vector-list");
    vectorList.classList.toggle("hidden");
  });

  return toggleBtn;
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
    const body = document.getElementsByTagName("body").item(0);
    const container = document.createElement("div");
    const text_fields = document.createElement("div");
    const input1 = document.createElement("input");
    const input2 = document.createElement("input");
    const input3 = document.createElement("input");

    canvas.id = "canvas";
    container.id = "container";
    text_fields.id = "text-inputs";
    input1.id = "input1";
    input2.id = "input2";
    input3.id = "input3";

    if (webgl == null) {
      throw new Error("No WebGL support on browser");
    }

    canvas.addEventListener("mousedown", down_listener);
    canvas.addEventListener("mouseup", up_listener);
    canvas.addEventListener("mousemove", move_listener);
    canvas.addEventListener("wheel", wheel_listener);

    new ResizeObserver((entries) => resize_listener(entries)).observe(canvas);

    body.appendChild(container);
    container.append(
      canvas,
      text_fields,
      createButtonGrid(),
      createToggleGridButton(),
      createVectorList(),
      createToggleVectorListButton()
    );
    text_fields.append(input1, input2, input3);
  },
  deinit: function () {
    webgl.finish();
  },
  run: function (ptr, fnPtr) {
    function frame() {
      call(ptr, fnPtr);

      setTimeout(() => {
        requestAnimationFrame(frame);
      }, 15);
    }
    requestAnimationFrame(frame);
    throw new Error("Not an error");
  },
  //TODO: better way to pass fn pointers from zig to this
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
    scale_fn_ptr
  ) {
    scene.ptr = ptr;
    scene.angles_fn_ptr = angles_fn_ptr;
    scene.get_ax_fn_ptr = get_ax_fn_ptr;
    scene.zoom_fn_ptr = zoom_fn_ptr;
    scene.insert_fn_ptr = insert_fn_ptr;
    scene.clear_fn_ptr = clear_fn_ptr;
    scene.cube_fn_ptr = cube_fn_ptr;
    scene.pyramid_fn_ptr = pyramid_fn_ptr;
    scene.sphere_fn_ptr = sphere_fn_ptr;
    scene.cone_fn_ptr = cone_fn_ptr;
    scene.rotate_fn_ptr = rotate_fn_ptr;
    scene.scale_fn_ptr = scale_fn_ptr;
  },
  _log: function (ptr, len) {
    console.log(getStr(ptr, len));
  },
  clear: function (r, g, b, a) {
    webgl.clearColor(r, g, b, a);
    webgl.clear(webgl.COLOR_BUFFER_BIT);
  },
  time: function () {
    return performance.now() / 1000;
  },
  initShader: function (type, source_ptr, source_len) {
    const shader =
      {
        0: webgl.createShader(webgl.VERTEX_SHADER),
        1: webgl.createShader(webgl.FRAGMENT_SHADER),
      }[type] || null;

    if (shader == null) {
      throw new Error("Invalid shader type");
    }

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
  deinitShader: function (handle) {
    webgl.deleteShader(shaders.get(handle) ?? null);
    next_shader--;
  },
  initProgram: function (shader1_handle, shader2_handle) {
    const program = webgl.createProgram();
    if (program == null) {
      throw new Error(`Failed to create program}`);
    }

    const shader1 = shaders.get(shader1_handle);
    const shader2 = shaders.get(shader2_handle);

    if (!shader1 || !shader2) {
      throw new Error("Failed to shaders attach, shader is not");
    }
    webgl.attachShader(program, shader1);
    webgl.attachShader(program, shader2);
    webgl.linkProgram(program);

    if (!webgl.getProgramParameter(program, webgl.LINK_STATUS)) {
      throw new Error(
        `Failed to link program:${gl.getProgramInfoLog(program)}`
      );
    }

    const attribute_count = webgl.getProgramParameter(
      program,
      webgl.ACTIVE_ATTRIBUTES
    );

    /** @type {Map<string, Attribute>}*/
    const attributes = new Map();

    for (let i = 0; i < attribute_count; i++) {
      const attribute = webgl.getActiveAttrib(program, i);
      if (attribute) {
        attributes.set(attribute.name, { index: i, info: attribute });
      }
    }
    const uniform_count = webgl.getProgramParameter(
      program,
      webgl.ACTIVE_UNIFORMS
    );

    /** @type {Map<string, WebGLActiveInfo>}*/
    const uniforms = new Map();

    for (let i = 0; i < uniform_count; i++) {
      const uniform = webgl.getActiveUniform(program, i);
      if (uniform) {
        uniforms.set(uniform.name, uniform);
      }
    }

    webgl.useProgram(program);
    webgl.uniform1f(
      webgl.getUniformLocation(program, "aspect_ratio"),
      canvas.width / canvas.height
    );

    const handle = next_program++;
    programs.set(handle, {
      gl: program,
      attributes: attributes,
      uniforms: uniforms,
    });
    return handle;
  },
  useProgram: function (handle) {
    const program = programs.get(handle);
    if (program) {
      webgl.useProgram(program.gl);
    }
  },
  deinitProgram: function (handle) {
    const program = programs.get(handle);
    if (program) {
      return;
    }
    programs.delete(handle);
    webgl.deleteProgram(program.gl);
    next_program--;
  },
  initVertexBuffer: function (data_ptr, data_len) {
    const vertex_buffer = webgl.createBuffer();
    if (vertex_buffer == null) {
      throw new Error("Failed to create buffer");
    }

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
  deinitVertexBuffer: function (handle) {
    const buffer = buffers.get(handle) ?? null;
    buffers.delete(handle);
    webgl.deleteBuffer(buffer);
    next_buffer--;
  },
  bindVertexBuffer: function (handle) {
    const vertex_buffer = buffers.get(handle) ?? null;
    webgl.bindBuffer(webgl.ARRAY_BUFFER, vertex_buffer);
  },
  vertexAttribPointer: function (
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
    if (!program) {
      return;
    }

    const attribute = program.attributes.get(getStr(name_ptr, name_len));
    if (!attribute) {
      return;
    }

    let gl_type;
    switch (type) {
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
      offset
    );
  },
  drawArrays: function (mode, first, count) {
    let gl_mode;
    switch (mode) {
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
        throw new Error("Unsupported draw mode");
    }

    webgl.drawArrays(gl_mode, first, count);
  },
};

export async function init(wasm_path) {
  let promise = fetch(wasm_path);
  WebAssembly.instantiateStreaming(promise, {
    env: env,
  }).then((result) => {
    wasm_instance = result.instance;
    wasm_memory = wasm_instance.exports.memory;
    wasm_instance.exports._start();
  });
}

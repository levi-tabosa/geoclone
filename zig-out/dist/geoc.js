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
 *    rotate_fn_ptr: number}
 * } Scene
 * */

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
/** @type { Map<number, Program> } */
let programs = new Map();
let next_program = 0;
/** @type { Map<number, WebGLBuffer> } */
let buffers = new Map();
let next_buffer = 0;

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
  rotate_fn_ptr: 0,
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

const move_listener = (event) => {
  if (is_pressed) {
    const rect = canvas.getBoundingClientRect();
    const pos = { x: event.clientX - rect.left, y: event.clientY - rect.top };
    const angle_x = (pos.y * 6.283185) / rect.height;
    const angle_z = (pos.x * 6.283185) / rect.width;

    wasm_instance.exports.setAngles(
      scene.ptr,
      scene.angles_fn_ptr,
      angle_x,
      angle_z
    );
  }
};

const wheel_listener = (event) => {
  wasm_instance.exports.setZoom(
    scene.ptr,
    scene.zoom_fn_ptr,
    (event.deltaY >> 6) * 0.1
  );
};

const resize_listener = (width, height) => {
  canvas.width = width;
  canvas.height = height;

  const program = programs.get(0);
  if (program) {
    const uniformLocation = webgl.getUniformLocation(
      program.gl,
      "aspect_ratio"
    );
    webgl.uniform1f(uniformLocation, width / height);
  }
  webgl.viewport(0, 0, width, height);
};

function toggleAutoRotation() {
  if (isAutoRotating) {
    clearInterval(autoRotationInterval);
    isAutoRotating = false;
    return;
  }

  const selectedVectors = document.querySelectorAll(".vector-item.selected");
  if (selectedVectors.length === 0) {
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
  constructor(wasm_instance, demo) {
    this.wasm_instance = wasm_instance;
    this.demo = demo;
    this.vectors = [];
    this.selected_indexes = [];
  }
  // Delegate methods matching Zig Scene/Handler methods

  addVector(x, y, z) {
    if ( // You'd think passing nan as a f32 to a V3 would crash or something ...
      !isNaN(parseFloat(x)) &&
      !isNaN(parseFloat(y)) &&
      !isNaN(parseFloat(z))
    ) {
      this.wasm_instance.exports.insertVector(
        this.demo.ptr,
        this.demo.insert_fn_ptr,
        x,
        y,
        z
      );
      // this.vectors.push({ x, y, z });
      this.addVectorToList(parseFloat(x), parseFloat(y), parseFloat(z));
    }
  }

  clear() {
    this.wasm_instance.exports.clear(this.demo.ptr, this.demo.clear_fn_ptr);
    this.clearVectorList();
  }

  insertCube() {
    this.wasm_instance.exports.insertCube(this.demo.ptr, this.demo.cube_fn_ptr);
  }

  insertPyramid() {
    this.wasm_instance.exports.insertPyramid(
      this.demo.ptr,
      this.demo.pyramid_fn_ptr
    );
  }

  handleRotation(x, y, z) {
    const idxs_len = this.selected_indexes.length;
    if (idxs_len > 0) {
      const buffer = new Uint32Array(wasm_memory.buffer);
      const offset = buffer.length - idxs_len;
      
      buffer.set(this.selected_indexes, offset);

      this.wasm_instance.exports.rotate(
        this.demo.ptr,
        this.demo.rotate_fn_ptr,
        offset * 4, // u32 4 bytes pointer alignment
        idxs_len,
        x,
        y,
        z
      );

    } else {
      toggleAutoRotation();
    }
  }

  addVectorToList(x, y, z) {
    const list = document.getElementById("vector-list");
    const item = document.createElement("div");
    item.textContent = `(${x}, ${y}, ${z})`;
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

  clearVectorList() {
    const list = document.getElementById("vector-list");
    list.innerHTML = "";
    this.vectors = [];
    this.updateSelectedIndexes();
  }
}
/**
 * @param {SceneHandler} scene_handler
 */
function createButtonListeners(scene_handler) {
  return [
    // Insert Vector
    () => {
      const x = input1.value;
      const y = input2.value;
      const z = input3.value;
      scene_handler.addVector(x, y, z);

      input1.value = "";
      input2.value = "";
      input3.value = "";
    },
    // Clear
    () => scene_handler.clear(),
    // Rotate
    () => {
      const x = input1.value;
      const y = input2.value;
      const z = input3.value;

      if (x || y || z) {
        scene_handler.handleRotation(x, y, z);
      } else {
        toggleAutoRotation();
      }
    },
    // Insert Cube
    () => scene_handler.insertCube(),
    // Toggle (placeholder)
    () => console.log("Toggle"),
    // Scale (placeholder)
    () => console.log("Scale"),
    // Insert Pyramid
    () => scene_handler.insertPyramid(),
    // Remaining placeholder methods
    ...Array(11).fill(() => console.log("Placeholder")),
  ];
}

const btn_listeners = [];

function createButtonGrid() {
  const buttonGrid = document.createElement("div");
  buttonGrid.id = "button-grid";

  const buttonLabels = [
    "Insert",
    "Clear",
    "Rotate",
    "Cube",
    "Toggle",
    "Scale",
    "Pyramid",
    "Text",
    "Text",
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

  buttonLabels.forEach((label, index) => {
    const btn = document.createElement("button");
    btn.textContent = label;
    btn.className = "floating-button";
    btn.id = `grid-btn-${index + 1}`;
    btn.addEventListener("click", btn_listeners[index]);
    buttonGrid.appendChild(btn);
  });

  return buttonGrid;
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

    new ResizeObserver((entries) => {
      //maybe change to named
      for (let entry of entries) {
        const width = entry.contentRect.width;
        const height = entry.contentRect.height;
        resize_listener(width, height);
      }
    }).observe(canvas);

    body.append(container);
    container.appendChild(canvas);
    container.appendChild(createButtonGrid());
    container.appendChild(createToggleGridButton());
    container.appendChild(createVectorList());
    container.appendChild(createToggleVectorListButton());
    container.appendChild(text_fields);
    text_fields.appendChild(input1);
    text_fields.appendChild(input2);
    text_fields.appendChild(input3);
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
  //TODO: pass in a array of pointers from zig instead
  setSceneCallBack: function (
    ptr,
    angles_fn_ptr,
    get_ax_fn_ptr,
    zoom_fn_ptr,
    insert_fn_ptr,
    clear_fn_ptr,
    cube_fn_ptr,
    pyramid_fn_ptr,
    rotate_fn_ptr
  ) {
    scene.ptr = ptr;
    scene.angles_fn_ptr = angles_fn_ptr;
    scene.get_ax_fn_ptr = get_ax_fn_ptr;
    scene.zoom_fn_ptr = zoom_fn_ptr;
    scene.insert_fn_ptr = insert_fn_ptr;
    scene.clear_fn_ptr = clear_fn_ptr;
    scene.cube_fn_ptr = cube_fn_ptr;
    scene.pyramid_fn_ptr = pyramid_fn_ptr;
    scene.rotate_fn_ptr = rotate_fn_ptr;
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

export async function init(wasmPath) {
  let promise = fetch(wasmPath);
  WebAssembly.instantiateStreaming(promise, {
    env: env,
  }).then((result) => {
    wasm_instance = result.instance;
    wasm_memory = wasm_instance.exports.memory;
    wasm_instance.exports._start();
  });
}

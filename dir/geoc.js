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
*  @typedef {{
*    ptr: number,
*    angles_fn_ptr: number
*    zoom_fn_ptr: number
*    insert_fn_ptr: number
*    clear_fn_ptr: number
*    cube_fn_ptr: number
*    pyramid_fn_ptr: number}
* } Demo
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

let is_pressed = false;

let demo = {
  ptr: 0,
  angles_fn_ptr: 0,
  zoom_fn_ptr: 0,
  insert_fn_ptr: 0,
  clear_fn_ptr: 0,
  cube_fn_ptr: 0,
  pyramid_fn_ptr: 0,
}

function getData(c_ptr, len) {
  return new Uint8Array(wasm_memory.buffer, c_ptr, len);
}

function getStr(c_ptr, len) {
  return new TextDecoder().decode(getData(c_ptr, len));
}

function call(ptr, fnPtr) {
  wasm_instance.exports.callPtr(ptr, fnPtr);
}

function setAngles(ptr, fnPtr, angle_x, angle_z) {
  wasm_instance.exports.callSetAnglesPtr(ptr, fnPtr, angle_x, angle_z);
}

function setZoom(ptr, fnPtr, i) {
  wasm_instance.exports.callSetZoomPtr(ptr, fnPtr, i);
}

function insertVector(ptr, fnPtr, x, y, z) {
  wasm_instance.exports.callInsertVector(ptr, fnPtr, x, y, z);
}

function clear(ptr, fnPtr) {
  wasm_instance.exports.callClear(ptr, fnPtr);
}

function insertCube(ptr, fnPtr) {
  wasm_instance.exports.callInsertCube(ptr, fnPtr);
}

function insertPyramid(ptr, fnPtr) {
  wasm_instance.exports.callInsertPyramid(ptr, fnPtr);
}
const up_listener = (_event) => {
  is_pressed = false;
};

const down_listener = (_event) => {
  is_pressed = true;
};

const move_listener = (event) => {
  if (is_pressed) {
    const rect = canvas.getBoundingClientRect();
    const pos = { x: event.clientX - rect.left, y: event.clientY - rect.top };
    const angle_x = (pos.y * 6.283185) / rect.height;
    const angle_z = (pos.x * 6.283185) / rect.width;
    
    setAngles(demo.ptr, demo.angles_fn_ptr, angle_x, angle_z);
  }
};

const wheel_listener = (event) => {
  setZoom(demo.ptr, demo.zoom_fn_ptr, (event.deltaY >> 6) * 0.1);
};

const listeners = [
  (_event) => {
    insertVector(demo.ptr, demo.insert_fn_ptr, input1.value, input2.value, input3.value);
    
    input1.value = "";
    input2.value = "";
    input3.value = "";
  },
  (_event) => {
    clear(demo.ptr, demo.clear_fn_ptr);
  },
  (_event) => {console.log("rotate")}, //rotate
  (_event) => {
    insertCube(demo.ptr, demo.cube_fn_ptr);
  },
  (_event) => {console.log("toggle")},//toggle
  (_event) => {console.log("scale")},//scale
  (_event) => {
    insertPyramid(demo.ptr, demo.pyramid_fn_ptr);
  },
  (_event) => {},
  (_event) => {},
  (_event) => {},,
  (_event) => {},
  (_event) => {},
  (_event) => {},
  (_event) => {},
  (_event) => {},
  (_event) => {},
  (_event) => {},
  (_event) => {},
];

function createButtonGrid() {
  const buttonGrid = document.createElement('div');
  buttonGrid.id = 'button-grid';

  const buttonLabels = [
    'Insert', 'Clear', 'Rotate',
    'Cube', 'Toggle', 'Scale',
    'Pyramid', 'GROUP', 'UNGROUP',
    'Sphere', 'DISTRIBUTE', 'SNAP', 
    'Cone', 'PAN', 'UNDO',
    'REDO', 'SAVE', 'LOAD'
  ];

  buttonLabels.forEach((label, index) => {
    const btn = document.createElement('button');
    btn.textContent = label;
    btn.className = 'floating-button';
    btn.id = `grid-btn-${index + 1}`;
    btn.addEventListener('click', listeners[index]);
    buttonGrid.appendChild(btn);
  });
  
  return buttonGrid;
}

function createToggleGridButton() {
  const toggleBtn = document.createElement('button');
  toggleBtn.id = 'toggle-grid-btn';
  toggleBtn.textContent = 'BUTTONS';
  
  toggleBtn.addEventListener('click', () => {
     const buttonGrid = document.getElementById('button-grid');
     buttonGrid.classList.toggle('hidden');
  });
  
  return toggleBtn;
}

const env = {
  init: function () {
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
    
    body.append(container);
    container.appendChild(canvas);
    container.appendChild(createButtonGrid());
    container.appendChild(createToggleGridButton());
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
      canvas.width = canvas.clientWidth;
      canvas.height = canvas.clientHeight;

      webgl.viewport(0, 0, canvas.width, canvas.height);

      call(ptr, fnPtr);

      setTimeout(() => {
        requestAnimationFrame(frame);
      }, 15);
    }
    requestAnimationFrame(frame);
    throw new Error("Not an error");
  },
  setSceneCallBack: function (
    ptr,
    angles_fn_ptr,
    zoom_fn_ptr,
    insert_fn_ptr,
    clear_fn_ptr,
    cube_fn_ptr,
    pyramid_fn_ptr,
  ) {
    demo.ptr = ptr;
    demo.angles_fn_ptr = angles_fn_ptr;
    demo.zoom_fn_ptr = zoom_fn_ptr;
    demo.insert_fn_ptr = insert_fn_ptr;
    demo.clear_fn_ptr = clear_fn_ptr;
    demo.cube_fn_ptr = cube_fn_ptr;
    demo.pyramid_fn_ptr = pyramid_fn_ptr;
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

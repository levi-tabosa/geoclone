import { createWebGLContext } from "./webgl-utils.js";
import { SceneHandler } from "./scene-handler.js";
import { createUI } from "./ui-components.js";

class WebAssemblyApp {
  constructor(wasmPath) {
    this.wasm_instance = null;
    this.wasm_memory = null;
    this.scene = this.initializeScene();
    this.wasmPath = wasmPath;
    this.canvas = null;
    this.webgl = null;
    this.sceneHandler = null;
    this.resourceManagers = {
      shaders: new Map(),
      programs: new Map(),
      buffers: new Map(),
    };
  }

  initializeScene() {
    return {
      ptr: 0,
      fnPtrs: {
        angles: 0,
        getAx: 0,
        zoom: 0,
        insert: 0,
        clear: 0,
        cube: 0,
        pyramid: 0,
        rotate: 0,
      },
    };
  }

  async init() {
    try {
      const { instance, memory } = await this.loadWebAssembly();
      this.wasm_instance = instance;
      this.wasm_memory = memory;

      this.setupWebGLContext();
      this.sceneHandler = new SceneHandler(this.wasm_instance, this.scene);
      this.setupEventListeners();
      this.createUserInterface();

      this.wasm_instance.exports._start();
    } catch (error) {
      console.error("Initialization failed:", error);
    }
  }

  async loadWebAssembly() {
    const promise = fetch(this.wasmPath);
    const result = await WebAssembly.instantiateStreaming(promise, {
      env: this.createWebAssemblyEnvironment(),
    });
    return result;
  }

  setupWebGLContext() {
    this.canvas = document.createElement("canvas");
    this.canvas.id = "canvas";
    this.webgl = createWebGLContext(this.canvas);
  }

  setupEventListeners() {
    this.canvas.addEventListener("mousedown", this.handleMouseDown.bind(this));
    this.canvas.addEventListener("mouseup", this.handleMouseUp.bind(this));
    this.canvas.addEventListener("mousemove", this.handleMouseMove.bind(this));
    this.canvas.addEventListener("wheel", this.handleWheel.bind(this));

    new ResizeObserver(this.handleResize.bind(this)).observe(this.canvas);
  }

  createUserInterface() {
    const { container, buttons, vectorList } = createUI(
      this.canvas,
      this.sceneHandler.createButtonListeners()
    );
    document.body.appendChild(container);
  }

  createWebAssemblyEnvironment() {
    return {
      _log: this.logMessage.bind(this),
      clear: this.clearColor.bind(this),
      time: this.getCurrentTime.bind(this),
      initShader: this.initializeShader.bind(this),
      // ... other WebAssembly environment methods
    };
  }

  // Delegated methods for WebAssembly environment
  logMessage(ptr, len) {
    console.log(this.decodeString(ptr, len));
  }

  clearColor(r, g, b, a) {
    this.webgl.clearColor(r, g, b, a);
    this.webgl.clear(this.webgl.COLOR_BUFFER_BIT);
  }

  getCurrentTime() {
    return performance.now() / 1000;
  }

  decodeString(ptr, len) {
    return new TextDecoder().decode(
      new Uint8Array(this.wasm_memory.buffer, ptr, len)
    );
  }

  // Event handlers
  handleMouseDown() {
    this.isPressed = true;
  }

  handleMouseUp() {
    this.isPressed = false;
  }

  handleMouseMove(event) {
    if (!this.isPressed) return;

    const rect = this.canvas.getBoundingClientRect();
    const pos = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
    };

    const angleX = (pos.y * Math.PI * 2) / rect.height;
    const angleZ = (pos.x * Math.PI * 2) / rect.width;

    this.wasm_instance.exports.setAngles(
      this.scene.ptr,
      this.scene.fnPtrs.angles,
      angleX,
      angleZ
    );
  }

  handleWheel(event) {
    this.wasm_instance.exports.setZoom(
      this.scene.ptr,
      this.scene.fnPtrs.zoom,
      (event.deltaY >> 6) * 0.1
    );
  }

  handleResize(entries) {
    const { width, height } = entries[0].contentRect;
    this.canvas.width = width;
    this.canvas.height = height;

    const program = this.resourceManagers.programs.get(0);
    if (program) {
      const aspectUniform = this.webgl.getUniformLocation(
        program.gl,
        "aspect_ratio"
      );
      this.webgl.uniform1f(aspectUniform, width / height);
    }
    this.webgl.viewport(0, 0, width, height);
  }
}

export async function initApp(wasmPath) {
  const app = new WebAssemblyApp(wasmPath);
  await app.init();
  return app;
}

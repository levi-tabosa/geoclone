// Constants
const RENDER_CONFIG = {
  ANIMATION_INTERVAL: 30,
  ANIMATION_FRAMES: 25,
  RENDER_FPS: 100,
  ZOOM: {
    MOUSE_SENSITIVITY: 0.1,
    TOUCH_SENSITIVITY: 2000
  }
};

const SCENE_DEFAULTS = {
  FOV: 1.4,
  NEAR: 0.1,
  FAR: 100.0,
  ASPECT_RATIO: 1.0
};

// Core WebGL Resources
class WebGLResources {
  constructor() {
    this.canvas = null;
    this.gl = null;
    this.shaders = new Map();
    this.programs = new Map();
    this.buffers = new Map();
    this.nextShaderId = 0;
    this.nextProgramId = 0;
    this.nextBufferId = 0;
  }

  initialize() {
    this.canvas = document.createElement('canvas');
    this.gl = this.canvas.getContext('webgl');
    if (!this.gl) {
      throw new Error('WebGL not supported');
    }
    return this.canvas;
  }

  createShader(type, source) {
    const shader = this.gl.createShader(type);
    this.gl.shaderSource(shader, `precision mediump float;\n${source}`);
    this.gl.compileShader(shader);

    if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) {
      throw new Error(`Shader compilation failed: ${this.gl.getShaderInfoLog(shader)}`);
    }

    const id = this.nextShaderId++;
    this.shaders.set(id, shader);
    return id;
  }

  createProgram(vertexShaderId, fragmentShaderId) {
    const program = this.gl.createProgram();
    const vertexShader = this.shaders.get(vertexShaderId);
    const fragmentShader = this.shaders.get(fragmentShaderId);

    if (!vertexShader || !fragmentShader) {
      throw new Error('Invalid shader references');
    }

    this.gl.attachShader(program, vertexShader);
    this.gl.attachShader(program, fragmentShader);
    this.gl.linkProgram(program);

    if (!this.gl.getProgramParameter(program, this.gl.LINK_STATUS)) {
      throw new Error(`Program linking failed: ${this.gl.getProgramInfoLog(program)}`);
    }

    const attributes = this.collectProgramAttributes(program);
    const uniforms = this.collectProgramUniforms(program);

    const id = this.nextProgramId++;
    this.programs.set(id, { gl: program, attributes, uniforms });
    return id;
  }

  collectProgramAttributes(program) {
    const attributes = new Map();
    const count = this.gl.getProgramParameter(program, this.gl.ACTIVE_ATTRIBUTES);

    for (let i = 0; i < count; i++) {
      const attribute = this.gl.getActiveAttrib(program, i);
      if (attribute) {
        attributes.set(attribute.name, { index: i, info: attribute });
      }
    }
    return attributes;
  }

  collectProgramUniforms(program) {
    const uniforms = new Map();
    const count = this.gl.getProgramParameter(program, this.gl.ACTIVE_UNIFORMS);

    for (let i = 0; i < count; i++) {
      const uniform = this.gl.getActiveUniform(program, i);
      if (uniform) {
        uniforms.set(uniform.name, uniform);
      }
    }
    return uniforms;
  }
}

// Scene State Management
class SceneState {
  constructor() {
    this.input = {
      isPressed: false,
      lastX: 0,
      lastY: 0,
      initialPinchDistance: -1
    };

    this.camera = {
      fov: SCENE_DEFAULTS.FOV,
      near: SCENE_DEFAULTS.NEAR,
      far: SCENE_DEFAULTS.FAR,
      aspectRatio: SCENE_DEFAULTS.ASPECT_RATIO
    };

    this.objects = {
      vectors: [],
      shapes: [],
      cameras: [],
      selectedVectors: [],
      selectedShapes: [],
      selectedCameras: []
    };

    this.animation = {
      isRotating: false,
      rotationInterval: null
    };
  }
}

// Input Handler
class InputHandler {
  constructor(canvas, sceneController) {
    this.canvas = canvas;
    this.sceneController = sceneController;
    this.setupEventListeners();
  }

  setupEventListeners() {
    this.canvas.addEventListener('mousedown', this.handleMouseDown.bind(this), { passive: true });
    this.canvas.addEventListener('mouseup', this.handleMouseUp.bind(this), { passive: true });
    this.canvas.addEventListener('mousemove', this.handleMouseMove.bind(this), { passive: true });
    this.canvas.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: true });
    this.canvas.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: true });
    this.canvas.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: true });
    this.canvas.addEventListener('wheel', this.handleWheel.bind(this), { passive: true });
  }

  handleMouseDown(event) {
    this.sceneController.state.input.isPressed = true;
  }

  handleMouseUp(event) {
    this.sceneController.state.input.isPressed = false;
  }

  handleMouseMove(event) {
    if (!this.sceneController.state.input.isPressed) return;

    const rect = this.canvas.getBoundingClientRect();
    const pitch = ((event.clientY - rect.top) * Math.PI * 2) / rect.height;
    const yaw = ((event.clientX - rect.left) * Math.PI * 2) / rect.width;

    this.sceneController.setViewAngles(pitch, yaw);
  }

  // Additional touch and wheel handlers...
}

// Scene Controller
class SceneController {
  constructor(wasmInstance, scene) {
    this.resources = new WebGLResources();
    this.state = new SceneState();
    this.wasmInterface = new WasmInterface(wasmInstance, scene);
    this.inputHandler = new InputHandler(this.resources.canvas, this);
  }

  // Scene manipulation methods
  setViewAngles(pitch, yaw) {
    this.wasmInterface.setAngles(pitch, yaw);
  }

  addVector(x, y, z) {
    const [xf, yf, zf] = [parseFloat(x), parseFloat(y), parseFloat(z)];
    if ([xf, yf, zf].some(isNaN)) return;

    this.wasmInterface.insertVector(xf, yf, zf);
    this.state.objects.vectors.push({ x: xf, y: yf, z: zf });
    this.updateUI();
  }

  // Additional methods for manipulating the scene...
}

// Main Application
class WebGLApplication {
  constructor() {
    this.resources = null;
    this.sceneController = null;
  }

  async initialize(wasmPath) {
    const wasmModule = await this.loadWasmModule(wasmPath);
    this.resources = new WebGLResources();
    this.sceneController = new SceneController(wasmModule.instance, {/* scene config */ });

    this.setupUI();
    this.startRenderLoop();
  }

  async loadWasmModule(wasmPath) {
    const response = await fetch(wasmPath);
    return await WebAssembly.instantiateStreaming(response, {
      env: this.createWasmEnvironment()
    });
  }

  createWasmEnvironment() {
    return {
      // WASM environment configuration...
    };
  }

  setupUI() {
    // UI setup code...
  }

  startRenderLoop() {
    const renderFrame = () => {
      // Render logic...
      requestAnimationFrame(renderFrame);
    };
    requestAnimationFrame(renderFrame);
  }
}

export { WebGLApplication };
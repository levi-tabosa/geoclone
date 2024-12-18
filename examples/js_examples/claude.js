class UIManager {
   constructor(sceneHandler) {
     this.sceneHandler = sceneHandler;
     this.canvas = null;
     this.webgl = null;
     this.inputs = [];
     this.buttonGrid = null;
     this.vectorList = null;
   }
 
   initializeUI() {
     this.createCanvas();
     this.createInputs();
     this.createButtonGrid();
     this.createVectorList();
     this.setupEventListeners();
   }
 
   createCanvas() {
     this.canvas = document.createElement('canvas');
     this.canvas.id = 'canvas';
     this.webgl = this.canvas.getContext('webgl');
     
     if (!this.webgl) {
       throw new Error('No WebGL support on browser');
     }
   }
 
   createInputs() {
     this.inputs = ['x', 'y', 'z'].map((axis, index) => {
       const input = document.createElement('input');
       input.id = `input${index + 1}`;
       return input;
     });
   }
 
   createButtonGrid() {
     const buttons = [
       { label: 'Insert', action: this.handleInsert.bind(this) },
       { label: 'Clear', action: this.handleClear.bind(this) },
       { label: 'Rotate', action: this.handleRotate.bind(this) },
       // Outros botões...
     ];
 
     this.buttonGrid = this.createElementWithButtons(buttons, 'button-grid');
   }
 
   createElementWithButtons(buttonConfigs, id) {
     const grid = document.createElement('div');
     grid.id = id;
 
     buttonConfigs.forEach((config, index) => {
       const btn = document.createElement('button');
       btn.textContent = config.label;
       btn.className = 'floating-button';
       btn.id = `grid-btn-${index + 1}`;
       btn.addEventListener('click', config.action);
       grid.appendChild(btn);
     });
 
     return grid;
   }
 
   handleInsert() {
     const [x, y, z] = this.inputs.map(input => input.value);
     this.sceneHandler.addVector(x, y, z);
     this.inputs.forEach(input => input.value = '');
   }
 
   handleClear() {
     this.sceneHandler.clear();
   }
 
   handleRotate() {
     const [x, y, z] = this.inputs.map(input => input.value);
     if (x || y || z) {
       this.sceneHandler.rotate(x, y, z);
     } else {
       this.toggleAutoRotation();
     }
   }
 
   setupEventListeners() {
     const eventHandlers = {
       mousedown: this.handleMouseDown.bind(this),
       mouseup: this.handleMouseUp.bind(this),
       mousemove: this.handleMouseMove.bind(this),
       wheel: this.handleWheel.bind(this)
     };
 
     Object.entries(eventHandlers).forEach(([event, handler]) => {
       this.canvas.addEventListener(event, handler);
     });
 
     new ResizeObserver(this.handleResize.bind(this)).observe(this.canvas);
   }
 
   // Implementar métodos de manipulação de eventos...
 }
 
 class SceneManager {
   constructor(wasmInstance) {
     this.wasmInstance = wasmInstance;
     this.scene = {
       ptr: 0,
       // outros ponteiros...
     };
   }
 
   setSceneCallbacks(callbackPointers) {
     Object.assign(this.scene, callbackPointers);
   }
 
   // Métodos de gerenciamento de cena...
 }
 
 export async function initializeApplication(wasmPath) {
   try {
     const wasmModule = await WebAssembly.instantiateStreaming(
       fetch(wasmPath), 
       { env: createEnvironmentBindings() }
     );
 
     const sceneManager = new SceneManager(wasmModule.instance);
     const uiManager = new UIManager(sceneManager);
     
     uiManager.initializeUI();
     wasmModule.instance.exports._start();
   } catch (error) {
     console.error('Initialization failed:', error);
   }
 }
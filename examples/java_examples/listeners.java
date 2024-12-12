import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.ComponentEvent;
import java.awt.event.ComponentAdapter;
import java.awt.event.MouseEvent;
import java.awt.event.MouseMotionAdapter;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.Vector;
import javax.swing.Timer;
import javax.swing.event.ListSelectionListener;

/**
 * This class manages all the listeners for the application, including:
 * <ul>
 *     <li>Canvas resizing listener</li>
 *     <li>Mouse motion listener for camera rotation</li>
 *     <li>Mouse wheel listener for zooming</li>
 *     <li>Button listeners for various transformations and object creation</li>
 *     <li>List selection listener for selecting vectors and shapes</li>
 * </ul>
 * It also contains helper methods for:
 * <ul>
 *     <li>Initializing the canvas</li>
 *     <li>Validating user input</li>
 *     <li>Applying transformations to vectors and shapes</li>
 *     <li>Updating the display of vectors and shapes in the GUI</li>
 * </ul>
 * 
 * The transformation methods (translation, scaling, rotation, reflection, shearing)
 * are implemented with animation. The animation is achieved using a Swing Timer
 * that updates the transformation parameters incrementally over a certain number
 * of frames. This creates a smooth visual effect for the transformations.
 */
@SuppressWarnings("unchecked")
class Listeners {
   // Constants for animation frames, interval, and FPS
   private static final int FRAMES = 25, INTERVAL = 30, FPS = 200;

   // Static reference to the singleton instance of the Demo canvas
   private static final Demo CANVAS = Demo.getInstance();

   /**
    * Initializes the canvas with listeners for resizing, mouse motion, and mouse wheel events.
    * Also starts a timer for repainting the canvas at a fixed rate.
    * 
    * @return The initialized Demo canvas instance.
    */
   protected static Demo initializeCanvas() {
      // Component listener for canvas resizing
      CANVAS.addComponentListener(new ComponentAdapter() {
         @Override
         public void componentResized(ComponentEvent e) {
            // Update canvas dimensions when resized
            CANVAS.updateSizeFields();
         }
      });

      // Mouse motion listener for camera rotation
      CANVAS.addMouseMotionListener(new MouseMotionAdapter() {
         @Override
         public void mouseDragged(MouseEvent e) {
            // Convert screen coordinates to camera angles and update the view
            CANVAS.screenPositionToAngles(e.getX(), e.getY());
         }
      });

      // Mouse wheel listener for zooming
      CANVAS.addMouseWheelListener(e -> CANVAS.incrementI(e.getWheelRotation() << 2));

      // Timer for repainting the canvas at a fixed rate
      new Timer(1000 / FPS, e -> CANVAS.repaint()).start();
      return CANVAS;
   }

   /**
    * Creates an action listener for the "Toggle Mode" button.
    * This listener switches between displaying vectors and shapes on the canvas.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createToggleShapesListener() {
      return new ActionListener() {
         // Flag to track whether vectors are currently visible
         private boolean isVectorsVisible = true;
         
         // Backup arrays to store vectors and shapes when switching modes
         private Object[] vectorsBackup;
         private Object[][] shapesBackup;

         @Override
         public void actionPerformed(ActionEvent e) {
            // Toggle between vectors and shapes
            if (isVectorsVisible) {
               // Store shapes in a backup array and display vectors
               shapesBackup = CANVAS._shapes;
               CANVAS.setVectors((V3[]) vectorsBackup);
               vectorsBackup = null;
               CANVAS.setShapes(null);
               CANVAS.updateVectors();
               Window.appendVectors();
            } else {
               // Store vectors in a backup array and display shapes
               vectorsBackup = CANVAS._vectors;
               CANVAS._shapes = (V3[][]) shapesBackup;
               shapesBackup = null;
               CANVAS.setVectors(null);
               CANVAS.updateShapes();
               Window.appendShapes();
            }
            // Toggle the visibility flag
            isVectorsVisible = !isVectorsVisible;
         }
      };
   }

   /**
    * Creates a list selection listener for the JList in the GUI.
    * This listener updates the canvas to display the selected vectors or shape.
    * 
    * @return The created ListSelectionListener object.
    */
   @SuppressWarnings("rawtypes")
   protected static ListSelectionListener createListSelectionListener() {
      return e -> {
         if (!e.getValueIsAdjusting()) {
            // Create a vector to store the selected elements from the list
            Vector selected = new Vector<>();
            Window.list.getSelectedValuesList().forEach(selected::add);

            // Check if the selected elements are V3 vectors or V3[][] shapes
            if (!selected.isEmpty() && selected.firstElement() instanceof V3) {
               // Display the selected vectors on the canvas
               CANVAS.setVectors((V3[]) selected.toArray(new V3[0]));
            } else {
               // Display the selected shape on the canvas
               CANVAS.setShapes((V3[][]) selected.toArray(new V3[0][]));
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Insert" button.
    * This listener reads the x, y, and z coordinates from the input fields,
    * creates a new V3 vector, and adds it to the list of vectors.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createInsertVectorListener() {
      return e -> {
         // Get the x, y, and z coordinate strings from the input fields
         String x = Window._x.getText(), y = Window._y.getText(), z = Window._z.getText();

         // Validate the input strings
         if (validateInput(x) && validateInput(y) && validateInput(z)) {
            // Create a new V3 vector from the validated coordinates
            Window.vectors.add(new V3(Double.parseDouble(x), Double.parseDouble(y), Double.parseDouble(z)));
            // Update the JList with the new vector
            Window.appendVectors();
            
            // Clear the input fields
            Window._x.setText("");
            Window._y.setText("");
            Window._z.setText("");
            return;
         }

         try (BufferedReader br = new BufferedReader(new FileReader("test.txt"))) {
            // test for tsa method
            String line;
            while ((line = br.readLine()) != null) {
               String[] parts = line.split(" ");
               Window.vectors.add(
                     new V3(Double.parseDouble(parts[0]), Double.parseDouble(parts[1]), Double.parseDouble(parts[2])));
               Window.appendVectors();
            }
         } catch (IOException q) {
            q.printStackTrace();
         }
      };
   }

   /**
    * Creates an action listener for the "Translate" button.
    * This listener reads the x, y, and z translation values from the input fields and applies
    * a translation transformation to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createTranslateListener() {
      return e -> {
         // Get the x, y, and z translation values from the input fields
         String x = Window._x.getText(), y = Window._y.getText(), z = Window._z.getText();
         double dx = validateInput(x) ? Double.parseDouble(x) : 0;
         double dy = validateInput(y) ? Double.parseDouble(y) : 0;
         double dz = validateInput(z) ? Double.parseDouble(z) : 0;

         // Apply translations to vectors or shapes
         if (CANVAS._vectors != null) {
            applyTranslations(CANVAS._vectors, dx, dy, dz);
         }
         if (CANVAS._shapes != null) {
            for (V3[] shape : CANVAS._shapes) {
               applyTranslations(shape, dx, dy, dz);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Scale" button.
    * This listener reads the scaling factor from the x input field and applies
    * a scaling transformation to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createScaleListener() {
      return e -> {
         // Get the scaling factor from the x input field
         String input = Window._x.getText();
         if (!validateInput(input)) {
            return;
         }
         double f = Double.parseDouble(input);

         // Apply scaling to vectors or shapes
         if (CANVAS._vectors != null) {
            applyScales(CANVAS._vectors, f);
         } else if (CANVAS._shapes != null) {
            for (V3[] aux : CANVAS._shapes) {
               applyScales(aux, f);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Projection XY" button.
    * This listener applies an XY projection transformation to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createProjXYListener() {
      return e -> {
         // Apply XY projection to vectors or shapes
         if (CANVAS._vectors != null) {
            applyProjections(CANVAS._vectors, Utils.projXY);
         } else if (CANVAS._shapes != null) {
            for (V3[] aux : CANVAS._shapes) {
               applyProjections(aux, Utils.projXY);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Projection XZ" button.
    * This listener applies an XZ projection transformation to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createProjXZListener() {
      return e -> {
         // Apply XZ projection to vectors or shapes
         if (CANVAS._vectors != null) {
            applyProjections(CANVAS._vectors, Utils.projXZ);
         } else if (CANVAS._shapes != null) {
            for (V3[] aux : CANVAS._shapes) {
               applyProjections(aux, Utils.projXZ);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Projection YZ" button.
    * This listener applies a YZ projection transformation to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createProjYZListener() {
      return e -> {
         // Apply YZ projection to vectors or shapes
         if (CANVAS._vectors != null) {
            applyProjections(CANVAS._vectors, Utils.projYZ);
         } else if (CANVAS._shapes != null) {
            for (V3[] aux : CANVAS._shapes) {
               applyProjections(aux, Utils.projYZ);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Reflection X" button.
    * This listener applies a reflection transformation across the X-axis to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createRefXListener() {
      return e -> {
         // Apply reflection across X-axis to vectors or shapes
         if (CANVAS._vectors != null) {
            applyReflections(CANVAS._vectors, Utils.refX);
         } else if (CANVAS._shapes != null) {
            for (V3[] aux : CANVAS._shapes) {
               applyReflections(aux, Utils.refX);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Reflection Y" button.
    * This listener applies a reflection transformation across the Y-axis to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createRefYListener() {
      return e -> {
         // Apply reflection across Y-axis to vectors or shapes
         if (CANVAS._vectors != null) {
            applyReflections(CANVAS._vectors, Utils.refY);
         } else if (CANVAS._shapes != null) {
            for (V3[] aux : CANVAS._shapes) {
               applyReflections(aux, Utils.refY);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Reflection Z" button.
    * This listener applies a reflection transformation across the Z-axis to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createRefZListener() {
      return e -> {
         // Apply reflection across Z-axis to vectors or shapes
         if (CANVAS._vectors != null) {
            applyReflections(CANVAS._vectors, Utils.refZ);
         } else if (CANVAS._shapes != null) {
            for (V3[] aux : CANVAS._shapes) {
               applyReflections(aux, Utils.refZ);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Rotate" button.
    * This listener reads the rotation angles around the X, Y, and Z axes from the input fields
    * and applies a rotation transformation to the selected vectors or shapes. 
    * If the input fields are empty, it starts an idle animation that rotates the canvas continuously.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createRotateListener() {
      return new ActionListener() {
         // Flag to track whether the idle animation is running
         boolean flag = true;
         
         // Timer for the idle animation
         Timer idle = new Timer(INTERVAL, new ActionListener() {
            int curr = 0;

            @Override
            public void actionPerformed(ActionEvent e) {
               // Rotate the canvas around the Z-axis
               CANVAS.setAngleZ(curr++ * 0.04);
               CANVAS.updateVectors();
               CANVAS.updateShapes();
               CANVAS.updateGridLines();
            }
         });

         @Override
         public void actionPerformed(ActionEvent e) {
            // Get the rotation angles from the input fields
            String x = Window._x.getText(), y = Window._y.getText(), z = Window._z.getText();
            double angleX = validateInput(x) ? Math.toRadians(Double.parseDouble(x)) : 0;
            double angleY = validateInput(y) ? Math.toRadians(Double.parseDouble(y)) : 0;
            double angleZ = validateInput(z) ? Math.toRadians(Double.parseDouble(z)) : 0;

            // Check if the angles are all zero (idle animation)
            if (angleX == angleY && angleY == angleZ && angleZ == 0) {
               if (flag) {
                  // Start the idle animation
                  idle.start();
               } else {
                  // Stop the idle animation
                  idle.stop();
               }
               // Toggle the animation flag
               flag = !flag;
            } else if (CANVAS._vectors != null) {
               // Apply rotations to vectors
               applyRotations(CANVAS._vectors, angleX, angleY, angleZ);
            } else if (CANVAS._shapes != null) {
               // Apply rotations to shapes
               for (V3[] aux : CANVAS._shapes) {
                  applyRotations(aux, angleX, angleY, angleZ);
               }
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Shear (X)" button.
    * This listener reads the shearing factors along the Z and Y axes from the input fields
    * and applies a shearing transformation along the X-axis to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createShearOnXListener() {
      return e -> {
         // Get the shearing factors from the z and y input fields
         String z = Window._z.getText(), y = Window._y.getText();
         double factorZ = validateInput(z) ? Double.parseDouble(z) : 0;
         double factorY = validateInput(y) ? Double.parseDouble(y) : 0;

         // Apply shearing along X-axis to vectors or shapes
         if (CANVAS._vectors != null) {
            V3[] aux = CANVAS._vectors;
            applyShears(aux, Utils.shearOnX, factorY, factorZ);
         } else {
            for (V3[] aux : CANVAS._shapes) {
               applyShears(aux, Utils.shearOnX, factorY, factorZ);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Shear (Y)" button.
    * This listener reads the shearing factors along the X and Z axes from the input fields
    * and applies a shearing transformation along the Y-axis to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createShearOnYListener() {
      return e -> {
         // Get the shearing factors from the x and z input fields
         String x = Window._x.getText(), z = Window._z.getText();
         double factorX = validateInput(x) ? Double.parseDouble(x) : 0;
         double factorZ = validateInput(z) ? Double.parseDouble(z) : 0;

         // Apply shearing along Y-axis to vectors or shapes
         if (CANVAS._vectors != null) {
            V3[] aux = CANVAS._vectors;
            applyShears(aux, Utils.shearOnY, factorX, factorZ);
         } else {
            for (V3[] aux : CANVAS._shapes) {
               applyShears(aux, Utils.shearOnY, factorX, factorZ);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Shear (Z)" button.
    * This listener reads the shearing factors along the X and Y axes from the input fields
    * and applies a shearing transformation along the Z-axis to the selected vectors or shapes.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createShearOnZListener() {
      return e -> {
         // Get the shearing factors from the x and y input fields
         String x = Window._x.getText(), y = Window._y.getText();
         double factorX = validateInput(x) ? Double.parseDouble(x) : 0;
         double factorY = validateInput(y) ? Double.parseDouble(y) : 0;

         // Apply shearing along Z-axis to vectors or shapes
         if (CANVAS._vectors != null) {
            V3[] aux = CANVAS._vectors;
            applyShears(aux, Utils.shearOnZ, factorX, factorY);
         } else {
            for (V3[] aux : CANVAS._shapes) {
               applyShears(aux, Utils.shearOnZ, factorX, factorY);
            }
         }
      };
   }

   /**
    * Creates an action listener for the "Sphere" button.
    * This listener adds a sphere shape to the list of shapes and updates the GUI.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createSphereListener() {
      return e -> {
         // Add a sphere shape to the list of shapes
         Window.shapes.add(Shape.SPHERE.getVectors());
         // Update the JList with the new sphere shape
         Window.appendShapes();
      };
   }

   /**
    * Creates an action listener for the "Cube" button.
    * This listener adds a cube shape to the list of shapes and updates the GUI.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createCubeListener() {
      return e -> {
         // Add a cube shape to the list of shapes
         Window.shapes.add(Shape.CUBE.getVectors());
         // Update the JList with the new cube shape
         Window.appendShapes();
      };
   }

   /**
    * Creates an action listener for the "Pyramid" button.
    * This listener adds a pyramid shape to the list of shapes and updates the GUI.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createPyramidListener() {
      return e -> {
         // Add a pyramid shape to the list of shapes
         Window.shapes.add(Shape.PYRAMID.getVectors());
         // Update the JList with the new pyramid shape
         Window.appendShapes();
      };
   }

   /**
    * Creates an action listener for the "TSA" button.
    * This listener implements the Travelling Salesman Algorithm (TSA)
    * to find the shortest path that visits all the selected vectors.
    * 
    * @return The created ActionListener object.
    */
   protected static ActionListener createTravellingSalesmanListener() {
      return new ActionListener() {
         /**
          * Calculates the total distance of a path represented by a sequence of indexes
          * based on a distance matrix.
          * 
          * @param indexes The sequence of indexes representing the path.
          * @param distances The distance matrix where distances[i][j] is the distance between
          *                  the i-th and j-th vectors.
          * @return The total distance of the path.
          */
         double totalDistance(int[] indexes, double[][] distances) {
            double total = 0;

            // Iterate over the indexes and sum the distances between consecutive vectors
            for (int i = 0; i < distances.length - 1; i++) {
               total += distances[indexes[i]][indexes[i + 1]];
            }
            // Add the distance from the last vector back to the first vector
            total += distances[indexes[distances[0].length - 1]][0];
            return total;
         }

         /**
          * Generates all permutations of a given array of integers.
          * 
          * @param elements The array of integers to permute.
          * @return A 2D array where each row represents a permutation of the input array.
          */
         int[][] permut(int[] elements) {
            int n = elements.length, fat = 1, i = 0, count = 0;
            int[] indexes = new int[n];

            // Calculate the factorial of n
            for (int j = n; j > 1; j--) {
               fat *= j;
            }

            // Create a 2D array to store the permutations
            int[][] permutations = new int[fat][n];
            permutations[count++] = elements;

            // Generate the permutations
            while (i < n) {
               if (indexes[i] < i) {
                  // Swap elements and generate a new permutation
                  swap(elements, i % 2 == 0 ? 0 : indexes[i], i);
                  permutations[count++] = elements;
                  indexes[i]++;
                  i = 0;
               } else {
                  indexes[i++] = 0;
               }
            }
            // Return the array of permutations
            return permutations;
         }

         /**
          * Swaps two elements in an array of integers.
          * 
          * @param elements The array of integers.
          * @param a The index of the first element to swap.
          * @param b The index of the second element to swap.
          */
         void swap(int[] elements, int a, int b) {
            int temp = elements[a];
            elements[a] = elements[b];
            elements[b] = temp;
         }

         @Override
         public void actionPerformed(ActionEvent e) {
            // Check if there are any vectors selected
            if (CANVAS._vectors == null) {
               return;
            }
            // Get the number of vectors
            int n = CANVAS._vectors.length;
            // Create a distance matrix to store the distances between vectors
            double[][] distances = new double[n][n];

            // Calculate the distances between all pairs of vectors
            for (int i = 0; i < n; i++) {
               for (int j = 1; j < n; j++) {
                  distances[i][j] = Math.sqrt(
                        Math.pow((CANVAS._vectors[j].x - CANVAS._vectors[i].x), 2) +
                              Math.pow((CANVAS._vectors[j].y - CANVAS._vectors[i].y), 2) +
                              Math.pow((CANVAS._vectors[j].z - CANVAS._vectors[i].z), 2));
               }
            }

            // Initialize the shortest path and its length
            int[] shortestPath = new int[n];
            for (int i = 0; i < n; i++) {
               shortestPath[i] = i;
            }
            double shortestLength = Double.MAX_VALUE;

            // Iterate over all permutations of the vectors
            for (int[] permutation : permut(shortestPath)) {
               // Calculate the total distance of the current permutation
               double distance = totalDistance(permutation, distances);
               // Update the shortest path if the current permutation is shorter
               if (shortestLength > distance) {
                  shortestLength = distance;
                  shortestPath = permutation;
               }
            }

            // Update the shapes array with the shortest path
            CANVAS._shapes = new V3[1][n];
            for (int i = 0; i < n; i++) {
               CANVAS._shapes[0][i] = CANVAS._vectors[shortestPath[i]];
            }
            // Update the canvas to display the shortest path
            CANVAS.updateShapes();
         }
      };
   }

   /**
    * Applies a translation transformation to an array of vectors with animation.
    * 
    * @param vectors The array of vectors to translate.
    * @param dx The translation along the X-axis.
    * @param dy The translation along the Y-axis.
    * @param dz The translation along the Z-axis.
    */
   private static void applyTranslations(V3[] vectors, double dx, double dy, double dz) {
      // Create a copy of the vectors to preserve the originals during animation
      V3[] copy = copyVectors(vectors);
      // Create a timer to animate the translation over a certain number of frames
      new Timer(INTERVAL, new ActionListener() {
         int curr = 0;

         @Override
         public void actionPerformed(ActionEvent e) {
            // Apply the translation incrementally for each frame
            applyTranslation(vectors, copy, dx / FRAMES * curr, dy / FRAMES * curr, dz / FRAMES * curr);
            // Stop the timer when all frames are completed
            if (curr == FRAMES) {
               ((Timer) e.getSource()).stop();
               // Update the vectors in the GUI if the translated vectors are the main vectors
               if (vectors == CANVAS._vectors)
                  updateWindowVectors(vectors);
            } else {
               curr++;
            }
         }
      }).start();
   }

   /**
    * Applies a translation transformation to an array of vectors for a single frame.
    * 
    * @param vectors The array of vectors to translate.
    * @param copy The copy of the original vectors.
    * @param dx The translation along the X-axis for the current frame.
    * @param dy The translation along the Y-axis for the current frame.
    * @param dz The translation along the Z-axis for the current frame.
    */
   private static void applyTranslation(V3[] vectors, V3[] copy, double dx, double dy, double dz) {
      // Apply the translation to each vector
      for (int i = 0; i < copy.length; i++) {
         vectors[i].x = copy[i].x + dx;
         vectors[i].y = copy[i].y + dy;
         vectors[i].z = copy[i].z + dz;
      }
      // Update the canvas to reflect the translated vectors
      if (vectors == CANVAS._vectors) {
         CANVAS.updateVectors();
      } else {
         CANVAS.updateShapes();
      }
   }

   /**
    * Applies a scaling transformation to an array of vectors with animation.
    * 
    * @param vectors The array of vectors to scale.
    * @param f The scaling factor.
    */
   private static void applyScales(V3[] vectors, double f) {
      // Create a copy of the vectors to preserve the originals during animation
      V3[] copy = copyVectors(vectors);
      // Create a timer to animate the scaling over a certain number of frames
      new Timer(INTERVAL, new ActionListener() {
         int curr = 0;

         @Override
         public void actionPerformed(ActionEvent e) {
            // Apply the scaling incrementally for each frame
            applyScale(vectors, copy, f, curr);
            // Stop the timer when all frames are completed
            if (curr == FRAMES) {
               ((Timer) e.getSource()).stop();
               // Update the vectors in the GUI if the scaled vectors are the main vectors
               if (vectors == CANVAS._vectors)
                  updateWindowVectors(vectors);
            } else {
               curr++;
            }
         }
      }).start();
   }

   /**
    * Applies a scaling transformation to an array of vectors for a single frame.
    * 
    * @param vectors The array of vectors to scale.
    * @param original The copy of the original vectors.
    * @param factor The scaling factor.
    * @param frame The current frame number.
    */
   private static void applyScale(V3[] vectors, V3[] original, double factor, int frame) {
      // Apply the scaling to each vector
      for (int i = 0; i < vectors.length; i++) {
         V3 scaled = Utils.scale.apply(original[i], factor);
         vectors[i].x = original[i].x + (scaled.x - original[i].x) / FRAMES * frame;
         vectors[i].y = original[i].y + (scaled.y - original[i].y) / FRAMES * frame;
         vectors[i].z = original[i].z + (scaled.z - original[i].z) / FRAMES * frame;
      }
      // Update the canvas to reflect the scaled vectors
      if (vectors == CANVAS._vectors) {
         CANVAS.updateVectors();
      } else {
         CANVAS.updateShapes();
      }
   }

   /**
    * Applies a projection transformation to an array of vectors with animation.
    * 
    * @param vectors The array of vectors to project.
    * @param transform The projection transformation function to apply.
    */
   private static void applyProjections(V3[] vectors, TransformFunction transform) {
      // Create a copy of the vectors to preserve the originals during animation
      V3[] copy = copyVectors(vectors);
      // Create a timer to animate the projection over a certain number of frames
      new Timer(INTERVAL, new ActionListener() {
         double curr = 0;

         @Override
         public void actionPerformed(ActionEvent e) {
            // Apply the projection incrementally for each frame
            applyProjection(vectors, copy, transform, 1 - curr / FRAMES);
            // Stop the timer when all frames are completed
            if (curr == FRAMES) {
               ((Timer) e.getSource()).stop();
               // Update the vectors in the GUI if the projected vectors are the main vectors
               if (vectors == CANVAS._vectors)
                  updateWindowVectors(vectors);
            } else {
               curr++;
            }
         }
      }).start();
   }

   /**
    * Applies a projection transformation to an array of vectors for a single frame.
    * 
    * @param vectors The array of vectors to project.
    * @param copy The copy of the original vectors.
    * @param transform The projection transformation function to apply.
    * @param f The interpolation factor for the current frame.
    */
   private static void applyProjection(V3[] vectors, V3[] copy, TransformFunction transform, double f) {
      // Apply the projection to each vector
      for (int i = 0; i < copy.length; i++) {
         vectors[i] = transform.apply(copy[i], f);
      }
      // Update the canvas to reflect the projected vectors
      if (vectors == CANVAS._vectors) {
         CANVAS.updateVectors();
      } else {
         CANVAS.updateShapes();
      }
   }

   /**
    * Applies a reflection transformation to an array of vectors with animation.
    * 
    * @param vectors The array of vectors to reflect.
    * @param transform The reflection transformation function to apply.
    */
   private static void applyReflections(V3[] vectors, TransformFunction transform) {
      // Create a copy of the vectors to preserve the originals during animation
      V3[] copy = copyVectors(vectors);
      // Create a timer to animate the reflection over a certain number of frames
      new Timer(INTERVAL, new ActionListener() {
         double curr = 0;

         @Override
         public void actionPerformed(ActionEvent e) {
            // Apply the reflection incrementally for each frame
            applyReflection(vectors, copy, transform, 1 - curr / FRAMES);
            // Stop the timer when all frames are completed
            if (curr == FRAMES << 1) {
               ((Timer) e.getSource()).stop();
               // Update the vectors in the GUI if the reflected vectors are the main vectors
               if (vectors == CANVAS._vectors)
                  updateWindowVectors(vectors);
            } else {
               curr += 2;
            }
         }
      }).start();
   }

   /**
    * Applies a reflection transformation to an array of vectors for a single frame.
    * 
    * @param vectors The array of vectors to reflect.
    * @param copy The copy of the original vectors.
    * @param transform The reflection transformation function to apply.
    * @param f The interpolation factor for the current frame.
    */
   private static void applyReflection(V3[] vectors, V3[] copy, TransformFunction transform, double f) {
      // Apply the reflection to each vector
      for (int i = 0; i < copy.length; i++) {
         vectors[i] = transform.apply(copy[i], f);
      }
      // Update the canvas to reflect the reflected vectors
      if (vectors == CANVAS._vectors) {
         CANVAS.updateVectors();
      } else {
         CANVAS.updateShapes();
      }
   }

   /**
    * Applies a rotation transformation to an array of vectors with animation.
    * 
    * @param vectors The array of vectors to rotate.
    * @param ax The rotation angle around the X-axis.
    * @param ay The rotation angle around the Y-axis.
    * @param az The rotation angle around the Z-axis.
    */
   private static void applyRotations(V3[] vectors, double ax, double ay, double az) {
      // Create a copy of the vectors to preserve the originals during
      V3[] copy = copyVectors(vectors);
      // Create a timer to animate the rotation over a certain number of frames
      new Timer(INTERVAL, new ActionListener() {
         int curr = 0;

         @Override
         public void actionPerformed(ActionEvent e) {
            // Apply rotations sequentially for each axis
            if (curr <= FRAMES) {
               if (ax == 0) {
                  curr += FRAMES;
               } else
                  applyRotation(vectors, copy, Utils.rotX, ax / FRAMES * curr);
            } else if (curr <= FRAMES << 1) {
               if (ay == 0) {
                  curr += FRAMES;
               } else
                  applyRotation(vectors, copy, Utils.rotY, ay / FRAMES * (curr - FRAMES));
            } else {
               if (az == 0) {
                  curr += FRAMES;
               } else
                  applyRotation(vectors, copy, Utils.rotZ, az / FRAMES * (curr - (FRAMES << 1)));
            }
            // Stop the timer when all frames are completed
            if (curr == FRAMES * 3) {
               ((Timer) e.getSource()).stop();
               // Update the vectors in the GUI if the rotated vectors are the main vectors
               if (vectors == CANVAS._vectors)
                  updateWindowVectors(vectors);

            } else {
               curr++;
            }
         }
      }).start();
   }

   /**
    * Applies a rotation transformation to an array of vectors for a single frame.
    * 
    * @param vectors The array of vectors to rotate.
    * @param original The copy of the original vectors.
    * @param rotation The rotation transformation function to apply.
    * @param angle The rotation angle for the current frame.
    */
   private static void applyRotation(V3[] vectors, V3[] original, TransformFunction rotation, double angle) {
      // Apply the rotation to each vector
      for (int i = 0; i < vectors.length; i++) {
         vectors[i] = rotation.apply(original[i], angle);
      }
      // Update the canvas to reflect the rotated vectors
      if (vectors == CANVAS._vectors) {
         CANVAS.updateVectors();
      } else {
         CANVAS.updateShapes();
      }
   }

   /**
    * Applies a shearing transformation to an array of vectors with animation.
    * 
    * @param vectors The array of vectors to shear.
    * @param transform The shearing transformation function to apply.
    * @param s The shearing factor along the first axis.
    * @param t The shearing factor along the second axis.
    */
   private static void applyShears(V3[] vectors, TransformFunction transform, double s, double t) {
      // Create a copy of the vectors to preserve the originals during animation
      V3[] copy = copyVectors(vectors);
      // Create a timer to animate the shearing over a certain number of frames
      new Timer(INTERVAL, new ActionListener() {
         int curr = 0;

         @Override
         public void actionPerformed(ActionEvent e) {
            // Apply the shearing incrementally for each frame
            applyShear(vectors, copy, transform, s / FRAMES * curr, t / FRAMES * curr);
            // Stop the timer when all frames are completed
            if (curr == FRAMES) {
               ((Timer) e.getSource()).stop();
               // Update the vectors in the GUI if the sheared vectors are the main vectors
               if (vectors == CANVAS._vectors)
                  updateWindowVectors(vectors);
            } else {
               curr++;
            }
         }
      }).start();
   }

   /**
    * Applies a shearing transformation to an array of vectors for a single frame.
    * 
    * @param vectors The array of vectors to shear.
    * @param original The copy of the original vectors.
    * @param transform The shearing transformation function to apply.
    * @param s The shearing factor along the first axis for the current frame.
    * @param t The shearing factor along the second axis for the current frame.
    */
   private static void applyShear(V3[] vectors, V3[] original, TransformFunction transform, double s, double t) {
      // Apply the shearing to each vector
      for (int i = 0; i < vectors.length; i++) {
         vectors[i] = transform.apply(original[i], s, t);
      }
      // Update the canvas to reflect the sheared vectors
      if (vectors == CANVAS._vectors) {
         CANVAS.updateVectors();
      } else {
         CANVAS.updateShapes();
      }
   }

   /**
    * Validates a string to check if it represents a valid numerical input.
    * 
    * @param in The string to validate.
    * @return True if the string is a valid number, false otherwise.
    */
   private static boolean validateInput(String in) {
      if (in.isEmpty()) {
         return false;
      }
      boolean hasDecimalPoint = false;
      char[] c = in.toCharArray();
      // Check if the string contains only valid numeric characters: digits, '-', '.'
      for (int i = 0; i < c.length - 1; i++) {
         if ((c[i] == '-' && i != 0) && c[i] != '.' && c[i] < 48 || c[i] > 57) {
            return false;
         }
         if (c[i] == '.') {
            // Check if there is more than one decimal point
            if (hasDecimalPoint) {
               return false;
            }
            hasDecimalPoint = true;
         }
      }
      // Check if the last character is a digit
      return c[c.length - 1] > 47 && c[c.length - 1] < 58;
   }

   /**
    * Updates the vectors displayed in the GUI list based on the modified vectors.
    * 
    * @param vectors The modified array of vectors.
    */
   private static void updateWindowVectors(V3[] vectors) {
      if (!Window.vectors.isEmpty()) {
         int[] selectedIndices = Window.list.getSelectedIndices();
         // Update the selected vectors in the GUI list
         for (int i = 0; i < selectedIndices.length; i++) {
            Window.vectors.set(selectedIndices[i], vectors[i]);
         }
         // Refresh the GUI list to reflect the changes
         Window.appendVectors();
         Window.list.setSelectedIndices(selectedIndices);
      }
   }

   /**
    * Creates a copy of an array of vectors.
    * 
    * @param vectors The array of vectors to copy.
    * @return The copied array of vectors.
    */
   private static V3[] copyVectors(V3[] vectors) {
      V3[] copy = new V3[vectors.length];
      // Copy each vector to the new array
      for (int i = 0; i < vectors.length; i++) {
         copy[i] = new V3(vectors[i].x, vectors[i].y, vectors[i].z);
      }
      return copy;
   }
}
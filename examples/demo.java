import java.awt.Color;
import java.awt.Graphics;
import java.awt.Image;
import javax.swing.JComponent;
/**
 * This class represents the canvas where 3D objects and vectors are drawn.
 * It handles the rendering of 3D objects using perspective projection.
 * It also manages camera angles, zooming, and double buffering for smooth animation.
 */
class Demo extends JComponent {
    // Fields for canvas size, zoom level, grid resolution, and perspective projection
    private int _i = 80, _H = 1, _W = 1, gridRes = 100; 
    private final double far = gridRes << 1, near = gridRes >> 1; 

    // Arrays to store 3D vectors for objects, lines, and grid lines
    public V3[] _vectors, vectors; // Original and rotated vectors
    private V3[] _gridLines = new V3[gridRes << 2], gridLines = new V3[gridRes << 2]; // Original and rotated grid lines
    private V3[] _lines, lines; // Original and rotated axis lines
    public V3[][] _shapes, shapes; // Original and rotated shapes

    // Camera angles for rotation
    private double angleZ = 0, angleX = 0;

    // Singleton instance of Demo
    private static Demo instance; 

    // Graphics and image for double buffering
    private Graphics graphics; 
    private Image image;       

    /**
     * Returns the singleton instance of Demo.
     * 
     * @return The singleton instance of Demo.
     */
    public static Demo getInstance() {
        // If instance is null, create a new Demo object
        return instance != null ? instance : new Demo();
    }

    /**
     * Private constructor for singleton pattern.
     * Initializes grid lines and axis lines.
     */
    private Demo() {
        super();
        int j = gridRes >> 1;

        // Initialize grid lines
        for (int i = -j; (gridRes & 1) == 1 ? i <= j : i < j; i++) { 
            gridLines[i + j << 2] = new V3(i, j, 0);
            gridLines[(i + j << 2) + 1] = new V3(i, -j, 0);
            gridLines[(i + j << 2) + 2] = new V3(j, i, 0);
            gridLines[(i + j << 2) + 3] = new V3(-j, i, 0);
            _gridLines[i + j << 2] = new V3(i, j, 0);
            _gridLines[(i + j << 2) + 1] = new V3(i, -j, 0);
            _gridLines[(i + j << 2) + 2] = new V3(j, i, 0);
            _gridLines[(i + j << 2) + 3] = new V3(-j, i, 0);
        }
        
        // Initialize axis lines
        lines = new V3[] {
                new V3(j, 0, 0), new V3(-j, 0, 0), new V3(0, j, 0),
                new V3(0, -j, 0), new V3(0, 0, j), new V3(0, 0, -j)
        };
        _lines = new V3[] {
                new V3(j, 0, 0), new V3(-j, 0, 0), new V3(0, j, 0),
                new V3(0, -j, 0), new V3(0, 0, j), new V3(0, 0, -j)
        };
    }

    /**
     * Draws the entire frame, including lines, shapes, and vectors.
     * 
     * @param g The Graphics object to draw on.
     */
    private void drawFrame(Graphics g) {
        // Create a new image for double buffering if necessary
        if (image == null || image.getWidth(null) != _W || image.getHeight(null) != _H) {
            image = createImage(_W, _H);
            graphics = image.getGraphics();
        }
        
        // Draw lines, shapes, and vectors on the buffered image
        drawLines(graphics);
        drawShapes(graphics);
        drawVector(graphics);
        
        // Draw the buffered image to the screen
        g.drawImage(image, 0, 0, null);
        graphics.clearRect(0, 0, _W, _H);
    }

    /**
     * Draws the 3D shapes on the canvas using perspective projection.
     * 
     * @param g The Graphics object to draw on.
     */
    private void drawShapes(Graphics g) {
        if (shapes != null) {
            g.setColor(Color.PINK);
            // Iterate through each shape
            for (int i = 0; i < shapes.length; i++) {
                int n = shapes[i].length;
                int[][] points = new int[n][2];
                // Project each vertex of the shape onto the 2D screen
                for (int j = 0; j < n; j++) {
                    points[j][0] = (int) ((_W >> 1) + (shapes[i][j].x * near / (shapes[i][j].y + far)) * _i);
                    points[j][1] = (int) ((_H >> 1) + (shapes[i][j].z * near / (shapes[i][j].y + far)) * _i);
                }
                // Draw lines between projected vertices to form the shape
                for (int j = 0; j < n - 1; j++) {
                    g.setColor(Color.YELLOW);
                    g.drawLine(points[j][0], points[j][1], points[j + 1][0], points[j + 1][1]);
                }
                g.drawLine(points[n - 1][0], points[n - 1][1], points[0][0], points[0][1]);
            }
        }
    }

    /**
     * Draws the 3D vectors on the canvas using perspective projection.
     * 
     * @param g The Graphics object to draw on.
     */
    private void drawVector(Graphics g) {
        if (_vectors != null) {
            g.setColor(Color.PINK);
            // Iterate through each vector
            for (int i = 0; i < _vectors.length; i++) {
                // Project the vector onto the 2D screen
                int px = (int) ((_W >> 1) + (vectors[i].x * near / (vectors[i].y + far)) * _i);
                int py = (int) ((_H >> 1) + (vectors[i].z * near / (vectors[i].y + far)) * _i);
                
                // Draw the vector and its index label
                g.drawString(i + "", px, py);
                g.drawLine(_W >> 1, _H >> 1, px, py);
                g.drawString(_vectors[i] + "", px - 10, py - 10);
            }
        }
    }

    /**
     * Draws the grid lines and axis lines on the canvas.
     * 
     * @param g The Graphics object to draw on.
     */
    private void drawLines(Graphics g) {
        int center_x = _W >> 1, center_y = _H >> 1;

        // Clear the canvas with black color
        g.setColor(Color.BLACK);
        g.fillRect(0, 0, _W, _H);
        
        // Draw axis lines with perspective and labels
        for (int i = 0; i < 3; i++) {
            g.setColor(new Color(255 - i * 100, i * 110, 22 << i));
            g.drawLine(
                    (int) (center_x + (lines[i << 1].x * near / (lines[i << 1].y + far)) * _i),
                    (int) (center_y + (lines[i << 1].z * near / (lines[i << 1].y + far)) * _i),
                    (int) (center_x + (lines[(i << 1) + 1].x * near / (lines[(i << 1) + 1].y + far)) * _i),
                    (int) (center_y + (lines[(i << 1) + 1].z * near / (lines[(i << 1) + 1].y + far)) * _i));
            
            // Draw unit labels on the axis lines
            for (int j = 0; j <= gridRes; j++) {
                double factor = j / (double) (gridRes);
                double interpX = lines[i << 1].x + factor * (lines[(i << 1) + 1].x - lines[i << 1].x);
                double interpY = lines[i << 1].y + factor * (lines[(i << 1) + 1].y - lines[i << 1].y);
                double interpZ = lines[i << 1].z + factor * (lines[(i << 1) + 1].z - lines[i << 1].z);
                int screenX = (int) (center_x + (interpX * near / (interpY + far)) * _i);
                int screenY = (int) (center_y + (interpZ * near / (interpY + far)) * _i);
                g.drawString((gridRes >> 1) - j + "", screenX, screenY); 
            }
        }
        
        // Draw grid lines with perspective
        g.setColor(new Color(90, 90, 90, 120));
        for (int i = 0; i < gridRes; i++) {
            g.drawLine(
                    (int) (center_x + (gridLines[i << 2].x * near / (gridLines[i << 2].y + far)) * _i),
                    (int) (center_y + (gridLines[i << 2].z * near / (gridLines[i << 2].y + far)) * _i),
                    (int) (center_x + (gridLines[(i << 2) + 1].x * near / (gridLines[(i << 2) + 1].y + far)) * _i),
                    (int) (center_y + (gridLines[(i << 2) + 1].z * near / (gridLines[(i << 2) + 1].y + far)) * _i));
            g.drawLine(
                    (int) (center_x + (gridLines[(i << 2) + 2].x * near / (gridLines[(i << 2) + 2].y + far)) * _i),
                    (int) (center_y + (gridLines[(i << 2) + 2].z * near / (gridLines[(i << 2) + 2].y + far)) * _i),
                    (int) (center_x + (gridLines[(i << 2) + 3].x * near / (gridLines[(i << 2) + 3].y + far)) * _i),
                    (int) (center_y + (gridLines[(i << 2) + 3].z * near / (gridLines[(i << 2) + 3].y + far)) * _i));
        }
    }

    /**
     * Updates the canvas dimensions when resized.
     */
    public void updateSizeFields() {
        _W = getWidth();
        _H = getHeight();
    }

    /**
     * Updates the grid lines based on camera angles.
     */
    public void updateGridLines() {
        // Rotate grid lines based on camera angles
        for (int i = 0; i < 6; i++) {
            lines[i] = Utils.rotZX.apply(_lines[i], angleZ, angleX);
        }
        for (int i = 0; i < gridRes << 1; i++) {
            gridLines[i << 1] = Utils.rotZX.apply(_gridLines[i << 1], angleZ, angleX);
            gridLines[(i << 1) + 1] = Utils.rotZX.apply(_gridLines[(i << 1) + 1], angleZ, angleX);
        }
    }

    // Setters for camera angles
    public void setAngleZ(double angleZ) {
        this.angleZ = angleZ;
    }

    public void setAngleX(double angleX) {
        this.angleX = angleX;
    }

    /**
     * Converts screen coordinates to camera angles and updates the view.
     * 
     * @param x The x-coordinate of the mouse.
     * @param y The y-coordinate of the mouse.
     */
    public void screenPositionToAngles(int x, int y) {
        setAngleZ(x * 6.283185 / _W);
        setAngleX(y * 6.283185 / _H);
        updateGridLines();
        updateShapes();
        updateVectors();
    }

    /**
     * Sets the vectors to be drawn on the canvas.
     * 
     * @param vectors An array of V3 vectors.
     */
    public void setVectors(V3[] vectors) {
        _vectors = vectors;
        updateVectors();
    }

    /**
     * Sets the shapes to be drawn on the canvas.
     * 
     * @param shapes An array of V3 arrays representing the shapes.
     */
    public void setShapes(V3[][] shapes) {
        _shapes = shapes;
        updateShapes();
    }

    /**
     * Updates the vectors based on camera angles.
     */
    public void updateVectors() {
        if (_vectors != null) {
            vectors = new V3[_vectors.length];
            if (vectors == null) {
                vectors = new V3[_vectors.length];
            }
            for (int i = 0; i < _vectors.length; i++) {
                vectors[i] = Utils.rotZX.apply(_vectors[i], angleZ, angleX);
            }
        }
    }

    /**
     * Updates the shapes based on camera angles.
     */
    public void updateShapes() {
        if (_shapes != null) {
            shapes = new V3[_shapes.length][];
            for (int i = 0; i < _shapes.length; i++) {
                if (shapes[i] == null) {
                    shapes[i] = new V3[_shapes[i].length];
                }
                for (int j = 0; j < _shapes[i].length; j++) {
                    shapes[i][j] = Utils.rotZX.apply(_shapes[i][j], angleZ, angleX);
                }
            }
        }
    }

    /**
     * Increments or decrements the zoom level.
     * 
     * @param amount The amount to increment or decrement by.
     */
    public void incrementI(int amount) {
        _i += amount;
    }

    /**
     * Overrides the paintComponent method to draw the frame using double buffering.
     * 
     * @param g The Graphics object to draw on.
     */
    @Override
    public void paintComponent(Graphics g) {
        super.paintComponent(g);
        drawFrame(g);
    }
}

/**
 * This enum defines various 3D shapes and provides a method to get their vertices.
 */
enum Shape {
   /**
    * Represents a cube with vertices at unit distances from the origin.
    */
   
    CUBE {
       @Override
       public V3[] getVectors() {
           // Define the vertices of the cube
           V3[] vectors = {
                 new V3(-1, 1, 1), new V3(-1, 1, -1), new V3(1, 1, -1), new V3(1, 1, 1),
                 new V3(1, -1, 1), new V3(1, -1, -1), new V3(-1, -1, -1), new V3(-1, -1, 1)
           };
           return vectors;
       }
   },
   
   /**
    * Represents a pyramid with its apex at (0, 0, 1) and base vertices in the z = -1 plane.
    */
   PYRAMID {
       @Override
       public V3[] getVectors() {
           // Define the vertices of the pyramid
           V3[] vectors = {
                 new V3(0, 0, 1), new V3(-1, 1, -1), new V3(1, 1, -1),
                 new V3(1, -1, -1), new V3(-1, -1, -1)
           };
           return vectors;
       }
   },
   
   /**
    * Represents a sphere with a specified resolution (number of vertices).
    */
   SPHERE(96) {
       @Override
       public V3[] getVectors() {
           // Create an array to store the sphere's vertices
           V3[] vectors = new V3[res * res];
           V3 aux = new V3(1, 0, 0);

           // Generate sphere vertices using spherical coordinates
           for (int i = 0; i < res; i++) {
               aux = Utils.rotY.apply(aux, i * (2 * Math.PI / res));
               for (int j = 0; j < res; j++) {
                   vectors[i * res + j] = Utils.rotX.apply(aux, j * (2 * Math.PI / res));
               }
           }
           return vectors;
       }
   };
   // Resolution (number of vertices) for the sphere
   public int res;
   // Constructor for shapes with custom resolution
   Shape(int res) {
       this.res = res;
   }

   // Default constructor
   Shape() {
   }


   /**
    * Abstract method to be implemented by each shape to return its vertices.
    * 
    * @return An array of V3 vectors representing the vertices of the shape.
    */
   public abstract V3[] getVectors();
}

/**
 * This class provides utility functions for 3D transformations.
 * It defines several transformation functions as lambda expressions,
 * each implementing the TransformFunction interface.
 */
class Utils {
   // Projection functions
   public static final TransformFunction projXY = (u, f) -> new V3(u.x, u.y, u.z * f[0]);
   public static final TransformFunction projXZ = (u, f) -> new V3(u.x, u.y * f[0], u.z);
   public static final TransformFunction projYZ = (u, f) -> new V3(u.x * f[0], u.y, u.z);

   // Reflection functions
   public static final TransformFunction refX = (u, f) -> new V3(u.x * f[0], u.y, u.z);
   public static final TransformFunction refY = (u, f) -> new V3(u.x, u.y * f[0], u.z);
   public static final TransformFunction refZ = (u, f) -> new V3(u.x, u.y, u.z * f[0]);

   // Rotation functions
   public static final TransformFunction rotX = (u, a) -> new V3(
           u.x,
           u.y * Math.cos(a[0]) + u.z * Math.sin(a[0]),
           u.z * Math.cos(a[0]) - u.y * Math.sin(a[0]));

   public static final TransformFunction rotY = (u, a) -> new V3(
           u.x * Math.cos(a[0]) - u.z * Math.sin(a[0]),
           u.y,
           u.z * Math.cos(a[0]) + u.x * Math.sin(a[0]));

   public static final TransformFunction rotZ = (u, a) -> new V3(
           u.x * Math.cos(a[0]) + u.y * Math.sin(a[0]),
           u.y * Math.cos(a[0]) - u.x * Math.sin(a[0]),
           u.z);

   public static final TransformFunction rotZX = (u, a) -> new V3( 
           u.x * Math.cos(a[0]) + u.y * Math.sin(a[0]),
           (u.y * Math.cos(a[0]) - u.x * Math.sin(a[0])) * Math.cos(a[1]) + u.z * Math.sin(a[1]),
           u.z * Math.cos(a[1]) - (u.y * Math.cos(a[0]) - u.x * Math.sin(a[0])) * Math.sin(a[1]));

   // Scaling function
   public static final TransformFunction scale = (u, f) -> new V3(
           u.x * f[0],
           u.y * f[0],
           u.z * f[0]);

   // Translation function
   public static final TransformFunction translate = (u, d) -> new V3(
           u.x + d[0],
           u.y + d[1],
           u.z + d[2]);

   // Shearing functions
   public static final TransformFunction shearOnX = (u, s) -> new V3(
           u.x, u.y + u.x * s[0], u.z + u.x * s[1]);
   public static final TransformFunction shearOnY = (u, s) -> new V3(
           u.x + u.y * s[0], u.y, u.z + u.y * s[1]);
   public static final TransformFunction shearOnZ = (u, s) -> new V3(
           u.x + u.z * s[0], u.y + u.z * s[1], u.z);
}

/**
* This interface defines a contract for functions that transform a 3D vector.
*/
interface TransformFunction {
   /**
    * Applies a transformation to a given 3D vector.
    * 
    * @param u The vector to transform.
    * @param args An array of double values representing transformation parameters.
    * @return The transformed vector.
    */
   V3 apply(V3 u, double... args);
}

/**
* This class represents a 3D vector with x, y, and z components.
*/
class V3 {
   double x, y, z;

   /**
    * Constructs a 3D vector with the given x, y, and z components.
    * 
    * @param x The x-component of the vector.
    * @param y The y-component of the vector.
    * @param z The z-component of the vector.
    */
   V3(double x, double y, double z) {
       this.x = x;
       this.y = y;
       this.z = z;
   }

   /**
    * Returns a string representation of the vector.
    * 
    * @return A string representation of the vector.
    */
   @Override
   public String toString() {
       return "(" + String.format("%.2f", x) + ", " + String.format("%.2f", y) + ", " + String.format("%.2f", z) + ")";
   }
}
/**
 * This class provides utility functions for 3D transformations.
 * It defines several transformation functions as lambda expressions,
 * each implementing the TransformFunction interface.
 */
public class Utils {
    // Projection functions
    public static final TransformFunction projXY = (u, f) -> new V3(u.x, u.y, u.z * f[0]);
    public static final TransformFunction projXZ = (u, f) -> new V3(u.x, u.y * f[0], u.z);
    public static final TransformFunction projYZ = (u, f) -> new V3(u.x * f[0], u.y, u.z);

    // Reflection functions
    public static final TransformFunction refX = (u, f) -> new V3(u.x * f[0], u.y, u.z);
    public static final TransformFunction refY = (u, f) -> new V3(u.x, u.y * f[0], u.z);
    public static final TransformFunction refZ = (u, f) -> new V3(u.x, u.y, u.z * f[0]);

    // Rotation functions
    public static final TransformFunction rotX = (u, a) -> new V3(
            u.x,
            u.y * Math.cos(a[0]) + u.z * Math.sin(a[0]),
            u.z * Math.cos(a[0]) - u.y * Math.sin(a[0]));

    public static final TransformFunction rotY = (u, a) -> new V3(
            u.x * Math.cos(a[0]) - u.z * Math.sin(a[0]),
            u.y,
            u.z * Math.cos(a[0]) + u.x * Math.sin(a[0]));

    public static final TransformFunction rotZ = (u, a) -> new V3(
            u.x * Math.cos(a[0]) + u.y * Math.sin(a[0]),
            u.y * Math.cos(a[0]) - u.x * Math.sin(a[0]),
            u.z);

    public static final TransformFunction rotZX = (u, a) -> new V3( 
            u.x * Math.cos(a[0]) + u.y * Math.sin(a[0]),
            (u.y * Math.cos(a[0]) - u.x * Math.sin(a[0])) * Math.cos(a[1]) + u.z * Math.sin(a[1]),
            u.z * Math.cos(a[1]) - (u.y * Math.cos(a[0]) - u.x * Math.sin(a[0])) * Math.sin(a[1]));

    // Scaling function
    public static final TransformFunction scale = (u, f) -> new V3(
            u.x * f[0],
            u.y * f[0],
            u.z * f[0]);

    // Translation function
    public static final TransformFunction translate = (u, d) -> new V3(
            u.x + d[0],
            u.y + d[1],
            u.z + d[2]);

    // Shearing functions
    public static final TransformFunction shearOnX = (u, s) -> new V3(
            u.x, u.y + u.x * s[0], u.z + u.x * s[1]);
    public static final TransformFunction shearOnY = (u, s) -> new V3(
            u.x + u.y * s[0], u.y, u.z + u.y * s[1]);
    public static final TransformFunction shearOnZ = (u, s) -> new V3(
            u.x + u.z * s[0], u.y + u.z * s[1], u.z);
}

/**
 * This interface defines a contract for functions that transform a 3D vector.
 */
interface TransformFunction {
    /**
     * Applies a transformation to a given 3D vector.
     * 
     * @param u The vector to transform.
     * @param args An array of double values representing transformation parameters.
     * @return The transformed vector.
     */
    V3 apply(V3 u, double... args);
}

/**
 * This class represents a 3D vector with x, y, and z components.
 */
class V3 {
    double x, y, z;

    /**
     * Constructs a 3D vector with the given x, y, and z components.
     * 
     * @param x The x-component of the vector.
     * @param y The y-component of the vector.
     * @param z The z-component of the vector.
     */
    V3(double x, double y, double z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    /**
     * Returns a string representation of the vector.
     * 
     * @return A string representation of the vector.
     */
    @Override
    public String toString() {
        return "(" + String.format("%.2f", x) + ", " + String.format("%.2f", y) + ", " + String.format("%.2f", z) + ")";
    }
}
//$ sessionjc -cp lib/ -d lib/ src/jacobi/Jacobi.sj
//$

package jacobi;

import java.util.Arrays;

/**
 * Base class for Jacobi method implementation.
 */
public abstract class Jacobi {
    public static final int BOUND_TOP    = 0;
    public static final int BOUND_RIGHT  = 1;
    public static final int BOUND_BOTTOM = 2;
    public static final int BOUND_LEFT   = 3;

    public static final int MAX_ITERATIONS = 3000;

    public void init(double[][] u, double[][] v, double above, double right, double below, double left) {
        for (int i=0; i<u.length; ++i) {
            for (int j=0; j<u[i].length; ++j) {
                u[i][j] = 0.0;
                v[i][j] = 0.0;
            }
        }

        // Sets up boundary (for sending/receiving in parallel version)
        for (int i=0; i<u.length; ++i) {
            u[0][i] = above;
            v[0][i] = above;

            u[u.length-1][i] = below;
            v[u.length-1][i] = below;

            u[i][u.length-1] = right;
            v[i][u.length-1] = right;

            u[i][0] = left;
            v[i][0] = left;
        }
    }

    public Checkconv iterate(double[][] u, double[][] v, int arraySize) {
        Checkconv cc = new Checkconv();
        cc.diff  = 0.0;
        cc.valmx = 0.0;

        // The first and final row (index = 0, arraySize+1) are not changed

        for (int i = 1; i < arraySize+1; ++i) { // 1-indexed
            for (int j = 1; j < arraySize + 1; ++j) { // 1-indexed
                v[i][j] = ( u[i-1][j] + u[i+1][j] + u[i][j-1] + u[i][j+1] ) / 4.0;

                // Maximum difference between iterations
                cc.diff  = Math.max( cc.diff, Math.abs( v[i][j] - u[i][j] ) );
                // Maximum value in new matrix
                cc.valmx = Math.max( cc.valmx, Math.abs(v[i][j]) );
            }
        }

        return cc;
    }

    public static boolean hasConverged(Checkconv cc) {
        return ((cc.diff / cc.valmx) < (1.0 * Math.pow(10, -5)));
    }

    public void printMatrix(double[][] u) {
        for (int i=0; i<u.length; ++i) {
            System.out.println(Arrays.toString(u[i]));
        }
    }

    public void printMatrixContent(double[][] u) {
        for (int i=1; i<u.length-1; ++i) {
            System.out.print("[");
            for (int j=1; j<u[i].length-1; ++j) {
                System.out.print(u[i][j] + " ");
            }
            System.out.println("]");
        }
    }
}

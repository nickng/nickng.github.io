//$ sessionjc -cp lib -d lib src/jacobi/mc/Master.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.mc.Master mesh.yaml master 9 1 1.0 1.0 1.0 1.0

package jacobi.mc;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;
import sessionj.utils.Log;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * Master node of Jacobi method implementation.
 *
 * Conceptually Master node is unique and is the
 * top-left corner of the mesh topology:
 *  1. connected to first North-Worker node
 *  2. connected to first West-Worker node (ie. below)
 */
public class Master extends Jacobi {
    private final noalias protocol p_right {
        cbegin.
            !<int>.          // Nr of nodes
            !<int>.          // Sz of array
            !<double[]>.     // fixed bounds
            ![
                !<double[]>. // right column->
                ?(double[]). // <-right column
                ?(Checkconv) // Converged?
            ]*
    }

    private final noalias protocol p_below {
        cbegin.
            !<int>.          // Nr of nodes
            !<int>.          // Sz of array
            !<double[]>.     // fixed bounds
            ![
                !<double[]>. // bottom row->
                ?(double[]). // <-bottom row
                ?(Checkconv) // Converged?
            ]*
    }

    public void run(String rightHost, int rightPort, String belowHost, int belowPort, int nrOfNodes, int arraySize, double topBound, double rightBound, double downBound, double leftBound) {
        final noalias SJService rightNode = SJService.create(p_right, rightHost, rightPort);
        final noalias SJService belowNode = SJService.create(p_below, belowHost, belowPort);

        final noalias SJSocket right;
        final noalias SJSocket below;

        // double[] quadBounds = { topBound, rightBound, downBound, leftBound };
        double[] quadBounds = new double[4];
        quadBounds[BOUND_TOP]   = topBound;
        quadBounds[BOUND_RIGHT] = rightBound;
        quadBounds[BOUND_BOTTOM]= downBound;
        quadBounds[BOUND_LEFT]  = leftBound;

        int[] nodeSizes = new int[nrOfNodes];

        double[][] matrix     = new double[arraySize+2][arraySize+2];
        double[][] tempMatrix = new double[arraySize+2][arraySize+2];

        double[] rightColumn = new double[arraySize];
        double[] bottomRow   = new double[arraySize];

        Checkconv cc = new Checkconv();
        Checkconv ccBelow = new Checkconv();
        Checkconv ccRight = new Checkconv();

        init(matrix, tempMatrix, quadBounds[BOUND_TOP], 0.0f, 0.0f, quadBounds[BOUND_LEFT]);

        long time = 0L;

        int iterations = 0;
        try (right, below) {
            time = System.currentTimeMillis();

            right = rightNode.request();
            below = belowNode.request();

            right.send(nrOfNodes);
            below.send(nrOfNodes);

            right.send(arraySize);
            below.send(arraySize);

            right.send(quadBounds);
            below.send(quadBounds);

            <right, below>.outwhile(!hasConverged(cc) && iterations < MAX_ITERATIONS) {
                // A single iteration of calculation
                cc = iterate(matrix, tempMatrix, arraySize); 

                for (int i=0; i<arraySize; ++i) {
                    rightColumn[i] = tempMatrix[i+1][arraySize];
                    bottomRow[i]   = tempMatrix[arraySize][i+1];
                }

                right.send(rightColumn);
                rightColumn = (double[])right.receive();
                ccRight = (Checkconv)right.receive();

                below.send(bottomRow);
                bottomRow   = (double[])below.receive();
                ccBelow = (Checkconv)below.receive();

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[i+1][arraySize+1] = rightColumn[i];
                    tempMatrix[arraySize+1][i+1] = bottomRow[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                ++iterations;

                cc.diff = Math.max( cc.diff, Math.max( ccBelow.diff, ccRight.diff ) );
                cc.valmx = Math.max( cc.valmx, Math.max( ccBelow.valmx, ccRight.valmx ) );

            } // outwhile

            if (hasConverged(cc)) {

                Log.i("ver=MC arraySz="+arraySize, "End of calculation (reason: Master converged, iterations="+iterations+", Convergence parameter="+cc+").");

            } else if (iterations >= MAX_ITERATIONS) {

                Log.i("ver=MC arraySz="+arraySize, "End of calculation (reason: MAX_ITERATIONS("+MAX_ITERATIONS+") reached cc="+cc+").");

            }

        } catch (SJRuntimeException re) {

            System.err.println("[Master] Runtime error: "+re);

        } catch (SJIOException ioe) {

            System.err.println("[Master] Communication error: "+ioe);

        } catch (SJIncompatibleSessionException ise) {

            System.err.println("[Master] Non-dual behaviour: "+ise);
        
        } catch (ClassNotFoundException cnfe) {

            System.err.println("[Master] Class not found: "+cnfe);

        } finally {}

        Log.b("jacobi-ver=MC arraySz="+arraySize, ""+(System.currentTimeMillis() - time));

    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);
        
        String rightHost = config.get("right.host");
        int rightPort = Integer.parseInt(config.get("right.port"));

        String belowHost = config.get("below.host");
        int belowPort = Integer.parseInt(config.get("below.port"));

        int nrOfNodes = Integer.parseInt(args[2]);
        int arraySize = Integer.parseInt(args[3]);

        double topBound = Double.parseDouble(args[4]);
        double rightBound = Double.parseDouble(args[5]);
        double downBound = Double.parseDouble(args[6]);
        double leftBound = Double.parseDouble(args[7]);

        (new Master()).run(rightHost, rightPort, belowHost, belowPort, nrOfNodes, arraySize, topBound, rightBound, downBound, leftBound);
    }
}

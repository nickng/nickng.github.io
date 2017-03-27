//$ sessionjc -cp lib -d lib src/jacobi/mc/WorkerNorth.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.mc.WorkerNorth mesh.yaml north

package jacobi.mc;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * NORTH Worker node of Jacobi method implementation.
 *
 * North Worker nodes are in the top row of the mesh:
 *  1. connected to   Worker node right
 *  2. connected to   Worker node below
 *  3. connected from Worker node left
 */
public class WorkerNorth extends Jacobi {
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
            ![
                !<double[]>. // bottom row->
                ?(double[])  // <-bottom row
            ]*
    }

    private final noalias protocol p_left { ^(p_right) }

    public void run(String rightHost, int rightPort, String belowHost, int belowPort, int leftPort) {
        final noalias SJService rightNode = SJService.create(p_right, rightHost, rightPort);
        final noalias SJService belowNode = SJService.create(p_below, belowHost, belowPort);

        final noalias SJServerSocket leftNode;

        final noalias SJSocket above, right, below, left;


        double[] quadBounds = new double[4];

        int nrOfNodes, arraySize;

        double[][] matrix;
        double[][] tempMatrix;

        double[] rightColumn;
        double[] bottomRow;
        double[] leftColumn;

        double[] leftColumn_received;

        Checkconv cc = new Checkconv();
        Checkconv ccRight = new Checkconv();

        try (leftNode) {
            leftNode  = SJServerSocketImpl.create(p_left, leftPort);

            try (right, below, left) {
                right = rightNode.request();
                below = belowNode.request();

                left = leftNode.accept();

                nrOfNodes = left.receiveInt();
                arraySize = left.receiveInt();
                quadBounds = (double[]) left.receive();

                right.send(nrOfNodes);
                right.send(arraySize);
                right.send(quadBounds);

                // Initialise after the details are forwarded
                matrix     = new double[arraySize+2][arraySize+2];
                tempMatrix = new double[arraySize+2][arraySize+2];

                rightColumn = new double[arraySize];
                bottomRow   = new double[arraySize];
                leftColumn  = new double[arraySize];

                leftColumn_received = new double[arraySize];


                init(matrix, tempMatrix, quadBounds[BOUND_TOP], 0.0f, 0.0f, 0.0f);

                <right, below>.outwhile(left.inwhile()) {
                    cc = iterate(matrix, tempMatrix, arraySize);

                    // Send prepare
                    for (int i=0; i<arraySize; ++i) {
                        rightColumn[i] = tempMatrix[i+1][arraySize];
                        bottomRow[i]   = tempMatrix[arraySize][i+1];
                        leftColumn[i]  = tempMatrix[i+1][1];
                    }

                    leftColumn_received = (double[])left.receive();
                    left.send(leftColumn);

                    right.send(rightColumn);
                    rightColumn = (double[])right.receive(); // Note: reused 
                    ccRight = (Checkconv)right.receive();

                    below.send(bottomRow);
                    bottomRow = (double[])below.receive(); // Note: reused

                    // Store results
                    for (int i=0; i<arraySize; ++i) {
                        tempMatrix[i+1][arraySize+1] = rightColumn[i];
                        tempMatrix[arraySize+1][i+1] = bottomRow[i];
                        tempMatrix[i+1][0] = leftColumn_received[i];
                    }

                    double[][] tmp;
                    tmp = matrix;
                    matrix = tempMatrix;
                    tempMatrix = tmp;

                    cc.diff = Math.max( cc.diff, ccRight.diff );
                    cc.valmx = Math.max( cc.valmx, ccRight.valmx );

                    left.send(cc);
                }

//                printMatrixContent(matrix);

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[WorkerNorth] Non-dual behaviour: "+ise);

            } catch (SJIOException ioe) {

                System.err.println("[WorkerNorth] Communication error: "+ioe);

            } catch (ClassNotFoundException cnfe) {

                System.err.println("[WorkerNorth] Class not found: "+cnfe);

            } finally {} // Sockets
        } catch (SJIOException ioe) {

            System.err.println("[WorkerNorth] Communication error: "+ioe);

        } finally {}
    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);
        String rightHost = config.get("right.host");
        int rightPort = Integer.parseInt(config.get("right.port"));

        String belowHost = config.get("below.host");
        int belowPort = Integer.parseInt(config.get("below.port"));

        int leftPort = Integer.parseInt(config.get("left.port"));

        (new WorkerNorth()).run(rightHost, rightPort, belowHost, belowPort, leftPort);
    }
}

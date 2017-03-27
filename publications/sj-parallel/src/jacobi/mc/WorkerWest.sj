//$ sessionjc -cp lib -d lib src/jacobi/mc/WorkerWest.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.mc.WorkerWest mesh.yaml west

package jacobi.mc;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * WEST Worker node of Jacobi method implementation.
 *
 * West Worker nodes are in the leftmost column of
 * the mesh:
 *  1. connected from Worker node above
 *  2. connected to   Worker node right
 *  3. connected to   Worker node below
 */
public class WorkerWest extends Jacobi {
    private final noalias protocol p_above {
        sbegin.
            ?(int).          // Nr of nodes
            ?(int).          // Sz of array
            ?(double[]).     // fixed bounds
            ?[
                ?(double[]). // <-top row
                !<double[]>. // top row->
                !<Checkconv> // Converged?
            ]*
    }

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

    private final noalias protocol p_below { ^(p_above) }

    public void run(int abovePort, String rightHost, int rightPort, String belowHost, int belowPort) {
        final noalias SJService rightNode = SJService.create(p_right, rightHost, rightPort);
        final noalias SJService belowNode = SJService.create(p_below, belowHost, belowPort);

        final noalias SJServerSocket aboveNode;
        final noalias SJSocket above, right, below;


        double[] quadBounds = new double[4];

        int nrOfNodes, arraySize;

        double[][] matrix;
        double[][] tempMatrix;

        double[] topRow;
        double[] rightColumn;
        double[] bottomRow;

        double[] topRow_received;

        Checkconv cc = new Checkconv();
        Checkconv ccRight = new Checkconv();
        Checkconv ccBelow = new Checkconv();

        try (aboveNode) {
            aboveNode = SJServerSocketImpl.create(p_above, abovePort);

            try (above, right, below) {
                above = aboveNode.accept();
                right = rightNode.request();
                below = belowNode.request();

                nrOfNodes = above.receiveInt();
                arraySize = above.receiveInt();
                quadBounds = (double[])above.receive();

                right.send(nrOfNodes);
                right.send(arraySize);
                right.send(quadBounds);

                below.send(nrOfNodes);
                below.send(arraySize);
                below.send(quadBounds);

                // Initialise after the details are forwarded
                matrix     = new double[arraySize+2][arraySize+2];
                tempMatrix = new double[arraySize+2][arraySize+2];

                topRow      = new double[arraySize];
                rightColumn = new double[arraySize];
                bottomRow   = new double[arraySize];

                topRow_received = new double[arraySize];

                init(matrix, tempMatrix, 0.0f, 0.0f, 0.0f, quadBounds[BOUND_LEFT]);

                <right, below>.outwhile(above.inwhile()) {
                    cc = iterate(matrix, tempMatrix, arraySize);

                    for (int i=0; i<arraySize; ++i) {
                        topRow[i]      = tempMatrix[1][i+1];
                        rightColumn[i] = tempMatrix[i+1][arraySize];
                        bottomRow[i]   = tempMatrix[arraySize][i+1];
                    }

                    topRow_received = (double[])above.receive();
                    above.send(topRow);

                    right.send(rightColumn);
                    rightColumn = (double[])right.receive(); // Note: reused
                    ccRight = (Checkconv)right.receive();

                    below.send(bottomRow);
                    bottomRow = (double[])below.receive(); // Note: reused
                    ccBelow = (Checkconv)below.receive();

                    for (int i=0; i<arraySize; ++i) {
                        tempMatrix[0][i+1]           = topRow_received[i];
                        tempMatrix[i+1][arraySize+1] = rightColumn[i];
                        tempMatrix[arraySize+1][i+1] = bottomRow[i];
                    }

                    double[][] tmp;
                    tmp = matrix;
                    matrix = tempMatrix;
                    tempMatrix = tmp;

                    cc.diff = Math.max( cc.diff, Math.max( ccBelow.diff, ccRight.diff ) );
                    cc.valmx = Math.max( cc.valmx, Math.max( ccBelow.valmx, ccRight.valmx ) );

                    above.send(cc);
                }

//                printMatrixContent(matrix);

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[WorkerWest] Non-dual behaviour: "+ise);

            } catch (SJIOException ioe) {

                System.err.println("[WorkerWest] Communication error: "+ioe);

            } catch (ClassNotFoundException cnfe) {

                System.err.println("[WorkerWest] Class not found: "+cnfe);

            } finally {} // Sockets

        } catch (SJIOException ioe) {

            System.err.println("[WorkerWest] Communication error: "+ioe);

        } finally {}
    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);
        int abovePort = Integer.parseInt(config.get("above.port"));

        String rightHost = config.get("right.host");
        int rightPort = Integer.parseInt(config.get("right.port"));

        String belowHost = config.get("below.host");
        int belowPort = Integer.parseInt(config.get("below.port"));

        (new WorkerWest()).run(abovePort, rightHost, rightPort, belowHost, belowPort);
    }
}

//$ sessionjc -cp lib -d lib src/jacobi/mc/WorkerEast.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.mc.WorkerEast mesh.yaml east

package jacobi.mc;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * EAST Worker node of Jacobi method implementation.
 *
 * East Worker nodes are in the rightmost column of
 * the mesh:
 *  1. connected from Worker node above
 *  2. connected to   Worker node below
*   3. connected from Worker node left
 */
public class WorkerEast extends Jacobi {
    private final noalias protocol p_above {
        sbegin.
            ?[
                ?(double[]).
                !<double[]>
            ]*
    }

    private final noalias protocol p_below { ^(p_above) }

    private final noalias protocol p_left {
        sbegin.
            ?(int).          // Nr of nodes
            ?(int).          // Sz of array
            ?(double[]).     // fixed bounds
            ?[
                ?(double[]). // left row->
                !<double[]>. // <-left row
                !<Checkconv> // Converged?
            ]*
    }

    public void run(int abovePort, String belowHost, int belowPort, int leftPort) {
        final noalias SJService belowNode = SJService.create(p_below, belowHost, belowPort);

        final noalias SJServerSocket aboveNode;
        final noalias SJServerSocket leftNode;

        final noalias SJSocket above, below, left;


        double[] quadBounds = new double[4];

        int nrOfNodes, arraySize;

        double[][] matrix;
        double[][] tempMatrix;

        double[] topRow;
        double[] bottomRow;
        double[] leftColumn;

        double[] topRow_received;
        double[] leftColumn_received;

        Checkconv cc = new Checkconv();

        try (aboveNode, leftNode) {
            aboveNode = SJServerSocketImpl.create(p_above, abovePort);
            leftNode  = SJServerSocketImpl.create(p_left, leftPort);

            try (above, below, left) {
                above = aboveNode.accept();
                below = belowNode.request();
                left  = leftNode.accept();

                nrOfNodes = left.receiveInt();
                arraySize = left.receiveInt();
                quadBounds = (double[]) left.receive();

                // Initialise after the details are forwarded
                matrix     = new double[arraySize+2][arraySize+2];
                tempMatrix = new double[arraySize+2][arraySize+2];

                topRow      = new double[arraySize];
                bottomRow   = new double[arraySize];
                leftColumn  = new double[arraySize];

                topRow_received = new double[arraySize];
                leftColumn_received = new double[arraySize];


                init(matrix, tempMatrix, 0.0f, quadBounds[BOUND_RIGHT], 0.0f, 0.0f);

                below.outwhile(<above, left>.inwhile()) {
                    cc = iterate(matrix, tempMatrix, arraySize);

                    for (int i=0; i<arraySize; ++i) {
                        topRow[i]     = tempMatrix[1][i+1];
                        leftColumn[i] = tempMatrix[i+1][1];
                        bottomRow[i]  = tempMatrix[arraySize][i+1];
                    }

                    topRow_received = (double[])above.receive();
                    above.send(topRow);

                    leftColumn_received = (double[])left.receive();
                    left.send(leftColumn);
                    left.send(cc);

                    below.send(bottomRow);
                    bottomRow = (double[])below.receive(); // Note: reused

                    for (int i=0; i<arraySize; ++i) {
                        tempMatrix[0][i+1]           = topRow_received[i];
                        tempMatrix[i+1][0]           = leftColumn_received[i];
                        tempMatrix[arraySize+1][i+1] = bottomRow[i];
                    }

                    double[][] tmp;
                    tmp = matrix;
                    matrix = tempMatrix;
                    tempMatrix = tmp;
                }

//                printMatrixContent(matrix);

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[WorkerEast] Non-dual behaviour: "+ise);

            } catch (SJIOException ioe) {

                System.err.println("[WorkerEast] Communication error: "+ioe);

            } catch (ClassNotFoundException cnfe) {

                System.err.println("[WorkerEast] Class not found: "+cnfe);

            } finally {} // Sockets
        } catch (SJIOException ioe) {

            System.err.println("[WorkerEast] Communication error: "+ioe);

        } finally {}
    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);

        int abovePort = Integer.parseInt(config.get("above.port"));

        String belowHost = config.get("below.host");
        int belowPort = Integer.parseInt(config.get("below.port"));

        int leftPort = Integer.parseInt(config.get("left.port"));

        (new WorkerEast()).run(abovePort, belowHost, belowPort, leftPort);
    }
}

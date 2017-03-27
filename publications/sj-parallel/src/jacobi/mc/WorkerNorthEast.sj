//$ sessionjc -cp lib -d lib src/jacobi/mc/WorkerNorthEast.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.mc.WorkerNorthEast mesh.yaml northeast

package jacobi.mc;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * NORTHEAST Worker node of Jacobi method implementation.
 *
 * Northeast Worker nodes are nodes in the top-right corner
 * of the mesh:
 *  1. connected to   Worker node below
 *  2. connected from Worker node left
 */
public class WorkerNorthEast extends Jacobi {
    private final noalias protocol p_below {
        cbegin.
            ![
                !<double[]>.
                ?(double[])
            ]*
    }

    private final noalias protocol p_left {
        sbegin.
            ?(int).          // Nr of nodes
            ?(int).          // Sz of array
            ?(double[]).     // fixed bounds
            ?[
                ?(double[]). // left column->
                !<double[]>. // <-left column
                !<Checkconv> // Converged?
            ]*
    }

    public void run(String belowHost, int belowPort, int leftPort) {
        final noalias SJService belowNode = SJService.create(p_below, belowHost, belowPort);

        final noalias SJServerSocket leftNode;

        final noalias SJSocket below, left;


        double[] quadBounds = new double[4];

        int nrOfNodes, arraySize;

        double[][] matrix;
        double[][] tempMatrix;

        double[] bottomRow;
        double[] leftColumn;

        double[] leftColumn_received;

        Checkconv cc = new Checkconv();

        try (leftNode) {
            leftNode  = SJServerSocketImpl.create(p_left, leftPort);

            try (below, left) {
                below = belowNode.request();
                left = leftNode.accept();

                nrOfNodes = left.receiveInt();
                arraySize = left.receiveInt();
                quadBounds = (double[])left.receive();

                // Initialise after the details are forwarded
                matrix     = new double[arraySize+2][arraySize+2];
                tempMatrix = new double[arraySize+2][arraySize+2];

                bottomRow   = new double[arraySize];
                leftColumn  = new double[arraySize];

                leftColumn_received = new double[arraySize];


                init(matrix, tempMatrix, quadBounds[BOUND_TOP], quadBounds[BOUND_RIGHT], 0.0f, 0.0f);

                below.outwhile(left.inwhile()) {
                    cc = iterate(matrix, tempMatrix, arraySize);

                    for (int i=0; i<arraySize; ++i) {
                        bottomRow[i]  = tempMatrix[arraySize][i+1];
                        leftColumn[i] = tempMatrix[i+1][1];
                    }

                    leftColumn_received = (double[])left.receive();
                    left.send(leftColumn);
                    left.send(cc);

                    below.send(bottomRow);
                    bottomRow = (double[])below.receive(); // Note: reused

                    for (int i=0; i<arraySize; ++i) {
                        tempMatrix[arraySize+1][i+1] = bottomRow[i];
                        tempMatrix[i+1][0]           = leftColumn_received[i];
                    }

                    double[][] tmp;
                    tmp = matrix;
                    matrix = tempMatrix;
                    tempMatrix = tmp;
                }

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[WorkerNorthEast] Non-dual behaviour: "+ise);

            } catch (SJIOException ioe) {

                System.err.println("[WorkerNorthEast] Communication error: "+ioe);

            } catch (ClassNotFoundException cnfe) {

                System.err.println("[WorkerNorthEast] Class not found: "+cnfe);

            } finally {} // Sockets
        } catch (SJIOException ioe) {

            System.err.println("[WorkerNorthEast] Communication error: "+ioe);

        } finally {}
    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);

        String belowHost = config.get("below.host");
        int belowPort = Integer.parseInt(config.get("below.port"));

        int leftPort = Integer.parseInt(config.get("left.port"));

        (new WorkerNorthEast()).run(belowHost, belowPort, leftPort);
    }
}

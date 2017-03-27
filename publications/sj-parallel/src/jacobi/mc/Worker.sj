//$ sessionjc -cp lib -d lib src/jacobi/mc/Worker.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.mc.Worker mesh.yaml worker

package jacobi.mc;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * Worker node of Jacobi method implementation.
 *
 * Worker nodes are non-edge nodes in a 2D-mesh
 * topology and connected to 4 (Worker) nodes:
 *  1. from Worker node above
 *  2. to   Worker node right
 *  3. to   Worker node below
 *  4. from Worker node left
 */
public class Worker extends Jacobi {
    private final noalias protocol p_above {
        sbegin.
            ?[
                ?(double[]).
                !<double[]>
            ]*
    }

    private final noalias protocol p_right {
        cbegin.
            !<int>.          // Nr of nodes
            !<int>.          // Sz of array
            !<double[]>.     // fixed bounds
            ![
                !<double[]>. // right row->
                ?(double[]). // <-right row
                ?(Checkconv)
            ]*
    }

    private final noalias protocol p_below { ^(p_above) }

    private final noalias protocol p_left { ^(p_right) }

    public void run(int abovePort, String rightHost, int rightPort, String belowHost, int belowPort, int leftPort) {
        final noalias SJService rightNode = SJService.create(p_right, rightHost, rightPort);
        final noalias SJService belowNode = SJService.create(p_below, belowHost, belowPort);

        final noalias SJServerSocket aboveNode;
        final noalias SJServerSocket leftNode;

        final noalias SJSocket above, right, below, left;


        double[] quadBounds = new double[4];

        int nrOfNodes, arraySize;

        double[][] matrix;
        double[][] tempMatrix;

        double[] topRow;
        double[] rightColumn;
        double[] bottomRow;
        double[] leftColumn;

        double[] topRow_received;
        double[] leftColumn_received;

        Checkconv cc = new Checkconv();
        Checkconv ccRight = new Checkconv();

        try (aboveNode, leftNode) {
            aboveNode = SJServerSocketImpl.create(p_above, abovePort);
            leftNode  = SJServerSocketImpl.create(p_left, leftPort);

            try (above, right, below, left) {
                above = aboveNode.accept();
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

                topRow      = new double[arraySize];
                rightColumn = new double[arraySize];
                bottomRow   = new double[arraySize];
                leftColumn  = new double[arraySize];

                topRow_received = new double[arraySize];
                leftColumn_received = new double[arraySize];


                init(matrix, tempMatrix, 0.0f, 0.0f, 0.0f, 0.0f);

                <right, below>.outwhile(<above, left>.inwhile()) {
                    cc = iterate(matrix, tempMatrix, arraySize);

                    for (int i=0; i<arraySize; ++i) {
                        topRow[i]      = tempMatrix[1][i+1];
                        rightColumn[i] = tempMatrix[i+1][arraySize];
                        bottomRow[i]   = tempMatrix[arraySize][i+1];
                        leftColumn[i]  = tempMatrix[i+1][1];
                    }

                    topRow_received = (double[])above.receive();
                    above.send(topRow);

                    leftColumn_received = (double[])left.receive();
                    left.send(leftColumn);

                    right.send(rightColumn);
                    rightColumn = (double[])right.receive(); // Note: reused
                    ccRight = (Checkconv)right.receive();

                    below.send(bottomRow);
                    bottomRow = (double[])below.receive(); // Note: reused

                    for (int i=0; i<arraySize; ++i) {
                        tempMatrix[0][i+1]           = topRow_received[i];
                        tempMatrix[i+1][arraySize+1] = rightColumn[i];
                        tempMatrix[arraySize+1][i+1] = bottomRow[i];
                        tempMatrix[i+1][0]           = leftColumn_received[i];
                    }

                    double[][] tmp;
                    tmp = matrix;
                    matrix = tempMatrix;
                    tempMatrix = tmp;

                    left.send(ccRight);
                }

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[Worker] Non-dual behaviour: "+ise);

            } catch (SJIOException ioe) {

                System.err.println("[Worker] Communication error: "+ioe);

            } catch (ClassNotFoundException cnfe) {

                System.err.println("[Worker] Class not found: "+cnfe);

            } finally {} // Sockets
        } catch (SJIOException ioe) {

            System.err.println("[Worker] Communication error: "+ioe);

        } finally {}
    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);
        int abovePort = Integer.parseInt(config.get("above.port"));

        String rightHost = config.get("right.host");
        int rightPort = Integer.parseInt(config.get("right.port"));

        String belowHost = config.get("below.host");
        int belowPort = Integer.parseInt(config.get("below.port"));

        int leftPort = Integer.parseInt(config.get("left.port"));

        (new Worker()).run(abovePort, rightHost, rightPort, belowHost, belowPort, leftPort);
    }
}

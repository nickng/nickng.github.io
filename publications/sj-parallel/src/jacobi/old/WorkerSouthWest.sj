//$ sessionjc -cp lib -d lib src/jacobi/old/WorkerSouthWest.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.old.WorkerSouthWest mesh.yaml southwest

package jacobi.old;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * SouthWest Worker node of Jacobi method implementation.
 *
 * SouthEast Worker node is the unique node at the 
 * bottom-left corner of the mesh topology:
 *  1. connected from last West-Worker node (above)
 *  2. connected to first South-worker node (right)
 */
public class WorkerSouthWest extends Jacobi {
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

    public void run(int abovePort, String rightHost, int rightPort) {
        final noalias SJService rightNode = SJService.create(p_right, rightHost, rightPort);

        final noalias SJServerSocket aboveNode;
        final noalias SJSocket above, right;


        double[] quadBounds = new double[4];

        int nrOfNodes, arraySize;

        double[][] matrix;
        double[][] tempMatrix;

        double[] topRow;
        double[] rightColumn;

        double[] topRow_received;

        Checkconv cc = new Checkconv();
        Checkconv ccRight = new Checkconv();

        try (aboveNode) {
            aboveNode = SJServerSocketImpl.create(p_above, abovePort);

            try (above, right) {
                above = aboveNode.accept();
                right = rightNode.request();

                nrOfNodes = above.receiveInt();
                arraySize = above.receiveInt();
                quadBounds = (double[])above.receive();

                right.send(nrOfNodes);
                right.send(arraySize);
                right.send(quadBounds);

                // Initialise after the details are forwarded
                matrix     = new double[arraySize+2][arraySize+2];
                tempMatrix = new double[arraySize+2][arraySize+2];

                topRow      = new double[arraySize];
                rightColumn = new double[arraySize];

                topRow_received = new double[arraySize];


                init(matrix, tempMatrix, 0.0f, 0.0f, quadBounds[BOUND_BOTTOM], quadBounds[BOUND_LEFT]);

                right.outwhile(above.inwhile()) {
                    cc = iterate(matrix, tempMatrix, arraySize);

                    for (int i=0; i<arraySize; ++i) {
                        topRow[i]      = tempMatrix[1][i+1];
                        rightColumn[i] = tempMatrix[i+1][arraySize];
                    }

                    topRow_received = (double[])above.receive();
                    above.send(topRow);

                    right.send(rightColumn);
                    rightColumn = (double[])right.receive(); // Note: reused

                    for (int i=0; i<arraySize; ++i) {
                        tempMatrix[0][i+1]           = topRow_received[i];
                        tempMatrix[i+1][arraySize+1] = rightColumn[i];
                    }

                    double[][] tmp;
                    tmp = matrix;
                    matrix = tempMatrix;
                    tempMatrix = tmp;

                    ccRight  = (Checkconv)right.receive();

                    cc.diff = Math.max( cc.diff, ccRight.diff );
                    cc.valmx = Math.max( cc.valmx, ccRight.valmx );

                    above.send(cc);
                }

                //printMatrixContent(matrix);

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[WorkerSouthWest@{above,right}] Non-dual behaviour: "+ise);

            } catch (SJIOException ioe) {

                System.err.println("[WorkerSouthWest@{above,right}] Communication error: "+ioe);
                System.err.println("Time: "+System.currentTimeMillis());

            } catch (ClassNotFoundException cnfe) {

                System.err.println("[WorkerSouthWest@{above,right}] Class not found: "+cnfe);

            } finally {} // Sockets

        } catch (SJIOException ioe) {

            System.err.println("[WorkerSouthWest@{aboveNode}] Communication error: "+ioe);

        } finally {}
    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);
        int abovePort = Integer.parseInt(config.get("above.port"));

        String rightHost = config.get("right.host");
        int rightPort = Integer.parseInt(config.get("right.port"));

        (new WorkerSouthWest()).run(abovePort, rightHost, rightPort);
    }
}

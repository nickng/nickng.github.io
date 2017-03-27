//$ sessionjc -cp lib -d lib src/jacobi/mc/WorkerSouthEast.sj
//$ sessionj  -cp lib:lib/jyaml.jar jacobi.mc.WorkerSouthEast mesh.yaml southeast

package jacobi.mc;

import java.io.*;
import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;

import jacobi.Jacobi;
import jacobi.Checkconv;

/**
 * SouthEast Worker node of Jacobi method implementation.
 *
 * SouthEast Worker node is the unique sink node and is
 * the bottom-right corner of the mesh topology:
 *  1. connected from last East-Worker node (above)
 *  2. connected from last South-worker node (left)
 */
public class WorkerSouthEast extends Jacobi {
    private final noalias protocol p_above {
        sbegin.
            ?[
                ?(double[]).
                !<double[]>
            ]*
    }

    private final noalias protocol p_left {
        sbegin.
            ?(int).          // Nr of nodes
            ?(int).          // Sz of array
            ?(double[]).     // fixed bounds
            ?[
                ?(double[]). // <-right row
                !<double[]>. // right row->
                !<Checkconv> // Converged?
            ]*
    }

    public void run(int abovePort, int leftPort) {
        final noalias SJServerSocket aboveNode;
        final noalias SJServerSocket leftNode;

        final noalias SJSocket above, left;


        double[] quadBounds = new double[4];

        int nrOfNodes, arraySize;

        double[][] matrix;
        double[][] tempMatrix;

        double[] topRow;
        double[] leftColumn;

        double[] topRow_received;
        double[] leftColumn_received;

        Checkconv cc = new Checkconv();
        Checkconv ccBelow = new Checkconv();
        Checkconv ccRight = new Checkconv();

        try (aboveNode, leftNode) {
            aboveNode = SJServerSocketImpl.create(p_above, abovePort);
            leftNode  = SJServerSocketImpl.create(p_left, leftPort);

            try (above, left) {
                above = aboveNode.accept();
                left  = leftNode.accept();

                nrOfNodes = left.receiveInt();
                arraySize = left.receiveInt();
                quadBounds = (double[]) left.receive();

                // Initialise after the details are forwarded
                matrix     = new double[arraySize+2][arraySize+2];
                tempMatrix = new double[arraySize+2][arraySize+2];

                topRow      = new double[arraySize];
                leftColumn  = new double[arraySize];

                topRow_received = new double[arraySize];
                leftColumn_received = new double[arraySize];


                init(matrix, tempMatrix, 0.0f, quadBounds[BOUND_RIGHT], quadBounds[BOUND_BOTTOM], 0.0f);

                <above, left>.inwhile() {
                    cc = iterate(matrix, tempMatrix, arraySize);

                    for (int i=0; i<arraySize; ++i) {
                        topRow[i]      = tempMatrix[1][i+1];
                        leftColumn[i]  = tempMatrix[i+1][1];
                    }

                    topRow_received = (double[])above.receive();
                    above.send(topRow);

                    leftColumn_received = (double[])left.receive();
                    left.send(leftColumn);
                    left.send(cc);

                    for (int i=0; i<arraySize; ++i) {
                        tempMatrix[0][i+1]           = topRow_received[i];
                        tempMatrix[i+1][0]           = leftColumn_received[i];
                    }

                    double[][] tmp;
                    tmp = matrix;
                    matrix = tempMatrix;
                    tempMatrix = tmp;
                }

//                printMatrixContent(matrix);

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[WorkerSouthEast] Non-dual behaviour: "+ise);

            } catch (SJIOException ioe) {

                System.err.println("[WorkerSouthEast] Communication error: "+ioe);

            } catch (ClassNotFoundException cnfe) {

                System.err.println("[WorkerSouthEast] Class not found: "+cnfe);

            } finally {} // Sockets
        } catch (SJIOException ioe) {

            System.err.println("[WorkerSouthEast] Communication error: "+ioe);

        } finally {}
    }

    public static void main(String[] args) throws FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);
        int abovePort = Integer.parseInt(config.get("above.port"));

        int leftPort = Integer.parseInt(config.get("left.port"));

        (new WorkerSouthEast()).run(abovePort, leftPort);
    }
}

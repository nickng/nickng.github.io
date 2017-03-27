//$ javac -d lib -cp lib:lib/mpj.jar Mpj.java
//$ mpjrun.sh -cp lib -np 9 jacobi.Mpj size 1 1 1 1

package jacobi;

import java.io.*;
import java.lang.Math;
import java.text.NumberFormat;
import java.util.*;

import mpi.*;

import jacobi.Checkconv;
import sessionj.utils.Log;

/**
 * @author Yiannos Kryftis
 * Modified by Nicholas Ng
 */
public class Mpj extends Jacobi {
    public static void main(String[] args) throws Exception {
        (new Mpj()).run(args);
    }

    public void run(String[] args) {
        int iterations = 0;
        int arraySize, grid;

        Checkconv cc = new Checkconv();
        Checkconv ccRight = new Checkconv();
        Checkconv ccBelow = new Checkconv();

        double[] ccBuf = new double[1];
        boolean[] convBuf = new boolean[1];

        MPI.Init(args);
        int rank = MPI.COMM_WORLD.Rank();
        int size = MPI.COMM_WORLD.Size();
        grid = (int) Math.sqrt(size);
        long time = 0L;

        arraySize = Integer.parseInt(args[3]);
        double topBound  = Double.parseDouble(args[4]);
        double downBound = Double.parseDouble(args[5]);
        double rightBound= Double.parseDouble(args[6]);
        double leftBound = Double.parseDouble(args[7]);

        double[][] matrix     = new double[arraySize+2][arraySize+2]; 
        double[][] tempMatrix = new double[arraySize+2][arraySize+2];
        double[] topRow      = new double[arraySize];
        double[] rightColumn = new double[arraySize];
        double[] bottomRow   = new double[arraySize];
        double[] leftColumn  = new double[arraySize];
        double[] topRow_received      = new double[arraySize];
        double[] rightColumn_received = new double[arraySize];
        double[] bottomRow_received   = new double[arraySize];
        double[] leftColumn_received  = new double[arraySize];
        double[] quadBounds= new double[4];

        quadBounds[BOUND_TOP]   = topBound;
        quadBounds[BOUND_RIGHT] = rightBound;
        quadBounds[BOUND_BOTTOM]= downBound;
        quadBounds[BOUND_LEFT]  = leftBound;

        if (rank == 0) { // Master

            init(matrix, tempMatrix, quadBounds[BOUND_TOP], 0.0f, 0.0f, quadBounds[BOUND_LEFT]);

            time = System.currentTimeMillis();
            while (!convBuf[0] && iterations < MAX_ITERATIONS) {

                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    rightColumn[i] = tempMatrix[i+1][arraySize];
                    bottomRow[i]   = tempMatrix[arraySize][i+1];
                }

                // right.send(rightColumn);
                // rightColumn = (double[])right.receive();
                MPI.COMM_WORLD.Send(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);
                MPI.COMM_WORLD.Recv(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);

                // below.send(bottomRow);
                // bottomRow   = (double[])below.receive();
                MPI.COMM_WORLD.Send(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);
                MPI.COMM_WORLD.Recv(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[i+1][arraySize+1] = rightColumn[i];
                    tempMatrix[arraySize+1][i+1] = bottomRow[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                ++iterations;

                // ccBelow = (Checkconv)below.receive();
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+grid, 10);
                ccBelow.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+grid, 10);
                ccBelow.valmx = ccBuf[0];
                // ccRight = (Checkconv)right.receive();
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.valmx = ccBuf[0];

                cc.diff = Math.max( cc.diff, Math.max( ccBelow.diff, ccRight.diff ) );
                cc.valmx = Math.max( cc.valmx, Math.max( ccBelow.valmx, ccRight.valmx ) );

                convBuf[0] = hasConverged(cc);
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }
        }



        /////////////////////
        //RANK_WORKER_NORTH//
        /////////////////////


        if ((rank/grid) == 0 && rank%grid!=0 && rank%grid!=(grid-1)) { // WorkerNorth

            init(matrix, tempMatrix, quadBounds[BOUND_TOP], 0.0f, 0.0f, 0.0f); 

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                // Send prepare
                for (int i=0; i<arraySize; ++i) {
                    rightColumn[i] = tempMatrix[i+1][arraySize];
                    bottomRow[i]   = tempMatrix[arraySize][i+1];
                    leftColumn[i]  = tempMatrix[i+1][1];
                }

                // right.send(rightColumn);
                // rightColumn = (double[])right.receive(); // Note: reused 
                MPI.COMM_WORLD.Send(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);
                MPI.COMM_WORLD.Recv(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);

                // below.send(bottomRow);
                // bottomRow = (double[])below.receive(); // Note: reused
                MPI.COMM_WORLD.Send(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);
                MPI.COMM_WORLD.Recv(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);

                // leftColumn_received = (double[])left.receive();
                // left.send(leftColumn);
                MPI.COMM_WORLD.Recv(leftColumn_received, 0, arraySize, MPI.DOUBLE, rank-1, 10);
                MPI.COMM_WORLD.Send(leftColumn,          0, arraySize, MPI.DOUBLE, rank-1, 10);


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

                // ccRight = (Checkconv)right.receive();
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.valmx = ccBuf[0];

                cc.diff = Math.max( cc.diff, ccRight.diff );
                cc.valmx = Math.max( cc.valmx, ccRight.valmx );

                // left.send(cc);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }
        }



        //////////////////////////
        //RANK_WORKER_NORTH_EAST//
        //////////////////////////



        if((rank/grid) == 0 && rank%grid==(grid-1) ) { // WorkerNorthEast

            init(matrix, tempMatrix, quadBounds[BOUND_TOP], quadBounds[BOUND_RIGHT], 0.0f, 0.0f);

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    bottomRow[i]  = tempMatrix[arraySize][i+1];
                    leftColumn[i] = tempMatrix[i+1][1];
                }

                // below.send(bottomRow);
                // bottomRow = (double[])below.receive(); // Note: reused
                MPI.COMM_WORLD.Send(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);
                MPI.COMM_WORLD.Recv(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);

                // leftColumn_received = (double[])left.receive();
                // left.send(leftColumn);
                MPI.COMM_WORLD.Recv(leftColumn_received, 0, arraySize, MPI.DOUBLE, rank-1, 10);
                MPI.COMM_WORLD.Send(leftColumn,          0, arraySize, MPI.DOUBLE, rank-1, 10);

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[arraySize+1][i+1] = bottomRow[i];
                    tempMatrix[i+1][0]           = leftColumn_received[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                // left.send(cc);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }
        }


        ///////////////////
        //RANK_WORKER_WEST//
        ////////////////////





        if ((rank%grid) == 0 && rank/grid!=0 && rank/grid!=(grid-1)) { // WorkerWest

            init(matrix, tempMatrix, 0.0f, 0.0f, 0.0f, quadBounds[BOUND_LEFT]);

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    topRow[i]      = tempMatrix[1][i+1];
                    rightColumn[i] = tempMatrix[i+1][arraySize];
                    bottomRow[i]   = tempMatrix[arraySize][i+1];
                }

                // topRow_received = (double[])above.receive();
                // above.send(topRow);
                MPI.COMM_WORLD.Recv(topRow_received, 0, arraySize, MPI.DOUBLE, rank-grid, 10);
                MPI.COMM_WORLD.Send(topRow,          0, arraySize, MPI.DOUBLE, rank-grid, 10);

                // right.send(rightColumn);
                // rightColumn = (double[])right.receive(); // Note: reused
                MPI.COMM_WORLD.Send(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);
                MPI.COMM_WORLD.Recv(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);

                // below.send(bottomRow);
                // bottomRow = (double[])below.receive(); // Note: reused
                MPI.COMM_WORLD.Send(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);
                MPI.COMM_WORLD.Recv(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[0][i+1]           = topRow_received[i];
                    tempMatrix[i+1][arraySize+1] = rightColumn[i];
                    tempMatrix[arraySize+1][i+1] = bottomRow[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                // ccRight = (Checkconv)right.receive();
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.valmx = ccBuf[0];
                // ccBelow = (Checkconv)below.receive();
                MPI.COMM_WORLD.Recv(ccBuf,  0, 1, MPI.DOUBLE, rank+grid, 10);
                ccBelow.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+grid, 10);
                ccBelow.valmx = ccBuf[0];

                cc.diff = Math.max( cc.diff, Math.max( ccBelow.diff, ccRight.diff ) );
                cc.valmx = Math.max( cc.valmx, Math.max( ccBelow.valmx, ccRight.valmx ) );

                // above.send(cc);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-grid, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-grid, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }
        }


        /////////////////////////
        //RANK_WORKER_WEST_SOUTH//
        //////////////////////////




        if ((rank%grid) == 0 && rank/grid==(grid-1)) { //WorkerWestSouth

            init(matrix, tempMatrix, 0.0f, 0.0f, quadBounds[BOUND_BOTTOM], quadBounds[BOUND_LEFT]);

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    topRow[i]      = tempMatrix[1][i+1];
                    rightColumn[i] = tempMatrix[i+1][arraySize];
                }

                // topRow_received = (double[])above.receive();
                // above.send(topRow);
                MPI.COMM_WORLD.Recv(topRow_received, 0, arraySize, MPI.DOUBLE, rank-grid, 10);
                MPI.COMM_WORLD.Send(topRow, 0, arraySize, MPI.DOUBLE, rank-grid, 10);

                // right.send(rightColumn);
                // rightColumn = (double[])right.receive();
                MPI.COMM_WORLD.Send(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);
                MPI.COMM_WORLD.Recv(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10); 

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[0][i+1]           = topRow_received[i];
                    tempMatrix[i+1][arraySize+1] = rightColumn[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                // ccRight  = (Checkconv)right.receive();
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.valmx = ccBuf[0];

                cc.diff = Math.max( cc.diff, ccRight.diff );
                cc.valmx = Math.max( cc.valmx, ccRight.valmx );

                // above.send(cc);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-grid, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-grid, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }

        }


        ////////////////////
        //RANK_WORKER_EAST//
        ////////////////////


        if ((rank%grid) == (grid-1) && rank/grid!=(grid-1) && rank/grid!=0) { // WorkerEast

            init(matrix, tempMatrix, 0.0f, quadBounds[BOUND_RIGHT], 0.0f, 0.0f);

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    topRow[i]     = tempMatrix[1][i+1];
                    leftColumn[i] = tempMatrix[i+1][1];
                    bottomRow[i]  = tempMatrix[arraySize][i+1];
                }

                // topRow_received = (double[])above.receive();
                // above.send(topRow);
                MPI.COMM_WORLD.Recv(topRow_received, 0, arraySize, MPI.DOUBLE, rank-grid, 10);
                MPI.COMM_WORLD.Send(topRow,          0, arraySize, MPI.DOUBLE, rank-grid, 10);

                // below.send(bottomRow);
                // bottomRow = (double[])below.receive(); // Note: reused
                MPI.COMM_WORLD.Send(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);
                MPI.COMM_WORLD.Recv(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);

                // leftColumn_received = (double[])left.receive();
                // left.send(leftColumn);
                MPI.COMM_WORLD.Recv(leftColumn_received, 0, arraySize, MPI.DOUBLE, rank-1, 10);
                MPI.COMM_WORLD.Send(leftColumn,          0, arraySize, MPI.DOUBLE, rank-1, 10);

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[0][i+1]           = topRow_received[i];
                    tempMatrix[i+1][0]           = leftColumn_received[i];
                    tempMatrix[arraySize+1][i+1] = bottomRow[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                // left.send(cc);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }
        }


        ////////////////////
        //RANK_WORKER_SOUTH//
        /////////////////////


        if ((rank/grid) == (grid-1) && rank%grid!=0 && rank%grid!=(grid-1)) { // WorkerSouth

            init(matrix, tempMatrix, 0.0f, 0.0f, quadBounds[BOUND_BOTTOM], 0.0f);

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    topRow[i]      = tempMatrix[1][i+1];
                    rightColumn[i] = tempMatrix[i+1][arraySize];
                    leftColumn[i]  = tempMatrix[i+1][1];
                }

                // topRow_received = (double[])above.receive();
                // above.send(topRow);
                MPI.COMM_WORLD.Recv(topRow_received, 0, arraySize, MPI.DOUBLE, rank-grid, 10);
                MPI.COMM_WORLD.Send(topRow,          0, arraySize, MPI.DOUBLE, rank-grid, 10);

                // right.send(rightColumn);
                // rightColumn = (double[])right.receive();
                MPI.COMM_WORLD.Send(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);
                MPI.COMM_WORLD.Recv(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);

                // leftColumn_received = (double[])left.receive();
                // left.send(leftColumn);
                MPI.COMM_WORLD.Recv(leftColumn_received, 0, arraySize, MPI.DOUBLE, rank-1, 10);
                MPI.COMM_WORLD.Send(leftColumn,          0, arraySize, MPI.DOUBLE, rank-1, 10);

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[0][i+1]           = topRow_received[i];
                    tempMatrix[i+1][arraySize+1] = rightColumn[i];
                    tempMatrix[i+1][0]           = leftColumn_received[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                // ccRight = (Checkconv)right.receive();
                MPI.COMM_WORLD.Recv(ccBuf,  0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.valmx = ccBuf[0];

                cc.diff = Math.max( cc.diff, ccRight.diff );
                cc.valmx = Math.max( cc.valmx, ccRight.valmx );

                // left.send(cc);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }

        }


        /////////////////////////
        //RANK_WORKER_EAST_SOUTH//
        //////////////////////////


        if (rank==size-1) { // WorkerEastSouth

            init(matrix, tempMatrix, 0.0f, quadBounds[BOUND_RIGHT], quadBounds[BOUND_BOTTOM], 0.0f);

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    topRow[i]      = tempMatrix[1][i+1];
                    leftColumn[i]  = tempMatrix[i+1][1];
                }

                // topRow_received = (double[])above.receive();
                // above.send(topRow);
                MPI.COMM_WORLD.Recv(topRow_received, 0, arraySize, MPI.DOUBLE, rank-grid, 10);
                MPI.COMM_WORLD.Send(topRow,          0, arraySize, MPI.DOUBLE, rank-grid, 10);

                // leftColumn_received = (double[])left.receive();
                // left.send(leftColumn);
                MPI.COMM_WORLD.Recv(leftColumn, 0, arraySize, MPI.DOUBLE, rank-1, 10);
                MPI.COMM_WORLD.Send(leftColumn, 0, arraySize, MPI.DOUBLE, rank-1, 10);

                for (int i=0; i<arraySize; ++i) {
                    tempMatrix[0][i+1] = topRow_received[i];
                    tempMatrix[i+1][0] = leftColumn_received[i];
                }

                double[][] tmp;
                tmp = matrix;
                matrix = tempMatrix;
                tempMatrix = tmp;

                // left.send(cc);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }
        }


        //////////////
        //RANK_WORKER//
        ///////////////

        if(rank/grid!=0 && rank/grid!=(grid-1) && rank%grid!=0 && rank%grid!=(grid-1)) { // Worker

            init(matrix, tempMatrix, 0.0f, 0.0f, 0.0f, 0.0f);

            while (!convBuf[0] && iterations < MAX_ITERATIONS) {
                cc = iterate(matrix, tempMatrix, arraySize);

                for (int i=0; i<arraySize; ++i) {
                    topRow[i]      = tempMatrix[1][i+1];
                    rightColumn[i] = tempMatrix[i+1][arraySize];
                    bottomRow[i]   = tempMatrix[arraySize][i+1];
                    leftColumn[i]  = tempMatrix[i+1][1];
                }

                // topRow_received = (double[])above.receive();
                // above.send(topRow);
                MPI.COMM_WORLD.Recv(topRow_received, 0, arraySize, MPI.DOUBLE, rank-grid, 10);
                MPI.COMM_WORLD.Send(topRow,          0, arraySize, MPI.DOUBLE, rank-grid, 10);

                // right.send(rightColumn);
                // rightColumn = (double[])right.receive(); // Note: reused
                MPI.COMM_WORLD.Send(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);
                MPI.COMM_WORLD.Recv(rightColumn, 0, arraySize, MPI.DOUBLE, rank+1, 10);

                // below.send(bottomRow);
                // bottomRow = (double[])below.receive(); // Note: reused
                MPI.COMM_WORLD.Send(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);
                MPI.COMM_WORLD.Recv(bottomRow, 0, arraySize, MPI.DOUBLE, rank+grid, 10);

                // leftColumn_received = (double[])left.receive();
                // left.send(leftColumn);
                MPI.COMM_WORLD.Send(leftColumn_received, 0, arraySize, MPI.DOUBLE, rank-1, 10);
                MPI.COMM_WORLD.Recv(leftColumn,          0, arraySize, MPI.DOUBLE, rank-1, 10);


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

                // ccRight = (Checkconv)right.receive();
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.diff = ccBuf[0];
                MPI.COMM_WORLD.Recv(ccBuf, 0, 1, MPI.DOUBLE, rank+1, 10);
                ccRight.valmx = ccBuf[0];

                // left.send(ccRight);
                ccBuf[0] = cc.diff;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);
                ccBuf[0] = cc.valmx;
                MPI.COMM_WORLD.Send(ccBuf, 0, 1, MPI.DOUBLE, rank-1, 10);

                ++iterations;
                MPI.COMM_WORLD.Bcast(convBuf, 0, 1, MPI.BOOLEAN, 0);
            }
        }

        MPI.COMM_WORLD.Barrier();
        MPI.Finalize();    

        if (0 == rank) {
            if (hasConverged(cc)) {

                Log.i("jacobi-ver=MPJ arraySz="+arraySize, "End of calculation (reason: Master converged, iterations="+iterations+", Convergence parameter="+cc+").");

            } else if (iterations >= MAX_ITERATIONS) {

                Log.i("jacobi-ver=MPJ arraySz="+arraySize, "End of calculation (reason: MAX_ITERATIONS("+MAX_ITERATIONS+") reached cc="+cc+").");

            }

            Log.b("jacobi-ver=MPJ arraySz="+arraySize, ""+(System.currentTimeMillis() - time));
        }

    }
}

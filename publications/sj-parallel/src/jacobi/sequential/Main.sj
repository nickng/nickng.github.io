//$ sessionjc -cp lib -d lib src/jacobi/sequential/Main.sj
//$ sessionj  -cp lib jacobi.sequential.Main 3 1.0 1.0 1.0 1.0

package jacobi.sequential;

import java.io.*;
import java.util.Arrays;

import jacobi.Jacobi;
import jacobi.Checkconv;

public class Main extends Jacobi {

    public void run(double topBound, double rightBound, double belowBound, double leftBound, int arraySize) {
        double[][] matrix     = new double[arraySize+2][arraySize+2];
        double[][] tempMatrix = new double[arraySize+2][arraySize+2];

        init(matrix, tempMatrix, topBound, rightBound, belowBound, leftBound);
        long time = System.currentTimeMillis();

        Checkconv cc = new Checkconv();
        int iterations = 0;
        while (!hasConverged(cc) && iterations <= MAX_ITERATIONS) {
            cc = iterate(matrix, tempMatrix, arraySize);

            double[][] tmp;
            tmp = matrix;
            matrix = tempMatrix;
            tempMatrix = tmp;

            ++iterations;
        }

        if (hasConverged(cc)) {

            //System.out.println("End of calculation (reason: converged, iterations="+iterations+", Convergence parameter="+cc+").");
            //printMatrixContent(matrix);

        } else if (iterations > MAX_ITERATIONS) {

            System.out.println("End of calculation (reason: MAX_ITERATIONS reached, Convergence parameter="+cc+").");

        }
        System.out.println(System.currentTimeMillis() - time);
        //printMatrixContent(matrix);
    }

    public static void main(String[] args) {
        int arraySize = Integer.parseInt(args[0]);

        double topBound = Double.parseDouble(args[1]);
        double rightBound = Double.parseDouble(args[2]);
        double downBound = Double.parseDouble(args[3]);
        double leftBound = Double.parseDouble(args[4]);

        (new Main()).run(topBound, rightBound, downBound, leftBound, arraySize);
    }
}

//$ javac -d lib -cp lib:lib/mpj.jar Mpj.java
//$ mpjrun.sh -cp lib -dev niodev -np 3 nbody.Mpj 10 10 false

package nbody;

import java.io.*;
import java.lang.Math;
import java.text.NumberFormat;
import java.util.*;

import mpi.*;

import nbody.Particle;
import nbody.ParticleV;
import sessionj.utils.Log;

public class Mpj extends NBody {
    private double[][] toReceive;
    private double[][] toSent;

    public static void main(String[] args) throws Exception {
        new Mpj().run(args);
    }

    public void run(String[] args) throws Exception {

        MPI.Init(args);

        int rank = MPI.COMM_WORLD.Rank();
        int size = MPI.COMM_WORLD.Size();
        long time = 0L;

        int numParticles = Integer.parseInt(args[3]);
        int iterations   = Integer.parseInt(args[4]);
        boolean debug    = Boolean.parseBoolean(args[5]);
        Particle[] particles = new Particle[numParticles];
        ParticleV[] pvs      = new ParticleV[numParticles];
        init(particles, pvs, rank);

        if (rank==0) {
            time = System.currentTimeMillis();
        }

        int i = 0;
        while (i<iterations) {
            if (debug) {
                System.out.println("\nIteration: " + i);
                System.out.println("Particles: " + Arrays.toString(particles));
            }	

            Particle[] current = new Particle[numParticles];
            Particle[] recvbuf = new Particle[numParticles*size];
            System.arraycopy(particles, 0, current, 0, numParticles);

            MPI.COMM_WORLD.Allgather(current, 0, numParticles, MPI.OBJECT, recvbuf, 0, numParticles , MPI.OBJECT);
            computeForces(particles, recvbuf, pvs);
            computePositions(particles, pvs, i);

            i++;
        }

        MPI.COMM_WORLD.Barrier();
        MPI.Finalize();

        if (rank==0) {
            Log.b("nbody-ver=MPJ particles="+numParticles+",iter="+iterations, ""+(System.currentTimeMillis() - time));
        }

    }
}

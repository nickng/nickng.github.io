//$ sessionjc -cp lib -d lib src/nbody/sequential/Main.sj
//$ sessionj -cp lib nbody.sequential.Main 30 10

package nbody.sequential;

import java.io.*;

import nbody.NBody;
import nbody.Particle;
import nbody.ParticleV;

/**
 * Sequantial version of NBody simulation
 * as correctness check.
 */
public class Main extends NBody {
    public void run(int nrOfParticles, int nrOfIterations) {
        Particle[] particles     = new Particle[nrOfParticles];
        Particle[] tempParticles = new Particle[nrOfParticles];
        ParticleV[] pvs = new ParticleV[nrOfParticles];

        init(particles, pvs, 0);
        System.arraycopy(particles, 0, tempParticles, 0, nrOfParticles);

        for (int i=0; i<nrOfIterations; ++i) {
            computeForces(particles, tempParticles, pvs);
            computePositions(particles, pvs, i);
        }

    }

    public static void main(String[] args) {
        int nrOfParticles  = Integer.parseInt(args[0]);
        int nrOfIterations = Integer.parseInt(args[1]);

        new Main().run(nrOfParticles, nrOfIterations);
    }
}

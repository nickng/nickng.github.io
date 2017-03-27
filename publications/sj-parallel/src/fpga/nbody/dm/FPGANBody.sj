//$ sessionjc -cp lib:./jna.jar src/nbody/dm/FPGANBody.sj -d lib
//$ 

package nbody.dm;

import nbody.NBody;
import nbody.Particle;
import nbody.ParticleV;

import com.sun.jna.Native;

/*
 * FPGANBody
 * FPGA-based NBody implementation
 */
public class FPGANBody extends NBody {
    public FPGANBody () {
        Native.register(System.getProperty("user.dir")+"/lib/libnbody_fpga.so");
    }

    public static native void begin_compute_forces(int nr_of_particles);
    public static native ParticleV compute_force(Particle particle, Particle tempParticle, ParticleV pv);
    public static native boolean initialise(String filename, float freq);
    public static native void freeall();
    public static native int finalise();
    public static native void cleanup();

    public static boolean initialised = false;

    public void prepare() {
        if (initialise("admxrc5t2.bit", 250.0f)) {
            cleanup();
            System.exit(1);
        }
        FPGANBody.initialised = true;
    }


    public void computeForces(Particle[] particles, Particle[] tempParticles, ParticleV[] pvs) {
        int size = particles.length;

        begin_compute_forces(size);
        for (int i=0; i<size-1; ++i) {
            compute_force(particles[i], tempParticles[i], pvs[i]);
        }

        ParticleV pv = compute_force(particles[size-1], tempParticles[size-1], pvs[size-1]);
        ParticleV[] results = (ParticleV[]) pv.toArray(size);
        for (int i=0; i<size; ++i) {
            pvs[i].ai = results[i].ai;
            pvs[i].aj = results[i].aj;
        }
        freeall();
	}


    public void finish() {
        finalise();
        cleanup();
    }
}


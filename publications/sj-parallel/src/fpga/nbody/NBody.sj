//$ sessionjc -cp lib:./jna.jar src/nbody/NBody.sj -d lib
//$

package nbody;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.PrintStream;
import java.util.Scanner;

public abstract class NBody {
    public void prepare() {}
    public void init(Particle[] particles, ParticleV[] pvs, int nodeIndex) {
        double m, x, y, vi, vj;
        int lineBegin = (nodeIndex * pvs.length) % 81920;
        int currentLine = 0;

        Scanner sc = null;
        try {
            sc = new Scanner(new BufferedReader(new FileReader(System.getProperty("user.dir")+"/input/particles.txt")));
        } catch (FileNotFoundException fnfe) {
            System.err.println("Cannot read input file, exiting.");
            System.exit(1);
        }

        // skip
        // TODO: Seek instead of this
        while (currentLine++ < lineBegin) {
            sc.nextLine();
        }

        for (int i=0; i<pvs.length; ++i) {
            m = sc.nextDouble();
            x = sc.nextDouble();
            y = sc.nextDouble();
            vi = sc.nextDouble();
            vj = sc.nextDouble();

            particles[i] = new Particle();
            particles[i].m = m;
            particles[i].x = x;
            particles[i].y = y;

            pvs[i] = new ParticleV();
            pvs[i].vi_old = vi;
            pvs[i].vi_old = vj;
            pvs[i].ai_old = 0.0f;
            pvs[i].aj_old = 0.0f;
            pvs[i].ai = 0.0f;
            pvs[i].aj = 0.0f;

            if (!sc.hasNext()) {
                sc.close();
                try {
                    sc = new Scanner(new BufferedReader(new FileReader(System.getProperty("user.dir")+"/input/particles.txt")));
                } catch (FileNotFoundException fnfe) {
                    System.err.println("Cannot read input file, exiting.");
                    System.exit(1);
                }
            }
        }
    }

    public void storeResults(Particle[] particles, int nodeIndex) {
        FileOutputStream out = null;
        PrintStream p = null;;
        try {
            // TODO: Add PID or some unique identifier (timestamp?)
            out = new FileOutputStream(System.getProperty("user.dir")+"/output/"+nodeIndex+"-particles.out");
            p = new PrintStream(out);
        } catch (Exception e) {
            System.err.println("storeResults failed");
            e.printStackTrace();
        }
        for (int i=0; i<particles.length; ++i) {
            p.println(particles[i].x+" "+particles[i].y);
        }
    }

    public abstract void computeForces(Particle[] particles, Particle[] current, ParticleV[] pvs);

    public void computePositions(Particle[] particles, ParticleV[] pvs, int step) {
        double dt = 1.0;

        for(int i = 0; i < particles.length; i++) {
            Particle p = particles[i]; 
            ParticleV pv = pvs[i];

            double x = p.x;
            double y = p.y;

            double ai_old = pv.ai_old;
            double aj_old = pv.aj_old;                      
            double ai = pv.ai;
            double aj = pv.aj;

            // At this point we have p_n, a_n.
            // We also have v_n-1  and a_n-1 (except for n = 0).
            // So need to work out v_n (except for n = 0).

            double vi_old = pv.vi_old;
            double vj_old = pv.vj_old;          
            double vi;
            double vj;

            if (0 == step) { // Only in the first iteration do we use the stored velocity values..

                vi = vi_old; 
                vj = vj_old;

            } else {         // ...otherwise we calculate the current velocities.

                vi = vi_old + ((ai + ai_old) * dt / 2);
                vj = vj_old + ((aj + aj_old) * dt / 2);

            }

            p.x = x + (vi * dt) + (ai * dt * dt / 2);  
            p.y = y + (vj * dt) + (aj * dt * dt / 2);           

            pv.vi_old = vi;
            pv.vj_old = vj;

            pv.ai_old = ai;
            pv.aj_old = aj;
            pv.ai = 0.0;
            pv.aj = 0.0;
        }
    }
    public void finish() {}
}

//$ sessionjc -cp lib:lib/jyaml.jar -d lib src/nbody/mc/Head.sj
//$ sessionj  -cp lib:lib/jyaml.jar nbody.mc.Head ring.yaml head 270 10

package nbody.mc;

import java.io.FileNotFoundException;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;
import sessionj.utils.Log;

import nbody.NBody;
import nbody.Particle;
import nbody.ParticleV;

public class Head extends NBody {
    //                                     #nodes
    final noalias protocol p_next { cbegin.?(int).!<int>.![![!<Particle[]>]*]* }
    final noalias protocol p_tail { cbegin.![![?(Particle[])]*]* }

    public void run(String nextHost, int nextPort, String tailHost, int tailPort, int size, int iterCount) throws ClassNotFoundException {

        final noalias SJService nextNode = SJService.create(p_next, nextHost, nextPort);
        final noalias SJService tailNode = SJService.create(p_tail, tailHost, tailPort);
        final noalias SJSocket next;
        final noalias SJSocket tail;

        Particle[] particles = null;
        ParticleV[] pvs = null;

        int i = 0, j = 0;
        int nodesCount = 0; // Number of processsing nodes

        long time = 0L;

        try (next,tail) {

            next = nextNode.request();
            tail = tailNode.request();

            // Find the number of nodes
            nodesCount = next.receiveInt();
            next.send(size);

            particles = new Particle[size];
            pvs = new ParticleV[size];

            init(particles, pvs, nodesCount);

            time = System.currentTimeMillis();

            // Synchronised ring
            i = 0;
            <next,tail>.outwhile(i < iterCount) {

                // This round
                Particle[] tempParticles = new Particle[size];
                System.arraycopy(particles, 0, tempParticles, 0, size);

                // Pump particles through the ring
                j = 0;
                <next,tail>.outwhile(j < nodesCount) {
                    next.send(tempParticles); // Send it into the ring
                    computeForces(particles, tempParticles, pvs); // Calculate current set
                    tempParticles = (Particle[]) tail.receive(); // Receive from the other end of the ring

                    ++j;
                }

                computeForces(particles, tempParticles, pvs);
                computePositions(particles, pvs, i);

                ++i;
            }

        } catch (SJIncompatibleSessionException ise) {

            System.err.println("[Head] Non-dual behaviour: " + ise);

        } catch (SJIOException sioe) {

            System.err.println("[Head] Communication error: " + sioe);

        } finally { }

        Log.b("nbody-ver=MC particles="+size+",iter="+iterCount, ""+(System.currentTimeMillis() - time));

    }

    public static void main(String[] args) throws ClassNotFoundException, FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);

        String nextHost = config.get("next.host");
        int nextPort = Integer.parseInt(config.get("next.port"));

        String tailHost = config.get("tail.host");
        int tailPort = Integer.parseInt(config.get("tail.port"));

        int nrOfParticles = Integer.parseInt(args[2]);
        int nrOfIterations = Integer.parseInt(args[3]);

        new Head().run(nextHost, nextPort, tailHost, tailPort, nrOfParticles, nrOfIterations);
    }
}

//$ sessionjc -cp lib:lib/jyaml.jar -d lib src/nbody/old/Head.sj
//$ sessionj  -cp lib:lib/jyaml.jar nbody.old.Head ring.yaml head 270 10

package nbody.old;

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
    final noalias protocol p_tail { cbegin.?(Particle[]) }

    public void run(String nextHost, int nextPort, String tailHost, int tailPort, int size, int iterCount) throws ClassNotFoundException {

        final noalias SJService nextNode = SJService.create(p_next, nextHost, nextPort);
        final noalias SJService tailNode = SJService.create(p_tail, tailHost, tailPort);
        final noalias SJSocket next;
        noalias SJSocket tail;

        Particle[] particles = null;
        ParticleV[] pvs = null;

        int i = 0, j = 0;
        int nodesCount = 0; // Number of processsing nodes

        long time = 0L;

        try (next) {

            time = System.currentTimeMillis();
            next = nextNode.request();

            // Find the number of nodes
            nodesCount = next.receiveInt();
            next.send(size);

            particles = new Particle[size];
            pvs = new ParticleV[size];

            init(particles, pvs, nodesCount);

            // Synchronised ring
            i = 0;
            next.outwhile(i < iterCount) {

                // This round
                Particle[] tempParticles = new Particle[size];
                System.arraycopy(particles, 0, tempParticles, 0, size);

                // Pump particles through the ring
                j = 0;
                next.outwhile(j < nodesCount) {
                    next.send(tempParticles); // Send it into the ring
                    computeForces(particles, tempParticles, pvs); // Calculate current set

                    try (tail) {

                        tail = tailNode.request();
                        tempParticles = (Particle[])tail.receive(); // Receive from the other end of the ring

                    } catch (SJIncompatibleSessionException ise) {

                        System.err.println("[Head@{tail}] Non-dual behaviour: "+ise);

                    } catch (SJIOException ioe) {

                        System.err.println("[Head@{tail}] Communication error: "+ioe);

                    } catch (ClassNotFoundException cnfe) {

                        System.err.println("[Head@{tail}] Class not found: "+cnfe);

                    } finally {} // Sockets

                    ++j;
                }

                computeForces(particles, tempParticles, pvs);
                computePositions(particles, pvs, i);

                ++i;
            }

        } catch (SJIncompatibleSessionException ise) {

            System.err.println("[Head@{next}] Non-dual behaviour: " + ise);

        } catch (SJIOException sioe) {

            System.err.println("[Head@{next}] Communication error: " + sioe);

        } finally { }

        Log.b("nbody-ver=Old particles="+size+",iter="+iterCount, ""+(System.currentTimeMillis() - time));

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

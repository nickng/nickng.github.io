//$ sessionjc -cp lib:lib/jyaml.jar -d lib src/nbody/mc/Body.sj
//$ sessionj  -cp lib:lib/jyaml.jar nbody.mc.Body ring.yaml body

package nbody.mc;

import java.io.FileNotFoundException;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;
import sessionj.utils.Log;

import nbody.NBody;
import nbody.Particle;
import nbody.ParticleV;

public class Body extends NBody {
    //                                     #nodes 
    final noalias protocol p_prev { sbegin.!<int>.?(int).?[?[?(Particle[])]*]* }
    final noalias protocol p_next { ^(p_prev) }

    public void run(int listenPort, String nextHost, int nextPort) throws ClassNotFoundException {

        final noalias SJServerSocket prevNode;
        final noalias SJService nextNode = SJService.create(p_next, nextHost, nextPort);;
        final noalias SJSocket prev;
        final noalias SJSocket next;

        Particle[] particles = null;
        ParticleV[] pvs = null;

        int i = 0;
        int nodeIndex = -1;
        int size;

        try (prevNode) {

            prevNode = SJServerSocketImpl.create(p_prev, listenPort);

            try (prev,next) {

                next = nextNode.request();
                Log.i("nbody.mc.Body", "Connected to next node at "+nextHost+":"+nextPort);
                prev = prevNode.accept();
                Log.i("nbody.mc.Body", "Connected by prev node at :"+listenPort);

                // # of nodes
                nodeIndex = next.receiveInt();
                prev.send(nodeIndex+1);
                size = prev.receiveInt();
                next.send(size);

                particles = new Particle[size];
                pvs = new ParticleV[size];

                init(particles, pvs, nodeIndex);

                next.outwhile(prev.inwhile()) {

                    // This round
                    Particle[] tempParticles = new Particle[size];
                    System.arraycopy(particles, 0, tempParticles, 0, size);

                    // Pump particles through ring
                    next.outwhile(prev.inwhile()) {
                        next.send(tempParticles);
                        computeForces(particles, tempParticles, pvs);
                        tempParticles = (Particle[]) prev.receive();
                    }

                    computeForces(particles, tempParticles, pvs);
                    computePositions(particles, pvs, i);

                    ++i;
                }

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[Body] Non-dual behaviour: " + ise);

            } catch (SJIOException sioe) {

                System.err.println("[Body] Communication error: " + sioe);
            }

        } catch (SJIOException sioe) {

            System.err.println("[Body] Communication error: " + sioe);

        } finally { }

    }

    public static void main(String[] args) throws ClassNotFoundException, FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);

        int prevPort = Integer.parseInt(config.get("prev.port"));

        String nextHost = config.get("next.host");
        int nextPort = Integer.parseInt(config.get("next.port"));

        new Body().run(prevPort, nextHost, nextPort);
    }

}

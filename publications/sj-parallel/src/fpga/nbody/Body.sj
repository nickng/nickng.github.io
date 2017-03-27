//$ sessionjc -cp lib:./jna.jar src/nbody/Body.sj -d lib
//$

package nbody;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

public class Body {
    //                                     #nodes 
    final noalias protocol p_prev { sbegin.!<int>.?[?[?(Particle[])]*]* }
    final noalias protocol p_next { ^(p_prev) }
    NBody nbody;

    /**
     * Constructor, sets NBody implementation
     */
    public Body(NBody nbody) {
        this.nbody = nbody;
    }


    public void run(int listenPort, String nextHost, int nextPort, int size) throws ClassNotFoundException {

        final noalias SJServerSocket prevNode;
        final noalias SJService nextNode = SJService.create(p_next, nextHost, nextPort);;
        final noalias SJSocket prev;
        final noalias SJSocket next;

        Particle[] particles = null;
        ParticleV[] pvs = null;

        int i = 0;
        int nodeIndex = -1;

        nbody.prepare();

        try (prevNode) {

            prevNode = SJServerSocketImpl.create(p_prev, listenPort);

            try (prev,next) {

                next = nextNode.request();
                System.out.println("[Body] Connected to next node at "+nextHost+":"+nextPort);
                prev = prevNode.accept();
                System.out.println("[Body] Connected by prev node at :"+listenPort);

                // # of nodes
                nodeIndex = next.receiveInt();
                prev.send(nodeIndex+1);

                particles = new Particle[size];
                pvs = new ParticleV[size];

                nbody.init(particles, pvs, nodeIndex);

                next.outwhile(prev.inwhile()) {

                    // This round
                    Particle[] tempParticles = new Particle[size];
                    System.arraycopy(particles, 0, tempParticles, 0, size);

                    // Pump particles through ring
                    next.outwhile(prev.inwhile()) {
                        next.send(tempParticles);
                        nbody.computeForces(particles, tempParticles, pvs);
                        tempParticles = (Particle[]) prev.receive();
                    }

                    nbody.computeForces(particles, tempParticles, pvs);
                    nbody.computePositions(particles, pvs, i);

                    ++i;
                }

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[Body] Non-dual behaviour: " + ise);

            } catch (SJIOException sioe) {

                System.err.println("[Body] Communication error: " + sioe);
            }

        } catch (SJIOException sioe) {

            System.err.println("[Body] Communication error: " + sioe);

        } finally { // Close socket
        
            nbody.finish(); // Finalise FPGA etc.

        }

//        nbody.storeResults(particles, nodeIndex);

    }

}

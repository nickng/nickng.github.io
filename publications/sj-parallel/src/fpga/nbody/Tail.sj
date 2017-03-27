//$ sessionjc -cp lib:./jna.jar src/nbody/Tail.sj -d lib
//$

package nbody;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

public class Tail {
    //                                     #nodes 
    final noalias protocol p_prev { sbegin.!<int>.?[?[?(Particle[])]*]* }
    final noalias protocol p_head { sbegin.?[?[!<Particle[]>]*]* }
    NBody nbody;

    /**
     * Constructor, sets NBody implementation
     */
    public Tail(NBody nbody) {
        this.nbody = nbody;
    }


    public void run(int listenPort, int headPort, int size) throws ClassNotFoundException {

        final noalias SJServerSocket prevNode;
        final noalias SJServerSocket headNode;
        final noalias SJSocket prev;
        final noalias SJSocket head;

        Particle[] particles = null;
        ParticleV[] pvs = null;

        int i = 0;

        nbody.prepare();
        
        try (prevNode,headNode) {

            prevNode = SJServerSocketImpl.create(p_prev, listenPort);
            headNode = SJServerSocketImpl.create(p_head, headPort);

            try (prev,head) {

                prev = prevNode.accept();
                System.out.println("[Tail] Connected by prev node at :"+listenPort);
                head = headNode.accept();
                System.out.println("[Tail] Connected by Head node at :"+headPort);

                // # of nodes
                prev.send(1);

                particles = new Particle[size];
                pvs = new ParticleV[size];

                nbody.init(particles, pvs, 0);

                <prev,head>.inwhile() {
                    
                    // This round
                    Particle[] tempParticles = new Particle[size];
                    System.arraycopy(particles, 0, tempParticles, 0, size);

                    // Pump particles through ring
                    <prev,head>.inwhile() {
                        head.send(tempParticles);
                        nbody.computeForces(particles, tempParticles, pvs);
                        tempParticles = (Particle[]) prev.receive();
                    }

                    nbody.computeForces(particles, tempParticles, pvs);
                    nbody.computePositions(tempParticles, pvs, i);

                    ++i;
                }

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[Tail] Non-dual behaviour: " + ise);

            } catch (SJIOException sioe) {

                System.err.println("[Tail] Communication error: " + sioe);
            }

        } catch (SJIOException sioe) {

            System.err.println("[Tail] Communication error: " + sioe);

        } finally { // Close socket

            nbody.finish(); // Finialised FPGA etc.

        }

//        nbody.storeResults(particles, 0);

    }

}

//$ sessionjc -cp lib:./jna.jar src/nbody/Head.sj -d lib
//$

package nbody;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

public class Head {
    //                                     #nodes
    final noalias protocol p_next { cbegin.?(int).![![!<Particle[]>]*]* }
    final noalias protocol p_tail { cbegin.![![?(Particle[])]*]* }
    NBody nbody;

    static long executionTime = 0; // Timekeeping

    /**
     * Constructur, sets NBody implementation
     */
    public Head(NBody nbody) {
        this.nbody = nbody;
    }


    public void run(String nextHost, int nextPort, String tailHost, int tailPort, int size, int iterCount) throws ClassNotFoundException {

        final noalias SJService nextNode = SJService.create(p_next, nextHost, nextPort);
        final noalias SJService tailNode = SJService.create(p_tail, tailHost, tailPort);
        final noalias SJSocket next;
        final noalias SJSocket tail;

        Particle[] particles = null;
        ParticleV[] pvs = null;

        int i = 0, j = 0;
        int nodesCount = 0; // Number of processsing nodes

        nbody.prepare();

        try (next,tail) {

            next = nextNode.request();
            tail = tailNode.request();

            // Find the number of nodes
            nodesCount = next.receiveInt();

            particles = new Particle[size];
            pvs = new ParticleV[size];

            nbody.init(particles, pvs, nodesCount);

            Head.tick();

            // Synchronised ring
            i = 0;
            <next,tail>.outwhile(i < iterCount+5) {

                // This round
                Particle[] tempParticles = new Particle[size];
                System.arraycopy(particles, 0, tempParticles, 0, size);

                // Pump particles through the ring
                j = 0;
                <next,tail>.outwhile(j < nodesCount - 1) {
                    next.send(tempParticles); // Send it into the ring
                    nbody.computeForces(particles, tempParticles, pvs); // Calculate current set
                    tempParticles = (Particle[]) tail.receive(); // Receive from the other end of the ring

                    ++j;
                }

                nbody.computeForces(particles, tempParticles, pvs);
                nbody.computePositions(particles, pvs, i);

                ++i;
            }

            Head.tock();

        } catch (SJIncompatibleSessionException ise) {

            System.err.println("[Head] Non-dual behaviour: " + ise);

        } catch (SJIOException sioe) {

            System.err.println("[Head] Communication error: " + sioe);

        } finally { // Close socket

            nbody.finish();

        }

//        nbody.storeResults(particles, nodesCount);

    }

    public static void tick() {
        executionTime = System.currentTimeMillis();
        System.out.println("[Head] Tick");
    }

    public static void tock() {
        executionTime = System.currentTimeMillis() - executionTime;
        System.out.println("[Head] Tock: execution time is "+executionTime);
    }

    public static void main(String[] args) throws ClassNotFoundException {
        Head head = new Head(new JavaNBody());
        head.run("localhost", 30001, "localhost", 30000, 10, 10);
    }

}

//$ sessionjc -cp lib:lib/jyaml.jar -d lib src/nbody/old/Tail.sj
//$ sessionj  -cp lib:lib/jyaml.jar nbody.old.Tail ring.yaml tail

package nbody.old;

import java.io.FileNotFoundException;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import sessionj.verifier.ConfigLoader;
import sessionj.utils.Log;

import nbody.NBody;
import nbody.Particle;
import nbody.ParticleV;

public class Tail extends NBody {
    //                                     #nodes 
    final noalias protocol p_prev { sbegin.!<int>.?(int).?[?[?(Particle[])]*]* }
    final noalias protocol p_head { sbegin.!<Particle[]> }

    public void run(int listenPort, int headPort) throws ClassNotFoundException {

        final noalias SJServerSocket prevNode;
        final noalias SJServerSocket headNode;
        final noalias SJSocket prev;
        noalias SJSocket head;

        Particle[] particles = null;
        ParticleV[] pvs = null;

        int i = 0;
        int size;

        try (prevNode,headNode) {

            prevNode = SJServerSocketImpl.create(p_prev, listenPort);
            headNode = SJServerSocketImpl.create(p_head, headPort);

            try (prev) {

                prev = prevNode.accept();
                Log.i("old.nbody.Tail", "Connected by prev node at :"+listenPort);

                // # of nodes
                prev.send(1);
                size = prev.receiveInt();

                particles = new Particle[size];
                pvs = new ParticleV[size];

                init(particles, pvs, 0);

                prev.inwhile() {
                    
                    // This round
                    Particle[] tempParticles = new Particle[size];
                    System.arraycopy(particles, 0, tempParticles, 0, size);

                    // Pump particles through ring
                    prev.inwhile() {
                        try (head) {
                            head = headNode.accept();
                            head.send(tempParticles);

                        } catch (SJIncompatibleSessionException ise) {

                            System.err.println("[Head@{tail}] Non-dual behaviour: "+ise);

                        } catch (SJIOException ioe) {

                            System.err.println("[Head@{tail}] Communication error: "+ioe);

                        } finally {} // Sockets

                        computeForces(particles, tempParticles, pvs);
                        tempParticles = (Particle[]) prev.receive();
                    }

                    computeForces(particles, tempParticles, pvs);
                    computePositions(tempParticles, pvs, i);

                    ++i;
                }

            } catch (SJIncompatibleSessionException ise) {

                System.err.println("[Tail] Non-dual behaviour: " + ise);

            } catch (SJIOException sioe) {

                System.err.println("[Tail] Communication error: " + sioe);
            }

        } catch (SJIOException sioe) {

            System.err.println("[Tail] Communication error: " + sioe);

        } finally { }
    }

    public static void main(String[] args) throws ClassNotFoundException, FileNotFoundException {
        ConfigLoader config = ConfigLoader.load(args[0], args[1]);

        int prevPort = Integer.parseInt(config.get("prev.port"));
        int headPort = Integer.parseInt(config.get("head.port"));

        new Tail().run(prevPort, headPort);
    }
}

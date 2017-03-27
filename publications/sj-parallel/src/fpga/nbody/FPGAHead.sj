//$ sessionjc -cp lib:./jna.jar src/nbody/FPGAHead.sj -d lib
//$ sessionj -cp lib:./jna.jar nbody.FPGAHead body-host:right-port tail-host:head-port input-size 200

package nbody;

import nbody.dm.FPGANBody;

public class FPGAHead {
    public static void main(String[] args) throws ClassNotFoundException {
        String nextHost = args[0].split(":")[0];
        int nextPort = Integer.parseInt(args[0].split(":")[1]);

        String tailHost = args[1].split(":")[0];
        int tailPort = Integer.parseInt(args[1].split(":")[1]);

        int size = Integer.parseInt(args[2]);
        int iterCount = Integer.parseInt(args[3]);

        Head head = new Head(new FPGANBody());
        head.run(nextHost, nextPort, tailHost, tailPort, size, iterCount);
    }

}

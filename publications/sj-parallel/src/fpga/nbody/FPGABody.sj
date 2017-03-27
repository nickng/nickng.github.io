//$ sessionjc -cp lib:./jna.jar src/nbody/FPGABody.sj -d lib/
//$ sessionj -cp lib:./jna.jar nbody.FPGABody left-port body-host:right-port input-size

package nbody;

import nbody.dm.FPGANBody;

public class FPGABody {
    public static void main(String[] args) throws ClassNotFoundException {
        int listenPort = Integer.parseInt(args[0]);

        String nextHost = args[1].split(":")[0];
        int nextPort = Integer.parseInt(args[1].split(":")[1]);

        int size = Integer.parseInt(args[2]);

        Body body = new Body(new FPGANBody());
        body.run(listenPort, nextHost, nextPort, size);
    }
}


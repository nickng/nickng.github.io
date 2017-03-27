//$ sessionjc -cp lib:./jna.jar src/nbody/FPGATail.sj -d lib/
//$ sessionj -cp lib:./jna.jar nbody.FPGATail tail-port head-port input-size

package nbody;

import nbody.dm.FPGANBody;

public class FPGATail {
    public static void main(String[] args) throws ClassNotFoundException {
        int listenPort = Integer.parseInt(args[0]);
        int headPort = Integer.parseInt(args[1]);

        int size = Integer.parseInt(args[2]);

        Tail tail = new Tail(new FPGANBody());
        tail.run(listenPort, headPort, size);
    }

}


//$ sessionjc -cp .:lib:./jna.jar src/nbody/Particle.sj -d lib
//$

package nbody;

import java.io.Serializable;
import com.sun.jna.Structure;

/**
 * Class modelling a particle in N-Body simulation.
 */
public class Particle extends Structure implements Serializable {
    public double x, y; // position
    public double m;    // mass

    /**
     * Constructor (required for JNA array construction)
     */
    public Particle() {
        super();
    }
}

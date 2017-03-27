//$ sessionjc -cp lib/ -d lib/ src/nbody/Particle.sj
//$

package nbody;

import java.io.Serializable;

/**
 * Class modelling a particle in N-Body simulation.
 */
public class Particle implements Serializable {
    public double x, y; // position
    public double m;    // mass

    public String toString() {
        return "<m="+m+" ("+x+","+y+")>";
    }
}

//$ sessionjc -cp .:lib:./jna.jar src/nbody/ParticleV.sj -d lib
//$
package nbody;

import java.io.Serializable;
import com.sun.jna.Structure;

/**
 * Class modelling particle velocities and acceleration in N-Body simulation.
 */
public class ParticleV extends Structure implements Serializable {
    public double vi_old, vj_old;
    public double ai_old, aj_old;
    public double ai, aj;
}

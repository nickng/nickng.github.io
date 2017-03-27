//$ sessionjc -cp lib/ -d lib/ src/nbody/ParticleV.sj
//$

package nbody;

import java.io.Serializable;

/**
 * Class modelling particle velocities and acceleration in N-Body simulation.
 */
public class ParticleV implements Serializable {
    public double vi_old, vj_old;
    public double ai_old, aj_old;
    public double ai, aj;
}

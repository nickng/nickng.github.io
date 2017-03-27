//$ sessionjc -cp lib/ -d lib/ src/jacobi/Checkconv.sj
//$

package jacobi;

import java.io.Serializable;

public class Checkconv implements Serializable {
	public double diff, valmx;

    public Checkconv() {
        diff = 100;
        valmx = 1.0;
    }
    
    public Checkconv(double diff, double valmx) {
        this.diff = diff;
        this.valmx = valmx;
    }
		
	public String toString() {
		return "<diff="+diff+", valmx="+valmx+">";
	}
}

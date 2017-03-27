//$ bin/sessionjc -cp tests/classes/ tests/src/nbody/FirstWorker.sj -d tests/classes/
//$ bin/sessionj -cp tests/classes/ nbody.FirstWorker false localhost 4441 localhost 4442 1 1

/**
* 
* @author Andi
* @modified Yiannos
*
*/
package nbody;

import java.util.Arrays;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import nbody.Particle;
import nbody.ParticleV;

public class FirstWorker
{	
  private final static int MAX_PARTICLES = 30000;
  private final static int MAX_PROCESSORS = 128;	
  private double[][] toReceive;
     private double[][] toSent;
  private final noalias protocol pro_first_second
  {
    cbegin.
    ?(int).
    ![
    ![
    !<Particle[]>
    //!<double[][]>
    ]*
    ]*
  }
  private final noalias protocol pro_first_last
  {
    cbegin.
    ![
    ![
    ?(Particle[])
    //?(double[][])
    ]*
    ]*
  }	
  
  public void run(boolean debug, String host_last, int port_last, String host_second, int port_second, int numParticles, /*int numProcessors*/ int reps)
  {
    // The particles.
    Particle[] particles = new Particle[numParticles];
    
    // The particles' velocities.
    ParticleV[] pvs = new ParticleV[numParticles]; 
    
    int numProcessors = 0;
    final noalias SJService c_last= SJService.create(pro_first_last, host_last, port_last);
    final noalias SJService c_second = SJService.create(pro_first_second, host_second, port_second);
    
    
    final noalias SJServerSocket ss;
    
    try (ss)
    {
      
      long timeStarted = 0;		
      long timeFinished = 0;			
      while(true)
      {
	final noalias SJSocket fs, fl;
	try(fs,fl)
	{
	  fs = c_second.request(); //first_second
	  fl = c_last.request(); //first_last
	  
	  timeStarted = System.nanoTime();
	  
	  numProcessors = fs.receiveInt() + 1;
	  
	  if (debug)
	  {
	    System.out.println("Number of processors: " + numProcessors);
	  }
	  
	  /* Generate initial values. */
	  initParticles(debug,particles, pvs);
	  
	  int i = 0;
	  
	  <fs,fl>.outwhile(i < reps)
	  {	
	    if (debug)
	    {
	      System.out.println("\nIteration: " + i);
	      System.out.println("Particles: " + Arrays.toString(particles));
	    }	
	    
	    Particle[] current = new Particle[numParticles];
	    
	    System.arraycopy(particles, 0, current, 0, numParticles);
	    
	    int j = 0;
	    
	    <fs,fl>.outwhile(j < (numProcessors - 1))
	    {									
	      //toSent=Worker.ParticleToDouble(current);
	      // fs.send(toSent);
          fs.send(current);
	      Worker.computeForces(particles, current, pvs);
	      //toReceive=(double[][]) fl.receive();
	      //current=Worker.DoubleToParticle(toReceive);
	      current =(Particle[]) fl.receive();
	      j++;
	    }													
	    
	    Worker.computeForces(particles, current, pvs);
	    
	    Worker.computeNewPos(particles, pvs, i);
	    
	    i++;
	  }
	  
	  timeFinished = System.nanoTime();
	  
	 System.out.println("Iterations= "+ i +" Particles= "+ numParticles + " time= " + (timeFinished - timeStarted) / 1000 + " micros ");
	  
	  if (debug)
	  {
	    System.out.println("\nIteration: " + i);
	    System.out.println("Particles: " + Arrays.toString(particles));
	  }
	  break;
	}
	
	finally
	{
	}
      }
      
    }
    catch (SJIncompatibleSessionException ise)
    {
      System.err.println("[Master] Non-dual behavior: " + ise);
    }
    catch (SJIOException sioe)
    {
      System.err.println("[Master] Communication error: " + sioe);
    }
    catch (ClassNotFoundException cnfe)
    {
      System.err.println("[Master] Class error: " + cnfe);
    }
    
  }
  
  
  public static void main(String args[])
  {
    boolean debug = Boolean.parseBoolean(args[0]);
    String host_last= args[1];
    int port_last = Integer.parseInt(args[2]);
    String host_second = args[3];
    int port_second = Integer.parseInt(args[4]);		
    
    int numParticles = Integer.parseInt(args[5]);
    //int numProcessors = Integer.parseInt(args[5]);		
    int reps = Integer.parseInt(args[6]);
    
    if (numParticles <= MAX_PARTICLES/* && numParticles <= MAX_PROCESSORS*/)
    {	
      FirstWorker fw = new FirstWorker(); 
      
      fw.run(debug, host_last ,port_last, host_second, port_second, numParticles, reps);
    }
    else
    {
      System.out.println("Too many particles: " + numParticles);
    }
  }
  
  private void initParticles(boolean debug, Particle[] particles, ParticleV[] pvs)
  {
    for(int i = 0; i < particles.length; i++)
    {		
      Particle p = new Particle();
      
      if (debug)
      {
	p.x = i;
	p.y = i;
	p.m = 1.0;
      }
      else
      {
	p.x = 10.0 * Math.random();
	p.y = 10.0 * Math.random();
	p.m = 10.0 * Math.random();
      }
      particles[i] = p;
      
      ParticleV pv = new ParticleV();
      
      pv.vi_old = 0;
      pv.vj_old = 0;
      pv.ai_old = 0;
      pv.aj_old = 0;
      pv.ai = 0;
      pv.aj = 0;
      
      pvs[i] = pv;
    }
  }
}

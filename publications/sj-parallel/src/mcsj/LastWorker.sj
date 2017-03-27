//$ bin/sessionjc -cp tests/classes/ tests/src/nbody/LastWorker.sj -d tests/classes/
//$ bin/sessionj -cp tests/classes/ nbody.LastWorker false 4444 4441 1

/**
* 
* @author Andi
* @modified Yiannos
*
*/
package nbody;

import java.util.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import nbody.Particle;
import nbody.ParticleV;

public class LastWorker
{
  private final static int MAX_PARTICLES = 30000;
  private double[][] toReceive;
     private double[][] toSent;
  private final noalias protocol pro_last_rest
  {
    sbegin.
    !<int>.
    ?[
    ?[
    ?(Particle[])
    //?(double[][])
    ]*
    ]*				
  }
  
  private final noalias protocol pro_last_first
  {
    sbegin.
    ?[
    ?[
    !<Particle[]>
    //!<double[][]>
    ]*
    ]*
  }
  
  public void run(boolean debug, int port_rest, int port_first, int numParticles)
  {
    // The particles.
    Particle[] particles = new Particle[numParticles];
     
    // The particles' velocities.
    ParticleV[] pvs = new ParticleV[numParticles]; 	
    
    //final noalias SJService right_c = SJService.create(pc_ring, host_r, port_r);
    
    final noalias SJServerSocket ss_rest,ss_first;
    
    try(ss_rest)
    {			
      ss_rest = SJServerSocketImpl.create(pro_last_rest, port_rest);
      
      try(ss_first)
      {			
	ss_first=SJServerSocketImpl.create(pro_last_first, port_first);
	while(true)
	{
	  final noalias SJSocket lr,lf; //last_rest and last_left
	  try(lf,lr)
	  {
	    lf = ss_first.accept();		
	    lr=ss_rest.accept();
	    lr.send(1);
	    
	    initParticles(debug,particles, pvs); 							
	    
	    int i = 0;
	    
	    <lr,lf>.inwhile()
	    {				
	      if (debug)
	      {
		System.out.println("\nIteration: " + i);
		System.out.println("Particles: " + Arrays.toString(particles));
	      }					
	      
	      Particle[] current = new Particle[numParticles];					
	      
	      System.arraycopy(particles, 0, current, 0, numParticles);
	      
	      <lr,lf>.inwhile()
	      {
		//toSent=Worker.ParticleToDouble(current);
		//lf.send(toSent);
        lf.send(current);
		Worker.computeForces(particles, current, pvs);
		//toReceive=(double[][]) lr.receive();
	     //  current=Worker.DoubleToParticle(toReceive);
         current = (Particle[]) lr.receive();
	   }
	      Worker.computeForces(particles, current, pvs);
	      
	      Worker.computeNewPos(particles, pvs, i);	
	      
	      i++;
	    }
	    
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
	System.err.println("[Client] Non dual-behavior: " + ise);
      }
      catch (SJIOException sioe)
      {
	System.err.println("[Client] Communication error: " + sioe);				
      }
      catch (ClassNotFoundException cnfe)
      {
	System.err.println("[Client] Class error: " + cnfe);
      }
    }
    catch (SJIOException sioe)
    {
      System.err.println("[WorkerN] Communication error: " + sioe);
    }
  }
  
  public static void main(String args[])
  {
    boolean debug = Boolean.parseBoolean(args[0]);	
    int port_l = Integer.parseInt(args[1]);
    int port_r = Integer.parseInt(args[2]);		
    
    int numParticles = Integer.parseInt(args[3]);		
    
    if (numParticles <= MAX_PARTICLES)
    {		
      LastWorker lw = new LastWorker();
      
      lw.run(debug, port_l, port_r, numParticles);
    }
    else
    {
      System.out.println("Too many particles.");
    }
  }
  
  private void initParticles(boolean debug,Particle[] particles, ParticleV[] pvs)
  {
    for(int i = 0; i < particles.length; i++)
    {		
      Particle p = new Particle();
      
     if (debug)
     {
       p.x = 2*particles.length + i;
       p.y = 2*particles.length + i;
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

//$ bin/sessionjc -cp tests/classes/ tests/src/nbody/ordinary/Worker.sj -d tests/classes/
//$ bin/sessionj -cp tests/classes/ nbody.ordinary.Worker false 4443 localhost 4444 1

package nbody.ordinary;

import java.util.*;
import java.io.*;

import sessionj.runtime.*;
import sessionj.runtime.net.*;

import nbody.Particle;
import nbody.ParticleV;

public class Worker
{
  private static final int MAX_PARTICLES = 30000;
  //private static final double G = 6.674 * Math.pow(10, -11);
  private static final double G = 1.0;
  
  private final noalias protocol ps_nbody // Server socket is on our s_l side: s_l guy connects to us.
  {
    sbegin.!<int>.?[?[?(Particle[])]*]*
  }
  
  private final noalias protocol pc_nbody // Client socket is on out s_r side: we connect to the s_r guy.
  {
    cbegin.?(int).![![!<Particle[]>]*]*
  }
  
  public void run(boolean debug, int port_l, String host_r, int port_r, int numParticles)
  {	
    // The particles.
    Particle[] particles = new Particle[numParticles];
    
    // The particles' velocities.
    ParticleV[] pvs = new ParticleV[numParticles]; 
    
    final noalias SJServerSocket ss_l;	
    
    final noalias SJService c_r = SJService.create(pc_nbody, host_r, port_r);		
    final noalias SJSocket s_r;
    
    /* Binary session types define a Client-Server model of programming; e.g. iterations and conditionals. */
    
    try (ss_l)
    {				
      ss_l = SJServerSocketImpl.create(ps_nbody, port_l);
      
      final noalias SJSocket s_l;							
      
      try (s_l, s_r) 
      {
	s_l = ss_l.accept();									
	
	s_r = c_r.request(); 
	
	s_l.send(s_r.receiveInt() + 1);
	
	initParticles(particles, pvs); 
	
	int i = 0;							
	
	s_r.outwhile(s_l.inwhile())
	{			
	  if (debug)
	  {
	    System.out.println("\nIteration: " + i);
	    System.out.println("Particles: " + Arrays.toString(particles));
	  }				
	  
	  Particle[] current = new Particle[numParticles];					
	  
	  System.arraycopy(particles, 0, current, 0, numParticles);
	  
	  s_r.outwhile(s_l.inwhile())
	  {			
	    s_r.send(current);
	    
	    computeForces(particles, current, pvs);
	    
	    current = (Particle[]) s_l.receive();
	    
	  }
	  
	  computeForces(particles, current, pvs);
	  
	  computeNewPos(particles, pvs, i);						
	  
	  i++;
	}			
	
	if (debug)
	{
	  System.out.println("\nIteration: " + i);
	  System.out.println("Particles: " + Arrays.toString(particles));
	}				
      }
      finally
      {
	
      }
    }
    catch (SJIncompatibleSessionException ise)
    {
      System.err.println("[Worker] Non-dual behavior: " + ise);
    }
    catch (SJIOException sioe)
    {
      System.err.println("[Worker] Communication error: " + sioe);				
    }
    catch (ClassNotFoundException cnfe)
    {
      System.err.println("[Worker] Class error: " + cnfe);
    }
    finally
    {
      
    }
  }
  
  public static void main(String args[])
  {
    boolean debug = Boolean.parseBoolean(args[0]);		
    int port_l = Integer.parseInt(args[1]);
    String host_r = args[2];
    int port_r = Integer.parseInt(args[3]);		
    
    int numParticles = Integer.parseInt(args[4]);
    
    if (numParticles <= MAX_PARTICLES/* && numParticles <= MAX_PROCESSORS*/)
    {	
      Worker w = new Worker(); 
      
      w.run(debug, port_l, host_r, port_r, numParticles);
    }
    else
    {
      System.out.println("Too many particles: " + numParticles);
    }
  }

    public void init(Particle[] particles, ParticleV[] pvs) {
        int nodeIndex = 1;

        double m, x, y, vi, vj;
        int lineBegin = (nodeIndex * pvs.length) % 81920;
        int currentLine = 0;

        Scanner sc = null;
        try {
            sc = new Scanner(new BufferedReader(new FileReader("/homes/cn06/fyp/src/nbody/input/particles.txt")));
        } catch (FileNotFoundException fnfe) {
            System.err.println("Cannot read input file, exiting.");
            System.exit(1);
        }

        // skip
        // TODO: Seek instead of this
        while (currentLine++ < lineBegin) {
            sc.nextLine();
        }

        for (int i=0; i<pvs.length; ++i) {
            m = sc.nextDouble();
            x = sc.nextDouble();
            y = sc.nextDouble();
            vi = sc.nextDouble();
            vj = sc.nextDouble();

            particles[i] = new Particle();
            particles[i].m = m;
            particles[i].x = x;
            particles[i].y = y;

            pvs[i] = new ParticleV();
            pvs[i].vi_old = vi;
            pvs[i].vi_old = vj;
            pvs[i].ai_old = 0.0f;
            pvs[i].aj_old = 0.0f;
            pvs[i].ai = 0.0f;
            pvs[i].aj = 0.0f;

            if (!sc.hasNext()) {
                sc.close();
                try {
                    sc = new Scanner(new BufferedReader(new FileReader(System.getProperty("user.dir")+"/input/particles.txt")));
                } catch (FileNotFoundException fnfe) {
                    System.err.println("Cannot read input file, exiting.");
                    System.exit(1);
                }
            }
        }
    }
  
  private void initParticles(Particle[] particles, ParticleV[] pvs)
  {
    for(int i = 0; i < particles.length; i++)
    {		
      Particle p = new Particle();
      
      // 			p.x = 10.0 * Math.random();
      // 			p.y = 10.0 * Math.random();
      // 			p.m = 10.0 * Math.random();
      p.x = particles.length+i;
      p.y = particles.length+i;
      p.m = 1.0;
      /*p.x = i + 3;
      p.y = i + 3;						
      p.m = i + 3;*/
      
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
  
  public static void computeForces(Particle[] particles, Particle[] current, ParticleV[] pvs)
  {		
    for (int ours = 0; ours < particles.length; ours++)
    {			
      double x = particles[ours].x;
      double y = particles[ours].y;
      
      double ai = 0.0;
      double aj = 0.0;
      
      for (int theirs = 0; theirs < current.length; theirs++)
      {				
	double ri = current[theirs].x - x;
	double rj = current[theirs].y - y;			
	double m = current[theirs].m;
	
	if (ri != 0)
	{									
	  ai += ((ri < 0) ? -1 : 1) * G * m / (ri * ri);
	  
	  //System.out.println("\n1: " + pvs[ours].ai + ", " + ai + "\n");
	}
	
	if (rj != 0)
	{
	  aj += ((rj < 0) ? -1 : 1) * G * m / (rj * rj);					
	}
      }
      
      pvs[ours].ai += ai;						
      
      pvs[ours].aj += aj;
    }	
  }
  
  public static void computeNewPos(Particle[] particles, ParticleV[] pvs, int step)
  {
    double dt = 1.0;
    
    for(int i = 0; i < particles.length; i++)
    {
      Particle p = particles[i]; 
      ParticleV pv = pvs[i];
      
      double x = p.x;
      double y = p.y;			
      
      double ai_old = pv.ai_old;
      double aj_old = pv.aj_old;						
      double ai = pv.ai;
      double aj = pv.aj;
      
      // At this point we have p_n, a_n. We also have v_n-1  and a_n-1 (except for n = 0). So need to work out v_n (except for n = 0).
      
      double vi_old = pv.vi_old;
      double vj_old = pv.vj_old;			
      double vi;
      double vj;
      
      if (step == 0) // Only in the first iteration do we use the stored velocity values...
      {
	vi = vi_old; 
	vj = vj_old;
      }
      else // ...otherwise we calculate the current velocities.
      {
	vi = vi_old + ((ai + ai_old) * dt / 2);
	vj = vj_old + ((aj + aj_old) * dt / 2);
      }
      
      p.x = x + (vi * dt) + (ai * dt * dt / 2);  
      p.y = y + (vj * dt) + (aj * dt * dt / 2);			
      
      pv.vi_old = vi;
      pv.vj_old = vj;
      
      pv.ai_old = ai;
      pv.aj_old = aj;
      pv.ai = 0.0;
      pv.aj = 0.0;
    }
  }
  public static double[][] ParticleToDouble(Particle[] particles)
  {
    double[][] partDouble= new double[particles.length][3];
    for(int i = 0; i < particles.length; i++)
    {
      partDouble[i][0]= particles[i].x;
      partDouble[i][1]= particles[i].y;
      partDouble[i][2]= particles[i].m;
    }
    return partDouble;
    
  }
  public static Particle[] DoubleToParticle(double[][] partDouble)
  {
    Particle [] particles=new Particle[partDouble.length];
    for(int i = 0; i < partDouble.length; i++)
    {
      Particle p = new Particle();
      p.x=partDouble[i][0];
      p.y=partDouble[i][1];
      p.m=partDouble[i][2];
      particles[i]=p;
    }
     return particles;
    
  }
}

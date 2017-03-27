//javac -cp  ../mpj/lib/mpj.jar Jacobi2D.java
//mpjrun.sh -np 4 Nbody 10 10 true

//
// Yiannos Kryftis
//
//
import Particles.*;
import java.io.*;
import java.text.NumberFormat;
import java.lang.Math;
import mpi.*;
import java.util.*;
public class Nbody 
{
  private static final int MAX_PARTICLES = 4000;
  
  //private static final double G = 6.674 * Math.pow(10, -11);
  private static final double G = 1.0;
  private double[][] toReceive;
  private double[][] toSent;
  
  public static void main(String[] args) throws Exception 
  {
    Nbody p = new Nbody(args);
  }
  
  public Nbody(String[] args) throws Exception 
  {
    
    //double      startwtime, endwtime;
    int rank, numParticles,size,iterations;
    int j,i=0;
    long timeStarted=0,timeFinished;
    MPI.Init(args);
    rank = MPI.COMM_WORLD.Rank();
    size  = MPI.COMM_WORLD.Size();
    numParticles = Integer.parseInt(args[3]);
    iterations= Integer.parseInt(args[4]);
    boolean debug=Boolean.parseBoolean(args[5]);
    Particle[] particles = new Particle[numParticles];
    ParticleV[] pvs = new ParticleV[numParticles];
    initParticles(particles, pvs,rank*numParticles); 
    if(rank==0)
    {
     timeStarted = System.nanoTime();
    }
      
      while(i<iterations)
      {	
	
	if (debug)
	{
	  System.out.println("\nIteration: " + i);
	  System.out.println("Particles: " + Arrays.toString(particles));
	}	
	
	Particle[] current = new Particle[numParticles];
	Particle[] recvbuf= new Particle[numParticles*size];
	System.arraycopy(particles, 0, current, 0, numParticles);
	
	MPI.COMM_WORLD.Allgather(current, 0, numParticles, MPI.OBJECT, recvbuf, 0, numParticles , MPI.OBJECT);
        computeForces(particles,recvbuf,pvs);
	computeNewPos(particles,pvs,i);
	i++;
	  
      }
    if(rank==0)
    {
    timeFinished = System.nanoTime();
    
    System.out.println("time = " + (timeFinished - timeStarted) / 1000 + " micros");
    }
    MPI.COMM_WORLD.Barrier();
    MPI.Finalize();
  }
  private void initParticles(Particle[] particles, ParticleV[] pvs,int rank)
  {
    for(int i = 0; i < particles.length; i++)
    {		
      Particle p = new Particle();
      
      // 			p.x = 10.0 * Math.random();
      // 			p.y = 10.0 * Math.random();
      // 			p.m = 10.0 * Math.random();
      p.x = rank+i;
      p.y = rank+i;
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
}

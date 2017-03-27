#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>

#include "types.h"
#include "axel.h"

volatile uint32_t* fpgaReg;
volatile uint8_t*  fpgaMem;

static int count = 0;
static int particle_index = 0;
static struct particlev_t *pvs;
static struct particle_t  *particles;
static struct particle_t  *currents;

void compute_forces(struct particle_t particles[], struct particle_t current[], struct particlev_t pvs[], int nr_of_particles);

void begin_compute_forces(int nr_of_particles)
{
    count = nr_of_particles-1;
    particle_index = 0;
    pvs = (struct particlev_t *) malloc(nr_of_particles*sizeof(struct particlev_t));
    particles = (struct particle_t *) malloc(nr_of_particles*sizeof(struct particle_t));
    currents = (struct particle_t *) malloc(nr_of_particles*sizeof(struct particle_t));
}

// JNA cannot use array/pointer arguments so return an array/pointer instead
struct particlev_t *compute_force(struct particle_t *particle, struct particle_t *current, struct particlev_t *pv)
{
    particles[particle_index] = *particle;
    currents[particle_index]  = *current;
    pvs[particle_index] = *pv;

    if (particle_index == count) {
        compute_forces(particles, currents, pvs, count+1);
        return pvs;
    }

    ++particle_index;

    return NULL; // Return nothing unless last round
}

void freeall()
{
    free(pvs);
    free(particles);
    free(currents);
}

// Wrapper for other functions needing access from SJ
// JNA cannot see symbols in fpga_utils

int initialise(char *bitfilename, float freq)
{
    return fpga_init(bitfilename, freq);
}
int finalise(void)
{
    return fpga_finalize();
}
void cleanup(void)
{
    fpga_cleanup();
}

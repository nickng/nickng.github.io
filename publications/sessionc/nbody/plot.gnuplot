# Nbody simulation
#
set term png font "Helvetica,20" enhanced
set output "nbody.png"
set xlabel "Number of particles per process"
set ylabel "Runtime (seconds)"
set title 'N-body simulation'
set key top left

plot \
    "mpi.dat"   using 1:(($2+$3+$4+$5+$6)/5) title 'MPI'       with linespoints lt 2 lw 2, \
    "sessc.dat" using 1:(($2+$3+$4+$5+$6)/5) title 'Session C' with linespoints lt 1 lw 2 

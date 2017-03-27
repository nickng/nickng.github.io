# Jacobi solution
#
set term png font "Helvetica,20" enhanced
set output "jacobi.png"
set xlabel "Array size of sub-grid"
set ylabel "Runtime (seconds)"
set title 'Jacobi solution of the Discrete Poisson Equation'
set xrange [1500:]
set key top left

plot \
    "sessc.dat" using 1:(($2+$3+$4)/3) title 'Session C (no optimisation)' with linespoints lt 3 lw 2, \
    "mpi.dat"   using 1:(($2+$3+$4)/3) title 'MPI'       with linespoints lt 2 lw 2, \
    "sessc.dat" using 1:(($5+$6+$7)/3) title 'Session C' with linespoints lt 1 lw 2

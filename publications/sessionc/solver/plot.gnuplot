# Parallel Linear Equation Solver
#
set term png font "Helvetica,20" enhanced
set output "solver.png"
set xlabel "Matrix dimension"
set ylabel "Runtime (seconds)"
set title 'Linear Equation Solver'
set key top left
set xrange[2100:6000]

plot \
    "mpi.dat"   using 1:(($2+$3+$4+$5+$6)/5) title 'MPI'       with linespoints lt 2 lw 2, \
    "sessc.dat" using 1:(($2+$3+$4+$5+$6)/5) title 'Session C' with linespoints lt 1 lw 2

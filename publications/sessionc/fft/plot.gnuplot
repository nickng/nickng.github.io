# FFT
#
set term png font "Helvetica,20" enhanced
set output "fft.png"
set xlabel "Array size"
set ylabel "Runtime (seconds)"
set logscale x 2
set format x "2^{%L}"
set title 'Fast Fourier Transformation'
set key top left

plot \
    "mpi.dat"   using (2**$1):(($2+$3+$4+$5+$6)/5*1000) title 'MPI'       with linespoints lt 2 lw 2, \
    "sessc.dat" using (2**$1):(($2+$3+$4+$5+$6)/5*1000) title 'Session C' with linespoints lt 1 lw 2 

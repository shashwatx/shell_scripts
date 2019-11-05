#!/bin/bash
FILES=./varianceWithSeedFiles/*.sorted
for f in $FILES
do
	gnuplot <<-EOF
		set xlabel "|Seeds|"
		set ylabel "|CR| - |Seeds|"
		set term png
		set output "${f}.png"
        set grid
        set style line 1 lc rgb '#0060ad' lt 1 lw 2 pt 7 ps 1.5   # --- blue
        set style line 2 lc rgb '#B23611' lt 1 lw 2 pt 7 ps 1.5   # --- red
        set xtic rotate by -45 scale 0
        plot "${f}" using (\$2-\$1):xticlabels(1) title "CR" with linespoints ls 1
	EOF
done


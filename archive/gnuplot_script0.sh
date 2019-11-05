#set terminal postscript eps enhanced monochrome font 'Helvetica,25'

set terminal postscript eps monochrome enhanced size 10,4 font 'Helvetica, 25'
set output 'figureCombined2.eps';

set xlabel "|Seeds|"
set ylabel "|CR| - |Seeds|"

set grid
#set style line 1 lc rgb '#0060ad' lt 1 lw 2 pt 7 ps 1.5   # --- blue
#set style line 2 lc rgb '#B23611' lt 1 lw 2 pt 7 ps 1.5   # --- red
set xtics rotate by -45 scale 0
set xtics 20,40,400
set key top left

set multiplot layout 1, 2 ;

plot "datafile" using 1:($2-$1) title "Porc" with linespoints ls 1,\
    "datafile2" using 1:($2-$1) title "Baguette" with linespoints ls 3

plot "datafile3" using 1:($2-$1) title "Butter" with linespoints ls 1,\
    "datafile4" using 1:($2-$1) title "Pampers" with linespoints ls 3

unset multiplot

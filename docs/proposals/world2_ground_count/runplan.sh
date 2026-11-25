#!/bin/bash
# ./runplan.sh : all ten plans, 3 at a time
S=$(dirname "$(readlink -f "$0")")
for n in 4 8 7 9 3 2 5 10 6 1; do echo $n; done | xargs -P3 -I{} sh -c "blender -b --factory-startup --python $S/plan_wrap.py -- {} > $S/plan/log{}.txt 2>&1"
echo ALLPLANS

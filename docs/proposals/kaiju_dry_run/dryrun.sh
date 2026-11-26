#!/bin/bash
# dryrun.sh <kaiju sha> <swap sha> [none = kaiju branch alone]: scratch merge + fill cut + overlaps + vans
set -euo pipefail
KJ=$1; SW=$2; D=$(cd $(dirname $0); pwd); SRC=/home/dev/Anime-Run.worktrees/feature-alex-agent-2
N=$KJ-$SW; R=$D/repo-$N; O=$D/out-$N; rm -rf "$R" "$O"; mkdir -p $O
git clone -q --shared --no-checkout $SRC $R
git -C $R -c advice.detachedHead=false checkout -q $KJ
if [ $SW != none ]; then
  git -C $R -c user.name=dry -c user.email=dry@invalid merge --no-commit --no-ff $SW > $O/merge.log 2>&1 || { echo "MERGE FAILED (conflicted files, if any, then git output)"; git -C $R diff --name-only --diff-filter=U; cat $O/merge.log; exit 1; }
  echo "merge clean; conflicts: $(git -C $R diff --name-only --diff-filter=U | wc -l); tree $(git -C $R write-tree)"
fi
BL="blender -b --factory-startup --python"
git -C $R show c627382f:tools/blender/world2/biomes/KaijuBase.py > $O/pre.py
git -C $R show 1bc5e9f7:tools/blender/world2/biomes/KaijuBase.py > $O/r5.py
$BL $D/probe.py -- $R $O $O/cur.json > $O/cur.log 2>&1
$BL $D/probe.py -- $R $O $O/vans.json --vans > $O/vans.log 2>&1
$BL $D/probe.py -- $R $O $O/pre.json $O/pre.py > $O/pre.log 2>&1 || true
$BL $D/probe.py -- $R $O $O/r5.json $O/r5.py > $O/r5.log 2>&1 || true
$BL $D/clr.py -- $R $O > $O/clr.log 2>&1
$BL $R/tools/blender/world2/kaiju_reference.py -- $O --fast --fit > $O/fit.log 2>&1
$BL $D/vclr.py -- $R $O $(ls $O/mod_$(printf %s $O/vans.json | md5sum | cut -c1-8).py) > $O/vclr.log 2>&1
[ -s $O/cur.json ] && [ -s $O/vans.json ] && [ -s $O/pre.json ] && [ -s $O/r5.json ]
echo DONE $N

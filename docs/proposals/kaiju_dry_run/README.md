# Kaiju dry run on bb93b6c4 + swap round 5 5747dda6 (agent-2, 2026-11-25, scratch only)
Merge clean (0 conflicts). Re-cut of the fill keeps 12 (8 Apartment, 3 Office, 1 Rubble): 3 of the committed 10 and 2 of
the earlier 6; the other 9 are round 5 candidates freed by the swap. Kaiju box overlaps, exempt included: site 1 25 (T4 2,
T6 23; was 21), site 2 28 (T3 2, T4 4, T6 21, T7 1; was 28). Vans: 5 of 8 fit their frozen spots (d 470, 515, 560, 640,
2520); d 2565, 2610, 2660 stand in the kaiju; d 560 meets one T4 Cedar box and d 2520 one T3 box; of the 8 current spots
6 meet another track's box and d 740 touches a returning fill Apartment. Mesh hash 6f2817f7...7dab089, 19,889 tris,
placements as approved 1bc5e9f7; clearance 827/827. Box against box only; no renders, no export, no lune. Repeat after
round 6: dryrun.sh <kaiju sha> <swap sha|none>, then report.py <dry> <kaiju>-<swap> (about 16 minutes).

// Handscroll unroll for the reference frames (design doc 4.46 draft). ?p=0.3 freezes every scroll at that progress
// (used for the 5-frame strip); ?shot hides review labels. Otherwise each scroll unrolls from its centre in 0.45 s
// (quad out) and rolls up in 0.25 s (quad in); press R or click a .replay to play it again.
(function () {
	const q = new URLSearchParams(location.search);
	if (q.has("shot")) document.documentElement.classList.add("shot");
	const scrolls = () => document.querySelectorAll(".hs");
	const set = (v) => scrolls().forEach((s) => s.style.setProperty("--p", v));
	if (q.has("p")) { set(q.get("p")); return; }
	const quadOut = (t) => 1 - (1 - t) * (1 - t);
	const quadIn = (t) => t * t;
	function run(from, to, ms, ease) {
		return new Promise((done) => {
			const t0 = performance.now();
			(function step(now) {
				const t = Math.min(1, (now - t0) / ms);
				set(from + (to - from) * ease(t));
				t < 1 ? requestAnimationFrame(step) : done();
			})(t0);
		});
	}
	async function replay() { await run(1, 0, 250, quadIn); await new Promise((r) => setTimeout(r, 250)); await run(0, 1, 450, quadOut); }
	window.unroll = replay;
	set(0);
	setTimeout(() => run(0, 1, 450, quadOut), 300);
	document.addEventListener("keydown", (e) => { if (e.key === "r" || e.key === "R") replay(); });
	document.addEventListener("click", (e) => { if (e.target.closest(".replay")) replay(); });
})();

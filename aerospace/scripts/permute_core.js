#!/usr/bin/osascript -l JavaScript
// Computation core for permute.sh (yabai-style rotate/mirror for AeroSpace).
// Windows keep their frame slots; only which window occupies which slot changes.
//
//   frames                    -> {"<window-id>": {"x":N,"y":N,"w":N,"h":N}, ...}
//   plan <op> <windows-json>  -> {"identity":true} | {"moveTo":{"<id>":<id>,...}} | {"error":"..."}
//                                op: rotate-cw|rotate-ccw|mirror-y|mirror-x
//                                windows: [{"id":N, "x":N,"y":N,"w":N,"h":N}]  (geometry
//                                optional; fetched from CGWindowList when absent)
//   swaps <input-json>        -> lines "<window-id> dfs-prev"   (added in a later task)

ObjC.import('CoreGraphics')

function cgFrames() {
	const ref = $.CGWindowListCopyWindowInfo(
		$.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements,
		$.kCGNullWindowID)
	// castRefToObject is required: CFBridgingRelease segfaults under osascript,
	// and deepUnwrap alone can't take the raw CFArrayRef.
	const arr = ObjC.deepUnwrap(ObjC.castRefToObject(ref))
	const out = {}
	for (const w of arr) {
		if (w.kCGWindowLayer !== 0) continue
		const b = w.kCGWindowBounds
		out[w.kCGWindowNumber] = { x: b.X, y: b.Y, w: b.Width, h: b.Height }
	}
	return out
}

function computePlan(op, windows) {
	if (windows.some(w => w.x === undefined)) {
		const frames = cgFrames()
		for (const w of windows) {
			if (w.x !== undefined) continue
			const f = frames[w.id]
			if (!f) return { error: `no frame for window ${w.id}` }
			Object.assign(w, f)
		}
	}
	for (const w of windows) {
		w.cx = w.x + w.w / 2
		w.cy = w.y + w.h / 2
	}

	let moveTo = {}
	if (op === 'rotate-cw' || op === 'rotate-ccw') {
		// Same math as yabai/scripts/rotate_without_changing_layout.sh:
		// angle around the centroid with Y flipped (0 = right, CCW positive),
		// normalized to [0, 2pi); cw walks the ring in descending angle.
		const mx = windows.reduce((s, w) => s + w.cx, 0) / windows.length
		const my = windows.reduce((s, w) => s + w.cy, 0) / windows.length
		for (const w of windows) {
			let a = Math.atan2(my - w.cy, w.cx - mx)
			if (a < 0) a += 2 * Math.PI
			w.key = op === 'rotate-ccw' ? a : 2 * Math.PI - a
		}
		const ring = windows.slice().sort((p, q) => p.key - q.key || p.id - q.id)
		for (let i = 0; i < ring.length; i++) moveTo[ring[i].id] = ring[(i + 1) % ring.length].id
	} else if (op === 'mirror-y' || op === 'mirror-x') {
		// Reflect each center across the bounding-box midline, then greedily pair
		// windows to slots by distance (deterministic: dist, then ids). Exact on
		// symmetric layouts; nearest sensible assignment on asymmetric ones.
		const xmin = Math.min(...windows.map(w => w.x))
		const xmax = Math.max(...windows.map(w => w.x + w.w))
		const ymin = Math.min(...windows.map(w => w.y))
		const ymax = Math.max(...windows.map(w => w.y + w.h))
		const pairs = []
		for (const w of windows) {
			const rx = op === 'mirror-y' ? xmin + xmax - w.cx : w.cx
			const ry = op === 'mirror-x' ? ymin + ymax - w.cy : w.cy
			for (const v of windows) pairs.push([Math.hypot(rx - v.cx, ry - v.cy), w.id, v.id])
		}
		pairs.sort((p, q) => p[0] - q[0] || p[1] - q[1] || p[2] - q[2])
		const slotTaken = new Set()
		for (const [, src, tgt] of pairs) {
			if (moveTo[src] !== undefined || slotTaken.has(tgt)) continue
			moveTo[src] = tgt
			slotTaken.add(tgt)
		}
	} else {
		return { error: `unknown op ${op}` }
	}

	if (Object.entries(moveTo).every(([a, b]) => String(a) === String(b))) return { identity: true }
	return { moveTo }
}

function computeSwaps(moveTo, dfsOrder) {
	// Slots are DFS indices; "swap --window-id X dfs-prev" swaps X with the
	// window one slot earlier. Selection-sort bubbling realizes any permutation
	// as adjacent transpositions (<= n(n-1)/2 swaps).
	const slotOf = {}
	dfsOrder.forEach((id, i) => { slotOf[id] = i })
	const srcs = Object.keys(moveTo)
	const tgts = Object.values(moveTo)
	if (srcs.length !== dfsOrder.length
		|| new Set(tgts).size !== dfsOrder.length
		|| !srcs.every(w => slotOf[w] !== undefined)
		|| !tgts.every(t => slotOf[t] !== undefined)) {
		throw new Error('moveTo/dfsOrder id sets differ')
	}
	const desired = new Array(dfsOrder.length)
	for (const [w, t] of Object.entries(moveTo)) desired[slotOf[t]] = Number(w)
	const current = dfsOrder.slice()
	const lines = []
	for (let i = 0; i < desired.length; i++) {
		for (let j = current.indexOf(desired[i]); j > i; j--) {
			lines.push(`${current[j]} dfs-prev`)
			const tmp = current[j - 1]
			current[j - 1] = current[j]
			current[j] = tmp
		}
	}
	return lines.join('\n')
}

function run(argv) {
	const cmd = argv[0]
	if (cmd === 'frames') return JSON.stringify(cgFrames())
	if (cmd === 'plan') return JSON.stringify(computePlan(argv[1], JSON.parse(argv[2])))
	if (cmd === 'swaps') {
		const input = JSON.parse(argv[1])
		return computeSwaps(input.moveTo, input.dfsOrder)
	}
	throw new Error('usage: permute_core.js frames | plan <op> <windows-json> | swaps <input-json>')
}

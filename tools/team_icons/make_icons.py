# Team Select icon set (owner 2026-11-20): sticker style, dark ink outline, flat fill + highlight, 256x256 transparent.
O='stroke="#2a1410" stroke-width="10" stroke-linejoin="round" stroke-linecap="round"'
ICONS={
'members':f'''<circle cx="92" cy="86" r="40" fill="#f2c9a0" {O}/><path d="M28 214c0-46 28-74 64-74s64 28 64 74z" fill="#c8302c" {O}/>
<circle cx="172" cy="96" r="34" fill="#e8b88c" {O}/><path d="M128 214c4-40 22-62 46-62 30 0 56 24 56 62z" fill="#8e1a24" {O}/>''',
'cruise':f'''<path d="M44 212l132-132" stroke="#2a1410" stroke-width="30" stroke-linecap="round"/><path d="M44 212l132-132" stroke="#d8dde6" stroke-width="14" stroke-linecap="round"/>
<path d="M212 212L80 80" stroke="#2a1410" stroke-width="30" stroke-linecap="round"/><path d="M212 212L80 80" stroke="#d8dde6" stroke-width="14" stroke-linecap="round"/>
<path d="M150 42l64 0 0 64z" fill="#e7b552" {O}/><path d="M106 42l-64 0 0 64z" fill="#e7b552" {O}/>
<rect x="30" y="186" width="44" height="22" rx="6" transform="rotate(-45 52 197)" fill="#7a3a1a" {O}/><rect x="182" y="186" width="44" height="22" rx="6" transform="rotate(45 204 197)" fill="#7a3a1a" {O}/>''',
'flower':''.join(f'<path d="M128 124C96 86 100 34 128 22 156 34 160 86 128 124z" transform="rotate({a} 128 128)" fill="#ff9cc0" {O}/>' for a in (0,72,144,216,288))+f'<circle cx="128" cy="128" r="22" fill="#ffd34a" {O}/>',
'heart':f'<path d="M128 220C50 166 22 130 22 88a52 52 0 0 1 106-20 52 52 0 0 1 106 20c0 42-28 78-106 132z" fill="#3fbf5a" {O}/><path d="M62 86c4-18 18-30 34-30" stroke="#c8f5d0" stroke-width="12" fill="none" stroke-linecap="round"/>',
'bolt':f'<path d="M150 18L52 140h62l-22 98 112-140h-64z" fill="#ffc83a" {O}/><path d="M138 50L86 118" stroke="#fff3b8" stroke-width="10" stroke-linecap="round"/>',
'stamina':f'<path d="M150 18L52 140h62l-22 98 112-140h-64z" fill="#4aa8ff" {O}/><path d="M138 50L86 118" stroke="#cfe8ff" stroke-width="10" stroke-linecap="round"/>',
'pencil':f'<path d="M44 212l12-50 116-116 38 38-116 116z" fill="#ffc83a" {O}/><path d="M172 46l38 38 14-14a14 14 0 0 0 0-20l-18-18a14 14 0 0 0-20 0z" fill="#ff8fa8" {O}/><path d="M44 212l12-50 38 38z" fill="#f2d8b0" {O}/>',
'person':f'<circle cx="128" cy="80" r="50" fill="#f2c9a0" {O}/><path d="M36 226c0-60 40-94 92-94s92 34 92 94z" fill="#c8302c" {O}/>',
'fox':f'''<path d="M30 30l60 52h76l60-52-10 100c0 58-48 100-98 110-50-10-98-52-98-110z" fill="#ff8a3a" {O}/>
<path d="M60 150c22 0 44 10 68 44 24-34 46-44 68-44-6 44-34 70-68 78-34-8-62-34-68-78z" fill="#fff6ee"/>
<path d="M88 128l24 10M168 128l-24 10" stroke="#2a1410" stroke-width="12" stroke-linecap="round"/><path d="M114 196h28l-14 14z" fill="#2a1410"/>''',
'check':f'<circle cx="128" cy="128" r="104" fill="#2fa84f" {O}/><path d="M74 132l36 36 74-80" stroke="#fff" stroke-width="22" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
'search':f'<circle cx="108" cy="108" r="66" fill="#fbf2de" {O}/><path d="M156 156l58 58" stroke="#2a1410" stroke-width="30" stroke-linecap="round"/><path d="M78 92a36 36 0 0 1 30-26" stroke="#c9a77a" stroke-width="10" fill="none" stroke-linecap="round"/>',
'sort':f'<path d="M36 64h40M106 64h120M36 128h40M106 128h90M36 192h40M106 192h60" stroke="#2a1410" stroke-width="26" stroke-linecap="round"/>',
'star':f'<path d="M128 18l32 70 76 8-58 52 16 76-66-38-66 38 16-76-58-52 76-8z" fill="#ffc83a" {O}/><path d="M128 54l18 40" stroke="#fff3b8" stroke-width="10" stroke-linecap="round"/>',
}
import os
for k,v in ICONS.items():
    open(f'out/{k}.html','w').write(f'<!DOCTYPE html><html><body style="margin:0;background:transparent"><svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">{v}</svg></body></html>')

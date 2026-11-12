// shared drawing helpers (draft only)
function P(id,x,y,w,rot,extra){ // portrait centred at x, top y, width w
  const i=document.createElement('img');i.src='src/p/'+id+'.png';i.className='p';
  i.style.cssText=`left:${x-w/2}px;top:${y}px;width:${w}px;transform:rotate(${rot||0}deg);${extra||''}`;
  document.getElementById('s').appendChild(i);return i;}
function svg(html,z){const d=document.createElement('div');d.style.cssText=`left:0;top:0;width:1920px;height:1080px;z-index:${z||0}`;
  d.innerHTML=`<svg width=1920 height=1080 viewBox="0 0 1920 1080" xmlns="http://www.w3.org/2000/svg">${html}</svg>`;document.getElementById('s').appendChild(d);}
let seed=7;function rnd(){seed=(seed*16807)%2147483647;return seed/2147483647;}
function petals(n,x0,x1,y0,y1,avoid){let s='';for(let k=0;k<n;k++){const x=x0+rnd()*(x1-x0),y=y0+rnd()*(y1-y0);
  if(avoid&&avoid(x,y))continue;const r=5+rnd()*7,a=rnd()*180;
  s+=`<ellipse cx="${x}" cy="${y}" rx="${r}" ry="${r*.55}" fill="#ffc4de" opacity="${.6+rnd()*.4}" transform="rotate(${a} ${x} ${y})"/>`;}return s;}
function blossom(cx,cy,r){let s='';for(let k=0;k<5;k++){const a=k*72*Math.PI/180;s+=`<circle cx="${cx+Math.cos(a)*r*.55}" cy="${cy+Math.sin(a)*r*.55}" r="${r*.5}" fill="#ffb3d1"/>`;}
  return s+`<circle cx="${cx}" cy="${cy}" r="${r*.25}" fill="#ff6e9e"/>`;}
function lantern(x,y,s){return `<line x1="${x}" y1="${y-40*s}" x2="${x}" y2="${y}" stroke="#2a1a14" stroke-width="${3*s}"/>
 <defs><radialGradient id="lg${x}"><stop offset="0" stop-color="#ff9a4a" stop-opacity=".55"/><stop offset="1" stop-color="#ff9a4a" stop-opacity="0"/></radialGradient></defs><circle cx="${x}" cy="${y+38*s}" r="${80*s}" fill="url(#lg${x})"/>
 <rect x="${x-14*s}" y="${y}" width="${28*s}" height="${7*s}" fill="#2a1a14"/>
 <ellipse cx="${x}" cy="${y+38*s}" rx="${24*s}" ry="${32*s}" fill="#e2352b" stroke="#ffb347" stroke-width="${2*s}"/>
 <ellipse cx="${x}" cy="${y+38*s}" rx="${12*s}" ry="${28*s}" fill="none" stroke="#ffcf6a" stroke-width="${1.5*s}" opacity=".7"/>
 <rect x="${x-14*s}" y="${y+69*s}" width="${28*s}" height="${7*s}" fill="#2a1a14"/>`;}
// lower haze replacing the old wall band; distant pagoda town silhouettes
function lowerHaze(){svg(`<defs><linearGradient id=lh x1=0 y1=0 x2=0 y2=1><stop offset=0 stop-color="#1c1528" stop-opacity=0 /><stop offset=".12" stop-color="#211830"/><stop offset="1" stop-color="#0f0a18"/></linearGradient>
 <radialGradient id=gl cx=.5 cy=.5 r=.5><stop offset=0 stop-color="#ff8fc0" stop-opacity=".35"/><stop offset=1 stop-color="#ff8fc0" stop-opacity=0 /></radialGradient></defs>
 <rect x=0 y=690 width=1920 height=390 fill="url(#lh)"/><ellipse cx=960 cy=780 rx=1100 ry=90 fill="url(#gl)"/>
 <path fill="#2a1f3d" d="M0 800 L80 800 L80 770 L60 770 L110 745 L160 770 L140 770 L140 800 L300 800 L300 760 L270 760 L330 725 L390 760 L360 760 L360 790 L380 790 L330 765 L280 790 L300 790 Z M1500 800 L1540 800 L1540 765 L1515 765 L1580 728 L1645 765 L1620 765 L1620 800 L1760 800 L1760 775 L1740 775 L1800 745 L1860 775 L1840 775 L1840 800 L1920 800 L1920 1080 L0 1080 Z"/>
 <path fill="#251b36" d="M0 815 Q480 790 960 805 Q1440 790 1920 815 L1920 1080 L0 1080Z"/>`,1);}
// lift everything above the haze so the bar also clears the roof edge on 2.16:1 phones (Crop trims top and bottom there)
function lift(n,fill){const k=[...document.getElementById('s').children];k.slice(2).forEach(e=>{e.style.transform=`translateY(${-n}px) `+(e.style.transform||'');});
 const b=document.createElement('div');b.style.cssText=`left:0;top:${1080-n-2}px;width:1920px;height:${n+2}px;background:${fill};z-index:30`;document.getElementById('s').appendChild(b);}

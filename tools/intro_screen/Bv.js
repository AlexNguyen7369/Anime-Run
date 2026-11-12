// B variations: gate scene split into layers so figures sit between them (draft only)
let fid=0;
// blended figure: erode baked outline, grade to dusk, backlight rim, blur, fade bust bottom
function F(id,x,y,w,o){o=Object.assign({sat:.5,bright:.6,haze:.35,hz:[96,52,72],rim:'#ffb070',rimA:.9,rdx:0,rdy:4,blur:.6,fade:[55,85],z:4,rot:0},o);
 const k='f'+(fid++),e=Math.max(1,w*11/512),r=Math.max(1.5,w*5/512),m=o.haze,b=o.bright*(1-m);
 const defs=document.getElementById('fx');
 defs.insertAdjacentHTML('beforeend',`<filter id="${k}" x="-5%" y="-5%" width="110%" height="110%" color-interpolation-filters="sRGB">
  <feMorphology in="SourceAlpha" operator="erode" radius="${e}" result="a"/><feGaussianBlur in="a" stdDeviation="${e*.35}" result="sa"/>
  <feComposite in="SourceGraphic" in2="sa" operator="in" result="cut"/>
  <feColorMatrix in="cut" type="saturate" values="${o.sat}" result="ds"/>
  <feComponentTransfer in="ds" result="tn"><feFuncR type="linear" slope="${b}" intercept="${m*o.hz[0]/255}"/><feFuncG type="linear" slope="${b}" intercept="${m*o.hz[1]/255}"/><feFuncB type="linear" slope="${b}" intercept="${m*o.hz[2]/255}"/><feFuncA type="identity"/></feComponentTransfer>
  <feComposite in="tn" in2="sa" operator="in" result="tn2"/>
  <feOffset in="sa" dx="${-o.rdx*r}" dy="${-o.rdy*r/2}" result="sh"/><feComposite in="sa" in2="sh" operator="out" result="edge"/>
  <feFlood flood-color="${o.rim}" flood-opacity="${o.rimA}"/><feComposite in2="edge" operator="in" result="rc"/><feGaussianBlur in="rc" stdDeviation="${r*.4}" result="rim"/>
  <feMerge result="mg"><feMergeNode in="tn2"/><feMergeNode in="rim"/></feMerge><feGaussianBlur in="mg" stdDeviation="${o.blur}"/></filter>`);
 const i=document.createElement('img');i.src='src/p/'+id+'.png';
 i.style.cssText=`left:${x-w/2}px;top:${y}px;width:${w}px;z-index:${o.z};filter:url(#${k});transform:rotate(${o.rot}deg);-webkit-mask-image:linear-gradient(to bottom,#000 ${o.fade[0]}%,transparent ${o.fade[1]}%)`;
 document.getElementById('s').appendChild(i);}
document.getElementById('s').insertAdjacentHTML('beforeend','<svg width=0 height=0 style="position:absolute"><defs id=fx></defs></svg>');
lowerHaze();
// back: glow, court, steps
let steps='';for(let k=0;k<4;k++){const y=905+k*45;steps+=`<path d="M0 ${y} Q960 ${y-25} 1920 ${y}" stroke="#f2c14e" stroke-width="2" opacity="${.35-k*.07}" fill="none"/>`;}
svg(`<defs><radialGradient id=gate cx=.5 cy=.55 r=.5><stop offset=0 stop-color="#ffb070" stop-opacity=".55"/><stop offset=.6 stop-color="#ff6ea8" stop-opacity=".18"/><stop offset=1 stop-color="#ff6ea8" stop-opacity="0"/></radialGradient>
 <radialGradient id=core><stop offset=0 stop-color="#ffd09a" stop-opacity=".55"/><stop offset=1 stop-color="#ffd09a" stop-opacity="0"/></radialGradient><linearGradient id=court x1=0 y1=0 x2=0 y2=1><stop offset=0 stop-color="#2b2140"/><stop offset=1 stop-color="#120c1c"/></linearGradient></defs>
 <ellipse cx=960 cy=790 rx=560 ry=300 fill="url(#gate)"/><ellipse cx=960 cy=805 rx=420 ry=70 fill="url(#gate)"/><ellipse cx=960 cy=800 rx=330 ry=60 fill="url(#core)"/>
 <path d="M0 890 Q960 860 1920 890 L1920 1080 L0 1080Z" fill="url(#court)"/>${steps}`,2);
// ground mist that swallows the faded bust bottoms (above far figures, below torii)
function mist(z){let p='';for(let x=610;x<=1310;x+=70)p+=`<rect x=${x-5} y=812 width=10 height=48 fill="#1a1226"/>`;svg(`<defs><linearGradient id=ms${z} x1=0 y1=0 x2=0 y2=1><stop offset=0 stop-color="#3a2a48" stop-opacity=0 /><stop offset=.55 stop-color="#3a2a48" stop-opacity=".75"/><stop offset=1 stop-color="#2b2140"/></linearGradient></defs>
 <rect x=0 y=815 width=1920 height=85 fill="url(#ms${z})"/><rect x=590 y=826 width=740 height=40 fill="#21182f"/>${p}<rect x=590 y=808 width=740 height=8 rx=3 fill="#2c2038"/><rect x=590 y=807 width=740 height=2 fill="#f2c14e" opacity=".6"/>`,z);}
// torii + lanterns
function torii(z){svg(`<defs><linearGradient id=lac x1=0 y1=0 x2=1 y2=0><stop offset=0 stop-color="#8e1a1a"/><stop offset=.45 stop-color="#d4382c"/><stop offset=1 stop-color="#8e1a1a"/></linearGradient></defs>
 <rect x=528 y=600 width=60 height=420 fill="url(#lac)"/><rect x=1332 y=600 width=60 height=420 fill="url(#lac)"/>
 <rect x=518 y=985 width=80 height=40 fill="#1a1010"/><rect x=1322 y=985 width=80 height=40 fill="#1a1010"/>
 <rect x=470 y=660 width=980 height=34 fill="url(#lac)"/><rect x=470 y=694 width=980 height=4 fill="#f2c14e"/>
 <path d="M380 560 Q960 600 1540 560 L1520 596 Q960 628 400 596Z" fill="#1d1420"/>
 <path d="M410 596 Q960 628 1510 596 L1500 622 Q960 650 420 622Z" fill="url(#lac)"/>
 <path d="M380 560 Q960 600 1540 560" stroke="#f2c14e" stroke-width="5" fill="none"/>
 <path d="M372 552 Q960 592 1548 552" stroke="#00f0ff" stroke-width="2" fill="none" opacity=".7"/>
 <rect x=920 y=630 width=80 height=30 fill="#1d1420" stroke="#f2c14e" stroke-width="3"/>${blossom(960,645,14)}
 ${lantern(700,700,0.9)}${lantern(1220,700,0.9)}`,z);}
function branch(m,low){let s=`<g transform="${m}"><path d="M-20 -10 C 120 80, 240 120, 470 150 M120 70 C 160 160, 210 210, 300 250 M260 120 C 320 60, 380 40, 450 40" stroke="#3a2420" stroke-width="16" fill="none" stroke-linecap="round"/>`;
 const pts=[[470,150],[420,140],[360,130],[300,250],[260,225],[220,190],[450,40],[400,45],[330,80],[180,110],[90,50],[40,25],[500,170],[150,150],[230,250],[340,110]];
 if(low){s+=`<path d="M-20 520 C 100 550, 220 590, 320 640" stroke="#3a2420" stroke-width="13" fill="none" stroke-linecap="round"/>`;pts.push([300,628],[250,604],[180,575],[120,556]);}
 pts.forEach(([x,y])=>{s+=blossom(x,y,26+rnd()*14);s+=blossom(x+30*rnd()-15,y+30+20*rnd(),18+rnd()*10);});return s+'</g>';}
function front(n,low,z){svg(branch('',low)+branch('translate(1920 0) scale(-1 1)',low)+petals(n,0,1920,30,1060,(x,y)=>(x>540&&x<1380&&y<540)||(x>560&&x<1360&&y>870)),z||9);}
// variations
if(V==1){ // silhouettes under the gate, backlit
 mist(5);torii(6);
 [['sea_captain',775,705,200],['jk_strongest',890,690,215],['db_hero',1030,688,220],['leaf_hero',1145,708,195]].forEach(([id,x,y,w])=>F(id,x,y-32,w,{bright:.32,sat:.35,haze:.3,rim:'#ffc07a',rimA:1,rdy:-5,blur:.6,z:4,fade:[55,82]}));
 front(70,false);
}
if(V==2){ // painted in at different depths, overlapped by branches/lanterns/petals
 F('ds_flame',840,680,175,{bright:.42,sat:.45,haze:.35,rdy:-5,blur:1.1,z:4,fade:[55,82]});
 F('leaf_crow',1085,688,165,{bright:.38,sat:.45,haze:.38,rdy:-5,blur:1.2,z:4,fade:[55,82]});
 mist(5);torii(6);
 F('jk_strongest',320,575,320,{bright:.8,sat:.7,haze:.22,rdx:3,rdy:-1,rim:'#ffb070',blur:.8,z:7,fade:[52,88],rot:4});
 F('db_hero',1600,575,320,{bright:.8,sat:.7,haze:.22,rdx:-3,rdy:-1,rim:'#ffb070',blur:.8,z:7,fade:[52,88],rot:-4});
 svg(lantern(150,640,1.15)+lantern(1770,640,1.15),8);
 front(110,true);
}
if(V==3){ // distant crowd in the glow
 const back=[['mha_hero',700,760,125],['sea_captain',820,752,135],['jk_king',1100,755,130],['leaf_crow',1220,762,120]];
 const fr=[['leaf_hero',750,768,150],['jk_strongest',900,748,165],['db_hero',1020,745,170],['ds_flame',1160,768,150]];
 back.forEach(([id,x,y,w])=>F(id,x,y-50,w,{bright:.2,sat:.3,haze:.42,rim:'#ffb070',rimA:.8,rdy:-5,blur:1.2,z:3,fade:[50,80]}));
 fr.forEach(([id,x,y,w])=>F(id,x,y-52,w,{bright:.28,sat:.4,haze:.3,rim:'#ffc890',rimA:1,rdy:-6,blur:.8,z:4,fade:[52,82]}));
 mist(5);torii(6);
 front(120,false);
 svg(petals(26,600,1320,640,860),10);
}

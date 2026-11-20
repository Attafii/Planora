const fs = require('fs');
const path = require('path');
const sharp = require('C:/Users/Ahmed Attafi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(__dirname, 'approved-logo.png'));
const b64 = b => 'data:image/png;base64,' + b.toString('base64');
const navy = '#011133', blue = '#0174FB', teal = '#01C0C2', violet = '#4C58FC', paper = '#FAF9F6', gray = '#637083';
const W = 1800, H = 13280;
const parts = [];
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const rect = (x,y,w,h,c,r=0,extra='') => parts.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}" rx="${r}" ${extra}/>`);
const line = (x1,y1,x2,y2,c='#D6D9DB',width=1,extra='') => parts.push(`<path d="M${x1} ${y1}L${x2} ${y2}" fill="none" stroke="${c}" stroke-width="${width}" ${extra}/>`);
const text = (s,x,y,size=24,color=navy,weight=400,font='Inter',extra='') => parts.push(`<text x="${x}" y="${y}" font-family="${font}" font-size="${size}" fill="${color}" font-weight="${weight}" ${extra}>${esc(s)}</text>`);
const multi = (arr,x,y,size=24,color=navy,weight=400,leading=1.45,font='Inter') => arr.forEach((s,i)=>text(s,x,y+i*size*leading,size,color,weight,font));
const label = (s,x,y,color=gray)=>text(s.toUpperCase(),x,y,18,color,500,'Inter','letter-spacing="3"');
const section = (n,title,y,color=navy)=>{line(90,y,1710,y);label(n+' / '+title,90,y+45,color);};
const logo = (x,y,w)=>{parts.push(`<svg x="${x}" y="${y}" width="${w}" height="${w*467/1705}" viewBox="162 167 1705 467" preserveAspectRatio="xMidYMid meet"><use href="#logoSource"/></svg>`);};
const mark = (x,y,w,opacity=1)=>parts.push(`<svg x="${x}" y="${y}" width="${w}" height="${w*467/432}" viewBox="158 167 432 467" opacity="${opacity}" preserveAspectRatio="xMidYMid meet"><use href="#logoSource"/></svg>`);
const word = (x,y,w)=>parts.push(`<svg x="${x}" y="${y}" width="${w}" height="${w*380/1227}" viewBox="641 253 1227 380" preserveAspectRatio="xMidYMid meet"><use href="#logoSource"/></svg>`);
const photo = (id,x,y,w,h)=>parts.push(`<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="0 0 1536 1024" preserveAspectRatio="xMidYMid slice"><use href="#${id}"/></svg>`);
const dot = (x,y,r,c)=>parts.push(`<circle cx="${x}" cy="${y}" r="${r}" fill="${c}"/>`);
const pill = (x,y,w,h,c)=>rect(x,y,w,h,c,h/2);
const smallTitle=(s,x,y)=>text(s,x,y,30,navy,650,'Manrope');
const icon=(kind,x,y,scale=1,color=navy)=>{
 parts.push(`<g transform="translate(${x} ${y}) scale(${scale})" fill="none" stroke="${color}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">`);
 if(kind==='plan')parts.push('<path d="M8 10h25M8 22h19M8 34h12"/><circle cx="37" cy="10" r="3" fill="currentColor"/>');
 if(kind==='focus')parts.push('<circle cx="24" cy="24" r="17"/><path d="M24 13v12h9"/><circle cx="24" cy="24" r="2"/>');
 if(kind==='goal')parts.push('<path d="M9 37V19c0-10 25-15 25-2s-25 10-25 20"/><circle cx="34" cy="17" r="3"/>');
 if(kind==='adapt')parts.push('<path d="M10 35V20c0-10 24-10 24 0v15M10 35h8M34 35h-8"/><circle cx="34" cy="14" r="3"/>');
 parts.push('</g>');
};

async function main(){
 for (const name of ['Manrope','Inter']) {
  await sharp({text:{text:'Planify',font:name+' 32',fontfile:path.join(__dirname,name+'.ttf'),rgba:true}}).png().toBuffer();
 }
 const archPath='C:/Users/Ahmed Attafi/.codex/generated_images/01a130fc-fd41-7192-9a9a-5644837ef01d/exec-5cd64d58-ce8f-47e9-8bd7-8c8ffa12f8a0.png';
 const prodPath='C:/Users/Ahmed Attafi/.codex/generated_images/01a130fc-fd41-7192-9a9a-5644837ef01d/exec-9e6ccba3-ac2c-4a15-bc6d-0968e2a30a8d.png';
 fs.copyFileSync(archPath,path.join(__dirname,'architecture.png'));
 fs.copyFileSync(prodPath,path.join(__dirname,'materials.png'));
 const defs=`<defs><image id="logoSource" width="2011" height="782" href="${b64(source)}"/><image id="architecture" width="1536" height="1024" href="${b64(await sharp(archPath).resize(1536,1024,{fit:'cover'}).png().toBuffer())}"/><image id="materials" width="1536" height="1024" href="${b64(await sharp(prodPath).resize(1536,1024,{fit:'cover'}).png().toBuffer())}"/><linearGradient id="brandGrad"><stop stop-color="${blue}"/><stop offset=".54" stop-color="${teal}"/><stop offset="1" stop-color="${violet}"/></linearGradient><linearGradient id="softGrad" x2="1" y2="1"><stop stop-color="#EBFBFA"/><stop offset="1" stop-color="#EDEFFC"/></linearGradient></defs>`;
 rect(0,0,W,H,paper);
 // 01. Cover: large identity, editorial tension, architectural daylight.
 label('Planify / Brand identity system',90,85);
 label('Edition 01 — October 2026',1300,85);
 logo(90,180,780);
 text('Make room',90,500,122,navy,650,'Manrope');
 text('for life.',90,640,122,navy,650,'Manrope');
 multi(['A considered system for adaptive planning.', 'Clarity in the schedule. Freedom in the day.'],95,735,29,gray);
 pill(95,875,280,20,teal);pill(95,915,210,20,blue);pill(95,955,140,20,violet);
 photo('architecture',1110,180,600,760);
 multi(['Calm direction.', 'Measured momentum.', 'Human control.'],800,885,25,navy,500);
 text('Identity derived from the supplied artwork. Original logo preserved throughout.',90,1050,19,gray);
 // 02. Analysis and logo system.
 section('01','The idea inside the mark',1130);
 text('A flexible path.',90,1290,72,navy,650,'Manrope');
 mark(140,1400,450);
 label('Observed formal language',800,1390);
 multi(['A continuous P-shaped arc joins a circular endpoint.', 'Three rounded bars descend in scale: time, broken', 'into manageable units. Circular counters and soft', 'corners repeat across the heavy lowercase wordmark.'],800,1450,27,navy,400,1.55);
 label('Positioning & audience',800,1670);
 multi(['An approachable, premium productivity companion', 'for students, independent professionals and small teams.', 'Navy provides authority; cool color provides momentum.', 'The personality is confident, helpful and unhurried.'],800,1730,26,gray,400,1.55);
 label('Primary lockup / original artwork',90,1980);
 logo(90,2030,680);
 label('Secondary / stacked',1010,1960);
 mark(1145,2010,100);word(1060,2140,270);
 label('Signet',1440,1960);mark(1485,2020,145);
 text('Only framing and placement change. The source shapes, colors and proportions do not.',90,2250,20,gray);
 // 03. Core usage standards.
 section('02','Protection, scale & responsive use',2340);
 text('Give the mark room.',90,2490,65,navy,650,'Manrope');
 label('Clearspace',90,2570);
 rect(145,2630,800,285,'none',0,'stroke="#9EA7AF" stroke-dasharray="7 7"');
 logo(205,2690,680);
 line(145,2605,205,2605,teal,2);line(145,2595,145,2615,teal,2);line(205,2595,205,2615,teal,2);
 text('x',170,2595,24,teal,600);
 multi(['x = diameter of the circular endpoint.', 'Keep at least 1x clearspace around every version.', 'The primary artwork measures approximately 3.65:1.'],90,2970,24,gray);
 label('Minimum reproduction',1100,2570);
 multi(['Primary  /  160 px · 35 mm', 'Signet  /  24 px · 6 mm', 'Use the signet below the lockup threshold.', 'These are conservative starting limits;', 'confirm legibility on the final material.'],1100,2630,26,navy,400,1.55);
 label('Light & dark',1100,2880);
 logo(1100,2920,470);
 rect(1080,3070,570,155,navy,10);rect(1115,3087,500,121,paper,4);logo(1155,3100,410);
 text('On dark: use a light protection panel.',1100,3260,21,gray);
 label('Underlying layout system / flexible editorial composition',90,3160);
 for(let i=0;i<12;i++)rect(90+i*77,3200,61,86,i%3===0?'#DAE5F1':'#EEF0F1',4);
 text('12 columns / desktop     4 / mobile     8 px spacing base     24–32 px gutters',90,3325,21,gray);
 // 04. The color system.
 section('03','Color anchors sampled from the logo',3420);
 text('Authority, with energy.',90,3570,67,navy,650,'Manrope');
 const cols=[['Ink',navy],['Route blue',blue],['Endpoint teal',teal],['Momentum violet',violet],['Paper',paper]];
 cols.forEach(([name,c],i)=>{
  const x=90+i*328, y=3650;
  rect(x,y,300,i===0?245:190,c,0,c===paper?'stroke="#D6D9DB"':'');
  const yy=3930;smallTitle(name,x,yy);
  const rgb=[1,3,5].map(k=>parseInt(c.slice(k,k+2),16));
  const mx=Math.max(...rgb)/255,k=1-mx;
  const cm=rgb.map(v=>Math.round((mx===0?0:(1-v/255-k)/(1-k))*100)).concat(Math.round(k*100));
  text(c.toUpperCase(),x,yy+42,23,navy,500);
  text('RGB  '+rgb.join(' / '),x,yy+78,21,gray);
  text('CMYK  '+cm.join(' / '),x,yy+112,19,gray);
  text('Pantone  /  physical match',x,yy+146,18,gray);
 });
 rect(90,4140,1020,24,'url(#brandGrad)',12);
 multi(['The gradient belongs to the route symbol.', 'Use it selectively.', 'Keep reading surfaces neutral.'],1180,4147,22,gray);
 text('sRGB anchors from source pixels. CMYK is an unprofiled estimate. Pantone codes require a physical swatch proof.',90,4280,19,gray);
 // 05. Type and hierarchy.
 section('04','Typography & hierarchy',4360);
 text('Clear by',90,4540,114,navy,600,'Manrope');text('design.',90,4670,114,navy,600,'Manrope');
 label('Manrope / display',95,4750);
 multi(['Open geometry follows the logo’s circular counters.', 'A confident headline, without competing with the mark.'],95,4810,26,gray);
 text('Aa Bb Cc 0123456789',90,4930,40,navy,500,'Manrope');
 label('Inter / interface & body',1000,4480);
 multi(['Plan a day that fits.', 'Make a realistic choice.', 'Stay in control when plans change.'],1000,4550,32,navy,400,1.5);
 line(1000,4750,1690,4750);
 [['H1 / 112 px / 600','Direction'],['H2 / 64 px / 600','Focus'],['H3 / 40 px / 600','Next action'],['Body / 24 px / 400','Useful detail'],['Meta / 18 px / 500','Quiet context']].forEach(([a,b],i)=>{text(a,1000,4810+i*58,21,gray);text(b,1390,4810+i*58,27,navy,500);});
 multi(['Generous line-height. Left-aligned paragraphs.', 'Two families. Three weights. One clear reading order.', 'The supplied wordmark is artwork, not typeset Manrope.'],90,5080,25,gray);
 // 06. Pattern, icon and illustration grammar.
 section('05','Graphic grammar',5300);
 text('The route becomes a system.',90,5450,65,navy,650,'Manrope');
 rect(90,5530,840,510,'#EEF5F5');
 for(let row=0;row<2;row++)for(let col=0;col<4;col++)mark(125+col*205,5570+row*226,160,.22);
 label('Pattern / repeat the intact signet',90,6090);
 label('Graphic elements / circular endpoints + rounded blocks',1020,5530);
 parts.push(`<path d="M1060 5780V5685 Q1060 5620 1185 5620 T1310 5685 Q1310 5750 1185 5750" fill="none" stroke="${teal}" stroke-width="22" stroke-linecap="round"/>`);
 dot(1300,5685,21,teal);pill(1049,5825,225,28,blue);pill(1049,5875,165,28,violet);pill(1049,5925,100,28,teal);
 multi(['The illustration language is diagrammatic.', 'Paths connect meaningful states; blocks describe time.', 'No decorative mascots or unrelated forms.'],1020,6010,23,gray);
 label('Custom icon family / shared radius, rounded ends, 3 px stroke',90,6200);
 ['plan','focus','goal','adapt'].forEach((k,i)=>{icon(k,110+i*360,6250,1.5,navy);text(['Plan','Focus','Goal','Adapt'][i],200+i*360,6297,26,navy,500);});
 // 07. Photography and tone.
 section('06','Atmosphere & behavior',6460);
 photo('architecture',0,6540,1080,800);
 label('Photography / campaign direction',1160,6610);
 text('Room to think.',1160,6690,48,navy,600,'Manrope');
 multi(['Natural light. Real materials.', 'Architectural rhythm. Honest work.', 'Navy shadows and warm neutral surfaces.', 'No posed portraits or productivity clichés.'],1160,6770,25,gray,400,1.5);
 label('Tone of voice',1160,6980);
 multi(['Clear. Calm. Specific.', '“You have 90 minutes available.”', '“Would you like to move this task?”', 'Use helpful choices; avoid guilt and hype.'],1160,7040,24,navy,400,1.5);
 multi(['BRAND VALUES', 'Clarity / Adaptability / Agency', 'DESIGN PRINCIPLES', 'Reduce noise. Preserve trust.', 'Show the next useful action.'],1160,7240,21,gray,400,1.5);
 text('Generated campaign study / architectural light and material direction.',90,7430,18,gray);
 // 08. Product and web identity.
 section('07','Digital applications',7500);
 text('One identity.',90,7660,75,navy,650,'Manrope');text('Every screen.',90,7750,75,navy,650,'Manrope');
 // Website canvas.
 rect(90,7820,1110,760,'#FFFFFF',16,'stroke="#D8DDE2"');
 rect(90,7820,1110,40,'#EEF1F3',16);dot(114,7841,4,'#B8C0CB');dot(131,7841,4,'#B8C0CB');dot(148,7841,4,'#B8C0CB');
 logo(135,7900,230);text('Product     Planning     About',675,7940,18,gray);pill(1020,7900,130,45,navy);text('Get started',1040,7929,15,'#FFFFFF',500);
 multi(['Your day,', 'with room', 'to change.'],140,8060,63,navy,600,1.12,'Manrope');
 multi(['A realistic plan. A focused next step.', 'The freedom to adapt.'],145,8308,22,gray);
 pill(145,8380,195,54,navy);text('Plan my day',175,8415,20,'#FFFFFF',500);
 rect(730,8010,420,425,'#F2F6F8',16);label('Today',765,8060);text('Tuesday',765,8110,30,navy,600,'Manrope');
 [['09:00','Deep work',blue],['11:00','Review',teal],['14:00','Project time',violet]].forEach(([time,a,c],i)=>{rect(755,8150+i*83,360,65,'#FFFFFF',8);rect(755,8150+i*83,5,65,c,2);text(time,775,8189+i*83,17,gray);text(a,862,8189+i*83,19,navy,500);});
 label('Website / identity application',90,8630);
 // Mobile viewport, right and taller.
 rect(1300,7700,390,900,'#152035',54);rect(1314,7714,362,872,'#FFFFFF',43);pill(1425,7730,140,28,'#152035');text('9:41',1340,7753,18,navy,600);
 logo(1340,7800,210);text('Today',1340,7910,44,navy,600,'Manrope');text('Tuesday, 13 October',1340,7950,18,gray);
 [['09:00','Deep work','60 min',blue],['11:00','Team review','30 min',teal],['14:00','Study session','45 min',violet]].forEach(([time,a,b,c],i)=>{text(time,1340,8025+i*120,17,gray);rect(1400,7990+i*120,250,88,'#F2F6F8',14);rect(1400,7990+i*120,5,88,c,2);text(a,1420,8025+i*120,20,navy,550);text(b,1420,8055+i*120,16,gray);});
 pill(1340,8390,310,60,navy);text('Start focus',1420,8428,22,'#FFFFFF',500);line(1340,8485,1650,8485);text('Today    Tasks    Goals',1355,8530,18,gray);
 label('Mobile / focus over density',1300,8640);
 // Desktop laptop mockup.
 rect(380,8740,1240,700,'#172137',22);rect(397,8757,1206,659,'#FFFFFF',7);rect(397,8757,220,659,'#EEF3F7',0);logo(420,8795,165);
 ['Today','Calendar','Tasks','Goals','Reports'].forEach((a,i)=>text(a,433,8900+i*62,21,i===1?blue:gray,i===1?600:400));
 text('Your week',670,8840,42,navy,600,'Manrope');text('A plan that fits your available time.',670,8890,21,gray);
 for(let i=0;i<5;i++){text(['MON','TUE','WED','THU','FRI'][i],710+i*175,8970,18,gray);line(681+i*175,9000,681+i*175,9320,'#E5E9EF');}
 for(let i=0;i<5;i++)line(680,9000+i*65,1540,9000+i*65,'#E5E9EF');
 [[702,9025,135,70,blue],[877,9135,135,90,teal],[1052,9060,135,100,violet],[1227,9190,135,60,blue],[1402,9050,115,78,teal]].forEach(([x,y,w,h,c])=>rect(x,y,w,h,c,9));
 parts.push('<path d="M320 9440H1680L1610 9485H390Z" fill="#BEC5CC"/>');
 label('Desktop / calm planning workspace',90,9520);
 text('Brand application studies. Product screens illustrate the identity; they are not implementation screenshots.',90,9540,18,gray);
 // 09. Editorial communication across social, presentation and OOH.
 section('08','Communication in the real world',9640);
 text('Say less. Mean more.',90,9795,68,navy,650,'Manrope');
 rect(90,9860,550,570,navy);rect(130,9900,300,95,paper,2);logo(155,9920,250);
 multi(['A day', 'that fits.'],140,10140,72,'#FFFFFF',600,1.1,'Manrope');pill(140,10370,155,13,teal);pill(140,10400,95,13,blue);
 label('Social / one message, one gesture',90,10490);
 rect(730,9860,980,560,'#FFFFFF',0,'stroke="#E0E4E8"');logo(780,9910,240);label('Planning with agency',780,10045);
 multi(['Clarity creates', 'momentum.'],780,10135,58,navy,600,1.15,'Manrope');
 text('01 / A realistic plan',790,10315,23,gray);text('02 / A focused action',790,10355,23,gray);text('03 / An adaptive day',790,10395,23,gray);
 mark(1450,10040,160);label('Presentation / restrained master slide',730,10490);
 rect(90,10570,1620,510,'#DDE2E3');rect(230,10610,1320,360,paper);line(360,10975,360,11080,'#687780',11);line(1410,10975,1410,11080,'#687780',11);
 logo(285,10655,390);multi(['Make room', 'for what matters.'],290,10820,62,navy,600,1.05,'Manrope');
 mark(1200,10665,190);label('Out-of-home / distance, contrast, singular message',90,11135);
 // 10. Realistic material application photography, exact logo placement.
 section('09','Material expressions',11220);
 text('Quiet confidence, made tangible.',90,11365,61,navy,650,'Manrope');
 photo('materials',90,11420,1200,800);
 // Photograph is 1536 x 1024. Products mapped to the artboard at 0.78125 scale.
 rect(258,11790,330,100,paper,3);logo(286,11811,274);
 logo(797,11537,225);
 logo(845,11967,280);
 label('Business card / stationery / merchandise',90,12265);
 label('Specification',1350,11470);
 multi(['Cotton paper, 350 gsm.', 'Emboss on a light field.', 'Navy cloth, quiet placement.', 'Cream cotton, full color.', 'Faithful, flat artwork.'],1350,11535,24,gray,400,1.65);
 label('Digital product scope',1350,11810);
 multi(['Packaging and fleet identity', 'sit outside the app’s current scope.', 'Add physical formats when', 'a real use case emerges.'],1350,11870,23,gray,400,1.6);
 text('Generated material mockup photography with the supplied logo placed directly. No logo redrawing.',90,12315,18,gray);
 // 11. Motion and usage governance.
 section('10','Motion & standards',12400);
 label('Motion / the artwork stays intact',90,12475);
 [0,1,2].forEach(i=>{rect(90+i*355,12515,315,235,'#EEF3F5',6);mark(150+i*355,12555,135,[.25,.65,1][i]);text(['0 ms / arrive','180 ms / settle','360 ms / hold'][i],110+i*355,12785,21,gray);});
 text('A short eased entrance. Animate the complete mark; never deform its geometry.',90,12845,22,gray);
 label('Do',1240,12475,teal);
 multi(['Use the supplied source.', 'Respect clearspace and proportion.', 'Keep contrast and copy calm.'],1240,12535,23,navy,400,1.6);
 label('Do not',1240,12685,violet);
 multi(['Stretch, redraw or recolor the logo.', 'Place navy lettering directly on navy.', 'Add shadows, hype or decoration.'],1240,12745,23,navy,400,1.6);
 line(90,12910,1710,12910);
 logo(90,12965,365);
 multi(['Planify / Identity system', 'A flexible path. A considered day.'],740,12998,26,navy,500);
 multi(['SOURCE & PRODUCTION', 'Raster artwork preserved. Vector master required for large-format print.', 'CMYK estimates and physical Pantone matching require printer approval.', 'Manrope and Inter: open-source typography. Mockups: visual direction.'],740,13105,18,gray,400,1.55);
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}${parts.join('\n')}</svg>`;
 const master=path.join(root,'planify-brand-guidelines.svg');fs.writeFileSync(master,svg);
 await sharp(Buffer.from(svg),{limitInputPixels:false}).png({compressionLevel:9}).toFile(path.join(root,'planify-brand-guidelines.png'));
 await sharp(path.join(root,'planify-brand-guidelines.png'),{limitInputPixels:false}).resize({width:700}).png().toFile(path.join(root,'planify-brand-guidelines-preview.png'));
 console.log(JSON.stringify({png:path.join(root,'planify-brand-guidelines.png'),width:W,height:H,sourceBytes:source.length}));
}
main().catch(e=>{console.error(e);process.exit(1)});

// Deterministic export of the code-native Planify vector to platform icon sizes.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require(process.argv[2] || 'sharp');
const root = path.resolve(__dirname, '..');
const mark = fs.readFileSync(path.join(root,'assets/branding/planify-symbol.svg'),'utf8');
const inside = mark.slice(mark.indexOf('>')+1, mark.lastIndexOf('</svg>'));
const icon = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><rect width="256" height="256" fill="#051B47"/><g transform="translate(40 40) scale(.88)">${inside}</g></svg>`);
async function png(file, size, source=icon) {
  await sharp(source).resize(size,size).png().toFile(path.join(root,file));
}
(async()=>{
  await png('assets/branding/planify-symbol.png',512,Buffer.from(mark));
  await png('assets/branding/planify-app-icon.png',1024);
  await png('web/favicon.png',32);
  for(const size of [192,512])for(const prefix of ['Icon-','Icon-maskable-']) await png(`web/icons/${prefix}${size}.png`,size);
  for(const [density,size] of Object.entries({mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192}))await png(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`,size);
  for(const folder of ['ios/Runner/Assets.xcassets/AppIcon.appiconset','macos/Runner/Assets.xcassets/AppIcon.appiconset']) {
    const contents=JSON.parse(fs.readFileSync(path.join(root,folder,'Contents.json')));
    for(const image of contents.images)if(image.filename)await png(`${folder}/${image.filename}`,Math.round(parseFloat(image.size)*parseFloat(image.scale)));
  }
  const sizes=[16,32,48,64,128,256];
  const images=await Promise.all(sizes.map(size=>sharp(icon).resize(size,size).png().toBuffer()));
  const header=Buffer.alloc(6+16*sizes.length);header.writeUInt16LE(1,2);header.writeUInt16LE(sizes.length,4);
  let offset=header.length;
  images.forEach((image,i)=>{const entry=6+16*i;header[entry]=sizes[i]===256?0:sizes[i];header[entry+1]=header[entry];header.writeUInt16LE(1,entry+4);header.writeUInt16LE(32,entry+6);header.writeUInt32LE(image.length,entry+8);header.writeUInt32LE(offset,entry+12);offset+=image.length;});
  fs.writeFileSync(path.join(root,'windows/runner/resources/app_icon.ico'),Buffer.concat([header,...images]));
  console.log('Planify vector and platform icons exported.');
})().catch(error=>{console.error(error);process.exitCode=1;});

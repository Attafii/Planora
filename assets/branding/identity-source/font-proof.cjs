const sharp=require('C:/Users/Ahmed Attafi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const path=require('path');
(async()=>{
 await sharp({text:{text:'Font',font:'Manrope 80',fontfile:path.join(__dirname,'Manrope.ttf'),rgba:true}}).png().toBuffer();
 await sharp(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="200"><rect width="1000" height="200" fill="white"/><text x="20" y="120" font-family="Manrope" font-size="80" font-weight="600">Make room for life.</text></svg>')).png().toFile(path.join(__dirname,'font-svg-proof.png'));
 await sharp(path.join(__dirname,'font-proof.png')).flatten({background:'#FFFFFF'}).png().toFile(path.join(__dirname,'font-direct-proof.png'));
})();

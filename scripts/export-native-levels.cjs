const fs=require('node:fs'),path=require('node:path');
const packs=require('../data/adventure.json');
const root=path.resolve(__dirname,'../PenguinPush/Resources/NativeGame');
fs.mkdirSync(root,{recursive:true});
fs.writeFileSync(path.join(root,'levels.json'),JSON.stringify(packs,null,2)+'\n');
fs.copyFileSync(path.resolve(__dirname,'../PenguinPush/Resources/Game/assets/penguins.png'),path.join(root,'penguins.png'));
console.log('Exported native levels and character atlas');

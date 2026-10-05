const fs=require('node:fs'),assert=require('node:assert/strict');
const packs=require('../PenguinPush/Resources/Game/js/levels.js'),Engine=require('../PenguinPush/Resources/Game/js/engine.js');
const exported=JSON.parse(fs.readFileSync('PenguinPush/Resources/NativeGame/levels.json','utf8'));
assert.deepEqual(exported,packs,'Native JSON must preserve every map and pack');
assert.deepEqual(fs.readFileSync('PenguinPush/Resources/NativeGame/penguins.png'),fs.readFileSync('PenguinPush/Resources/Game/assets/penguins.png'));
const point=p=>({x:p[0],y:p[1]}),state=g=>({...g.snapshot(),player:point(g.player),boxes:[...g.boxes].map(k=>point(k.split(',').map(Number)))});
const directions=[[0,1],[-1,0],[1,0],[0,-1]];
let seed=7165;
function random(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;}
const fixtures=packs.flatMap(p=>p.levels.map(level=>{
 const g=new Engine(level),steps=[];
 for(let i=0;i<160;i++){
  const undo=i%11===10,direction=(random()>>>28)%4;
  if(undo)g.undo();else g.move(...directions[direction]);
  steps.push({undo,direction,state:state(g)});
 }
 return{level,steps};
}));
fs.writeFileSync(process.argv[2],JSON.stringify(fixtures));
console.log('PASS native export: 170 maps and original character atlas');

const fs=require('node:fs'),assert=require('node:assert/strict');
const packs=require('../PenguinPush/Resources/Game/js/levels.js'),Engine=require('../PenguinPush/Resources/Game/js/engine.js');
const exported=JSON.parse(fs.readFileSync('PenguinPush/Resources/NativeGame/levels.json','utf8'));
assert.deepEqual(exported,require('../data/adventure.json'),'Native JSON must match the eight adventure stages');
assert.equal(exported.length,1);assert.equal(exported[0].levels.length,8);
assert.deepEqual(fs.readFileSync('PenguinPush/Resources/NativeGame/penguins.png'),fs.readFileSync('PenguinPush/Resources/Game/assets/penguins.png'));
const point=p=>({x:p[0],y:p[1]}),state=g=>({...g.snapshot(),player:point(g.player),boxes:[...g.boxes].map(k=>point(k.split(',').map(Number)))});
const directions=[[0,1],[-1,0],[1,0],[0,-1]];
let seed=7165;
function random(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;}
const solutions=require('../data/adventure-solutions.json');
assert.deepEqual(solutions.map(s=>s.pushes),[2,2,2,2,5,5,6,7]);
const fixtures=[...packs,...exported].flatMap(p=>p.levels.map(level=>{
 const g=new Engine(level),steps=[];
 for(let i=0;i<160;i++){
  const undo=i%11===10,direction=(random()>>>28)%4;
  if(undo)g.undo();else g.move(...directions[direction]);
  steps.push({undo,direction,state:state(g)});
 }
 const solved=p.id==='adventure'?solutions.find(s=>s.id===level.id):null;
 if(solved){const fresh=new Engine(level);for(const letter of solved.solution.toUpperCase()){const direction='DLRU'.indexOf(letter);assert.notEqual(fresh.move(...directions[direction]).type,'blocked');}assert(fresh.won);}
 return{level,steps,solution:solved?.solution,optimalPushes:solved?.pushes};
}));
fs.writeFileSync(process.argv[2],JSON.stringify(fixtures));
console.log('PASS native export: eight adventure stages and original character atlas');

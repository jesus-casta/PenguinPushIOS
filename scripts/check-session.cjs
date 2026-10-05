const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const packs=require('../PenguinPush/Resources/Game/js/levels.js'),Engine=require('../PenguinPush/Resources/Game/js/engine.js');
const level=packs.find(p=>p.id==='tutorial').levels[0],game=new Engine(level);
game.move(1,0);game.move(1,0);
const saved=JSON.parse(JSON.stringify({...game.snapshot(),history:game.history}));
const restored=new Engine(level);assert(restored.restore(saved));assert.deepEqual(restored.snapshot(),game.snapshot());assert(restored.undo());assert(!restored.won);
const invalid=JSON.parse(JSON.stringify(saved));invalid.boxes=['999,999'];assert.equal(new Engine(level).restore(invalid),false);
let stored=null;
function boot(){const elements=new Map(),el=id=>{if(!elements.has(id))elements.set(id,{hidden:['welcome','settings','win'].includes(id),dataset:{},style:{},classList:{toggle(){}},setAttribute(){},addEventListener(){},focus(){},scrollIntoView(){},getBoundingClientRect(){return{top:0}},clientWidth:390,clientHeight:844});return elements.get(id);};
const context={window:{PENGUIN_PACKS:packs,addEventListener(){}},document:{getElementById:el,querySelectorAll(){return[]},addEventListener(){},body:{classList:{toggle(){}},dataset:{}}},localStorage:{getItem(){return stored},setItem(k,v){stored=v}},PenguinSokoban:Engine,PenguinAudio:class{constructor(){this.enabled=true;this.volume=.35}activate(){}play(){}pause(){}},PenguinRenderer:class{constructor(){this.canvas={};this.reducedMotion=true}setGame(){}draw(){}invalidate(){}animate(){}celebrate(){}},performance:{now(){return 0}},requestAnimationFrame(fn){fn()},setTimeout(){return 1},clearTimeout(){},innerWidth:390,innerHeight:844};
vm.runInNewContext(fs.readFileSync('PenguinPush/Resources/Game/js/app.js','utf8'),context);return{el,state:()=>context.window.PenguinPush.getState()};}
let app=boot();assert.equal(app.el('welcome').hidden,true);assert.equal(app.state().pack,'boxxle1');app.el('pack').onchange({target:{value:packs.findIndex(p=>p.id==='tutorial')}});app.el('settingsOpen').onclick();app.el('newGame').onclick();app.el('play').onclick();assert.equal(app.el('welcome').hidden,true);
// Use the lifecycle bridge to check recovery of a previously saved real engine session.
const settings=JSON.parse(stored);settings.session={level:level.id,...saved};stored=JSON.stringify(settings);app=boot();assert.deepEqual(JSON.parse(JSON.stringify(app.state().player)),saved.player);assert.equal(app.state().moves,2);app.el('mobileUndo').onclick();assert.equal(app.state().moves,1);app=boot();assert.equal(app.state().moves,1);assert.equal(app.el('welcome').hidden,true);
console.log('PASS session restore, invalid save rejection, undo after relaunch, direct startup and new-game picker');
let layers=0;
const ctx=new Proxy({},{get(target,key){if(!(key in target))target[key]=key==='createLinearGradient'?()=>({addColorStop(){}}):()=>{};return target[key];}});
const renderContext={document:{createElement(){layers++;return{getContext:()=>ctx}}},Image:class{constructor(){this.complete=false}},performance:{now:()=>0},requestAnimationFrame:()=>1};
vm.runInNewContext(fs.readFileSync('PenguinPush/Resources/Game/js/renderer.js','utf8'),renderContext);
const renderer=new renderContext.PenguinRenderer({width:900,height:1900,getContext:()=>ctx});renderer.setGame(new Engine(level));assert.equal(layers,1);renderer.draw(20);assert.equal(layers,1);renderer.theme='night';renderer.draw(30);assert.equal(layers,2);renderer.invalidate();renderer.draw(40);assert.equal(layers,3);
console.log('PASS static Canvas cache reuse and invalidation');

// Push breadth-first search; uppercase steps walk, lowercase steps push.
const packs=require(require('path').resolve(__dirname,'../PenguinPush/Resources/Game/js/levels.js')),Engine=require(require('path').resolve(__dirname,'../PenguinPush/Resources/Game/js/engine.js'));
const dirs=[[0,1,'D'],[-1,0,'L'],[1,0,'R'],[0,-1,'U']];
function solve(l){const g=new Engine(l),q=[{p:g.player,b:[...g.boxes].sort(),path:''}],seen=new Set();for(let i=0;i<q.length&&i<500000;i++){
 const s=q[i],boxes=new Set(s.b),reach=new Map([[s.p.join(','),'']]),walk=[s.p];
 for(let j=0;j<walk.length;j++){const p=walk[j];for(const[dx,dy,d]of dirs){const n=[p[0]+dx,p[1]+dy],k=n.join(',');if(g.floor.has(k)&&!boxes.has(k)&&!reach.has(k)){reach.set(k,reach.get(p.join(','))+d);walk.push(n)}}}
 const key=s.b.join(';')+'|'+[...reach.keys()].sort()[0];if(seen.has(key))continue;seen.add(key);
 if(s.b.every(k=>g.goals.has(k)))return {solution:s.path,pushes:(s.path.match(/[dlru]/g)||[]).length,states:i};
 for(const b of s.b){const[x,y]=b.split(',').map(Number);for(const[dx,dy,d]of dirs){const behind=[x-dx,y-dy].join(','),to=[x+dx,y+dy].join(',');if(!reach.has(behind)||!g.floor.has(to)||boxes.has(to))continue;if(!g.goals.has(to)){const[a,c]=to.split(',').map(Number),wall=(dx,dy)=>!g.floor.has([a+dx,c+dy].join(','));if((wall(1,0)||wall(-1,0))&&(wall(0,1)||wall(0,-1)))continue;}
 q.push({p:[x,y],b:s.b.filter(k=>k!==b).concat(to).sort(),path:s.path+reach.get(behind)+d.toLowerCase()});}}
 }throw Error('Unsolved '+l.id)}
const levels=require(require('path').resolve(__dirname,'../data/adventure.json'))[0].levels;const results=levels.map(l=>({id:l.id,...solve(l)}));console.log(results);require('fs').writeFileSync(require('path').resolve(__dirname,'../data/adventure-solutions.json'),JSON.stringify(results,null,2));

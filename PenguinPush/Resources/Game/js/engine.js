(function(root){
'use strict';
const key=(x,y)=>x+','+y;
class Sokoban {
 constructor(level){this.level=level;this.reset();}
 reset(){
  const rows=this.level.map;if(!rows||!rows.length)throw Error('Empty level');
  this.width=Math.max(...rows.map(r=>r.length));this.height=rows.length;
  this.walls=new Set();this.floor=new Set();this.goals=new Set();this.boxes=new Set();this.history=[];this.moves=0;this.pushes=0;this.direction=0;
  // Flood the padded border to distinguish outdoors from enclosed floor.
  const at=(x,y)=>rows[y]?.[x]??' ',outside=new Set(),queue=[[-1,-1]];outside.add(key(-1,-1));
  for(let i=0;i<queue.length;i++){const[x,y]=queue[i];for(const[dx,dy]of[[0,1],[0,-1],[1,0],[-1,0]]){let a=x+dx,b=y+dy,k=key(a,b);if(a < -1||b < -1||a>this.width||b>this.height||outside.has(k)||at(a,b)==='#')continue;outside.add(k);queue.push([a,b]);}}
  let players=0;
  rows.forEach((row,y)=>[...row].forEach((c,x)=>{if(!' #.$@+*'.includes(c))throw Error('Unknown tile');const k=key(x,y);if(c==='#'){this.walls.add(k);return;}if(outside.has(k)){if(c!==' ')throw Error('Level is not enclosed');return;}this.floor.add(k);if('.+*'.includes(c))this.goals.add(k);if('$*'.includes(c))this.boxes.add(k);if('@+'.includes(c)){this.player=[x,y];players++;}}));
  if(players!==1||!this.boxes.size||this.boxes.size!==this.goals.size)throw Error('Invalid player/box/goal count');
 }
 get won(){return [...this.boxes].every(k=>this.goals.has(k));}
 move(dx,dy){
  if(Math.abs(dx)+Math.abs(dy)!==1)throw Error('Move must be one orthogonal step');
  if(this.won)return{type:'finished'};
  const oldDirection=this.direction;this.direction=dy===1?0:dx===-1?1:dx===1?2:3;
  const[x,y]=this.player,to=[x+dx,y+dy],k=to.join(','),beyond=[x+2*dx,y+2*dy],b=beyond.join(','),pushing=this.boxes.has(k);
  if(!this.floor.has(k)||(pushing&&(!this.floor.has(b)||this.boxes.has(b))))return{type:'blocked',direction:this.direction};
  this.history.push({player:[...this.player],boxes:[...this.boxes],moves:this.moves,pushes:this.pushes,direction:oldDirection});
  const from=[...this.player];this.player=to;this.moves++;
  if(pushing){this.boxes.delete(k);this.boxes.add(b);this.pushes++;}
  return{type:pushing?'push':'step',from,to,direction:this.direction,box:pushing?{from:to,to:beyond,delivered:this.goals.has(b)}:null,won:this.won};
 }
 undo(){const s=this.history.pop();if(!s)return false;Object.assign(this,s,{boxes:new Set(s.boxes)});return true;}
 get cornerBlocked(){return [...this.boxes].some(k=>{if(this.goals.has(k))return false;const[x,y]=k.split(',').map(Number),wall=(dx,dy)=>!this.floor.has(key(x+dx,y+dy));return(wall(1,0)||wall(-1,0))&&(wall(0,1)||wall(0,-1));});}
 snapshot(){return{player:[...this.player],boxes:[...this.boxes].sort(),moves:this.moves,pushes:this.pushes,direction:this.direction};}
}
if(typeof module!=='undefined'&&module.exports)module.exports=Sokoban;else root.PenguinSokoban=Sokoban;
})(typeof globalThis!=='undefined'?globalThis:this);

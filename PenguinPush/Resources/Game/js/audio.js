(function(root){'use strict';
// Original synthesized effects. No copied recordings and no network requests.
class PenguinAudio {
 constructor(){this.context=null;this.enabled=true;this.volume=.35;this.lastStep=0;}
 activate(){if(!this.enabled)return;try{const C=root.AudioContext||root.webkitAudioContext;if(!C)return;this.context??=new C();if(this.context.state==='suspended')this.context.resume().catch(()=>{});}catch{}}
 setEnabled(value){this.enabled=!!value;if(!this.enabled&&this.context)this.context.suspend().catch(()=>{});}
 tone(frequency,duration,offset=0,type='sine',level=.4,end=frequency){const c=this.context;if(!c)return;const t=c.currentTime+offset,osc=c.createOscillator(),gain=c.createGain();osc.type=type;osc.frequency.setValueAtTime(frequency,t);osc.frequency.exponentialRampToValueAtTime(Math.max(1,end),t+duration);gain.gain.setValueAtTime(0,t);gain.gain.linearRampToValueAtTime(this.volume*level,t+.006);gain.gain.exponentialRampToValueAtTime(.0001,t+duration);osc.connect(gain);gain.connect(c.destination);osc.start(t);osc.stop(t+duration+.02);}
 play(type){if(!this.enabled||this.volume===0)return;this.activate();if(!this.context)return;
 switch(type){case'step':this.tone(180,.055,0,'triangle',.22,110);break;
 case'push':this.tone(95,.12,0,'triangle',.55,42);this.tone(250,.07,.025,'sine',.12,160);break;
 case'goal':this.tone(660,.18,0,'sine',.5);this.tone(880,.22,.08,'sine',.4);break;
 case'blocked':this.tone(120,.065,0,'sine',.25,70);break;
 case'undo':this.tone(480,.1,0,'sine',.3,260);break;
 case'win':[523.25,659.25,783.99,1046.5].forEach((f,i)=>this.tone(f,.3,i*.11,'sine',.5));break;}
 }
 pause(){if(this.context?.state==='running')this.context.suspend().catch(()=>{});}
}
if(typeof module!=='undefined'&&module.exports)module.exports=PenguinAudio;else root.PenguinAudio=PenguinAudio;
})(typeof globalThis!=='undefined'?globalThis:this);

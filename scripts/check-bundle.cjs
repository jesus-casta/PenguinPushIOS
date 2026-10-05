const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),bundle=path.join(root,'PenguinPush/Resources/Game'),manifest=require('../bundle-manifest.json');
for(const[file,hash]of Object.entries(manifest)){const bytes=fs.readFileSync(path.join(bundle,file));assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),hash,'Changed runtime file: '+file);}
const packs=require(path.join(bundle,'js/levels.js')),Sokoban=require(path.join(bundle,'js/engine.js'));assert.equal(packs.find(p=>p.id==='boxxle1').levels.length,108);assert.equal(packs.find(p=>p.id==='classic').levels.length,50);assert.equal(packs.find(p=>p.id==='tutorial').levels.length,12);for(const p of packs)for(const l of p.levels)new Sokoban(l);
const g=new Sokoban(packs.find(p=>p.id==='tutorial').levels[0]);g.move(1,0);g.move(1,0);assert(g.won);assert(g.undo());assert(!g.won);
console.log('PASS bundled game hashes, 108 Boxxle I maps, 50 classics, 12 tutorials, delivery and undo');

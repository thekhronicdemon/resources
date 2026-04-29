const root = document.getElementById('hackRoot');
const loadingScreen = document.getElementById('loadingScreen');
const gameScreen = document.getElementById('gameScreen');
const loadingHackType = document.getElementById('loadingHackType');
const loadingGameName = document.getElementById('loadingGameName');
const loadingTarget = document.getElementById('loadingTarget');
const loadingHint = document.getElementById('loadingHint');
const loadingIcon = document.getElementById('loadingIcon');
const loadingFill = document.getElementById('loadingFill');
const loadingPercent = document.getElementById('loadingPercent');
const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const typingGame = document.getElementById('typingGame');
const typingText = document.getElementById('typingText');
const typingErrors = document.getElementById('typingErrors');
const scoreText = document.getElementById('scoreText');
const targetText = document.getElementById('targetText');
const timeText = document.getElementById('timeText');
const titleText = document.getElementById('hackTitle');
const banner = document.getElementById('banner');
const bannerText = document.getElementById('bannerText');

let currentGame = 'tetris';
let options = {};
let score = 0;
let targetScore = 1000;
let running = false;
let animationId = null;
let timerId = null;
let timeLeft = null;
let loadingId = null;
let loadingTimeout = null;
let loadingActive = false;

const GAME_LABELS = {
    tetris: 'TETRIS HACK',
    flappy: 'FLAPPY BIRD HACK',
    crossy: 'CROSSY ROADS HACK',
    memory: 'MEMORY MATCH HACK',
    typing: 'CODE TYPE HACK'
};

function nuiPost(name, data) {
    fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}) }).catch(() => {});
}
function showBanner(success) {
    banner.className = `banner ${success ? 'success' : 'failed'}`;
    bannerText.textContent = success ? (options.successText || 'Hack Completed') : (options.failedText || 'Hack Failed');
    banner.classList.remove('hidden');
    setTimeout(() => banner.classList.add('hidden'), 2200);
}
function updateHud() {
    scoreText.textContent = score;
    targetText.textContent = targetScore;
    timeText.textContent = timeLeft === null ? '--' : Math.max(0, Math.ceil(timeLeft));
}
function startTimer() {
    clearInterval(timerId);
    if (!options.timeLimit) { timeLeft = null; updateHud(); return; }
    timeLeft = Number(options.timeLimit);
    timerId = setInterval(() => {
        if (!running) return;
        timeLeft -= 1;
        updateHud();
        if (timeLeft <= 0) finish(false, 'time');
    }, 1000);
}
function finish(success, reason) {
    if (!running && !loadingActive) return;
    running = false; loadingActive = false;
    cancelAnimationFrame(animationId); cancelAnimationFrame(loadingId);
    clearTimeout(loadingTimeout); clearInterval(timerId);
    gameScreen.classList.add('hidden'); loadingScreen.classList.add('hidden'); root.classList.add('hidden');
    showBanner(success);
    nuiPost('hackResult', { success, reason, game: currentGame, score, targetScore, difficulty: options.difficulty });
}
function cancelHack(reason='escape') { finish(false, reason); }

document.addEventListener('keydown', (e) => { if ((running || loadingActive) && e.key === 'Escape') cancelHack('escape'); });
window.addEventListener('message', (event) => { if (!event.data || event.data.action !== 'start') return; startHack(event.data.data || {}); });

function startHack(data) {
    options = data;
    currentGame = (data.game || 'tetris').toLowerCase();
    score = 0;
    const fallback = currentGame === 'flappy' ? 20 : currentGame === 'crossy' ? 20 : currentGame === 'memory' ? 8 : currentGame === 'typing' ? 100 : 1000;
    targetScore = Number(data.targetScore || fallback);
    titleText.textContent = data.title || GAME_LABELS[currentGame] || 'PRP HACK';
    updateHud();
    showLoadingScreen();
}
function showLoadingScreen() {
    clearTimeout(loadingTimeout); cancelAnimationFrame(loadingId); cancelAnimationFrame(animationId); clearInterval(timerId);
    running = false; loadingActive = true;
    root.classList.remove('hidden'); gameScreen.classList.add('hidden'); loadingScreen.classList.remove('hidden');
    const label = GAME_LABELS[currentGame] || 'PRP HACK';
    loadingHackType.textContent = `// ${label}`;
    loadingGameName.textContent = label;
    loadingTarget.textContent = currentGame === 'typing' ? `DIFFICULTY: ${(options.difficulty || 'random').toUpperCase()}` : `TARGET: SCORE ${targetScore}`;
    loadingHint.textContent = currentGame === 'flappy' ? 'SPACE / CLICK' : currentGame === 'crossy' ? 'ARROW KEYS' : currentGame === 'memory' ? 'MATCH THE PAIRS' : currentGame === 'typing' ? 'TYPE THE RANDOM CODE' : 'GET READY';
    loadingIcon.className = `loading-icon ${currentGame === 'flappy' ? 'flappy-icon' : currentGame === 'crossy' ? 'crossy-icon' : currentGame === 'memory' ? 'memory-icon' : currentGame === 'typing' ? 'typing-icon' : 'tetris-icon'}`;
    const duration = Number(options.loadingTime || 3200);
    const started = performance.now();
    loadingFill.style.width = '0%'; loadingPercent.textContent = '0%';
    function step(now) {
        if (!loadingActive) return;
        const progress = Math.min(1, (now - started) / duration);
        const eased = progress < .75 ? progress * .9 : .675 + ((progress - .75) / .25) * .325;
        const percent = Math.min(100, Math.floor(eased * 100));
        loadingFill.style.width = `${percent}%`; loadingPercent.textContent = `${percent}%`;
        if (progress < 1) loadingId = requestAnimationFrame(step);
    }
    loadingId = requestAnimationFrame(step);
    loadingTimeout = setTimeout(beginGameAfterLoading, duration + 120);
}
function beginGameAfterLoading() {
    if (!loadingActive) return;
    loadingActive = false; loadingScreen.classList.add('hidden'); gameScreen.classList.remove('hidden');
    canvas.classList.toggle('hidden', currentGame === 'typing');
    typingGame.classList.toggle('hidden', currentGame !== 'typing');
    running = true; updateHud(); startTimer();
    if (currentGame === 'flappy') startFlappy();
    else if (currentGame === 'crossy') startCrossy();
    else if (currentGame === 'memory') startMemory();
    else if (currentGame === 'typing') startTyping();
    else startTetris();
}

// tiny web-audio sfx, no extra files needed
let audioCtx = null;
function beep(freq, dur, type='square', gain=.035) {
    try {
        audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
        const o = audioCtx.createOscillator(); const g = audioCtx.createGain();
        o.type = type; o.frequency.value = freq; g.gain.value = gain;
        o.connect(g); g.connect(audioCtx.destination); o.start();
        o.frequency.exponentialRampToValueAtTime(Math.max(40, freq * .55), audioCtx.currentTime + dur / 1000);
        g.gain.exponentialRampToValueAtTime(.001, audioCtx.currentTime + dur / 1000);
        setTimeout(() => o.stop(), dur + 20);
    } catch(e) {}
}
function keySfx(){ beep(720 + Math.random()*160, 34, 'square', .018); }
function glitchSfx(){ beep(120, 90, 'sawtooth', .055); setTimeout(() => beep(70, 70, 'sawtooth', .04), 35); }

// TETRIS
const COLS = 10, ROWS = 20, BLOCK = 26, TETRIS_X = 80, TETRIS_Y = 20;
const SHAPES = [[[1,1,1,1]],[[1,1],[1,1]],[[0,1,0],[1,1,1]],[[1,0,0],[1,1,1]],[[0,0,1],[1,1,1]],[[1,1,0],[0,1,1]],[[0,1,1],[1,1,0]]];
let board, piece, dropCounter, lastTime;
function startTetris() { board = Array.from({ length: ROWS }, () => Array(COLS).fill(0)); spawnPiece(); dropCounter = 0; lastTime = 0; animationId = requestAnimationFrame(tetrisLoop); }
function spawnPiece() { const matrix = JSON.parse(JSON.stringify(SHAPES[Math.floor(Math.random()*SHAPES.length)])); piece = { matrix, x: Math.floor(COLS/2)-Math.ceil(matrix[0].length/2), y:0 }; if (collides(piece.matrix,piece.x,piece.y)) finish(false,'tetris_topout'); }
function collides(matrix, ox, oy) { for (let y=0;y<matrix.length;y++) for (let x=0;x<matrix[y].length;x++) { if (!matrix[y][x]) continue; const bx=ox+x, by=oy+y; if (bx<0||bx>=COLS||by>=ROWS) return true; if (by>=0&&board[by][bx]) return true; } return false; }
function mergePiece(){ piece.matrix.forEach((row,y)=>row.forEach((v,x)=>{ if(v&&piece.y+y>=0) board[piece.y+y][piece.x+x]=1; })); }
function clearLines(){ let lines=0; outer: for(let y=ROWS-1;y>=0;y--){ for(let x=0;x<COLS;x++) if(!board[y][x]) continue outer; board.splice(y,1); board.unshift(Array(COLS).fill(0)); lines++; y++; } if(lines>0){ score += [0,100,300,500,800][lines] || lines*250; updateHud(); if(score>=targetScore) finish(true,'target_score'); }}
function rotate(matrix){ return matrix[0].map((_,i)=>matrix.map(row=>row[i]).reverse()); }
function tetrisLoop(time=0){ if(!running||currentGame!=='tetris') return; const delta=time-lastTime; lastTime=time; dropCounter+=delta; if(dropCounter>650){ piece.y++; if(collides(piece.matrix,piece.x,piece.y)){ piece.y--; mergePiece(); clearLines(); spawnPiece(); } dropCounter=0; } drawTetris(); animationId=requestAnimationFrame(tetrisLoop); }
function drawTetris(){ ctx.clearRect(0,0,canvas.width,canvas.height); ctx.fillStyle='#07101e'; ctx.fillRect(0,0,canvas.width,canvas.height); ctx.strokeStyle='rgba(255,255,255,.06)'; for(let y=0;y<ROWS;y++) for(let x=0;x<COLS;x++) drawBlock(x,y,board[y][x]); piece.matrix.forEach((row,y)=>row.forEach((v,x)=>{ if(v) drawBlock(piece.x+x,piece.y+y,2); })); }
function drawBlock(x,y,type){ const px=TETRIS_X+x*BLOCK, py=TETRIS_Y+y*BLOCK; if(type){ ctx.fillStyle=type===2?'#38bdf8':'#14b8a6'; ctx.fillRect(px+1,py+1,BLOCK-2,BLOCK-2); } ctx.strokeRect(px,py,BLOCK,BLOCK); }
document.addEventListener('keydown',(e)=>{ if(!running||currentGame!=='tetris'||!piece) return; if(e.key==='ArrowLeft'&&!collides(piece.matrix,piece.x-1,piece.y)) piece.x--; if(e.key==='ArrowRight'&&!collides(piece.matrix,piece.x+1,piece.y)) piece.x++; if(e.key==='ArrowDown'&&!collides(piece.matrix,piece.x,piece.y+1)){ piece.y++; score+=1; updateHud(); } if(e.key==='ArrowUp'){ const r=rotate(piece.matrix); if(!collides(r,piece.x,piece.y)) piece.matrix=r; }});

// FLAPPY
let bird, pipes, flappyLast, gravity, jumpPower, pipeTimer;
function startFlappy(){ bird={x:105,y:260,vy:0,r:15}; pipes=[]; flappyLast=performance.now(); gravity=.38; jumpPower=-7.2; pipeTimer=0; animationId=requestAnimationFrame(flappyLoop); }
function flap(){ if(running&&currentGame==='flappy') bird.vy=jumpPower; }
document.addEventListener('keydown',(e)=>{ if(e.code==='Space') flap(); }); canvas.addEventListener('mousedown', flap);
function addPipe(){ const gap=145; const top=70+Math.random()*260; pipes.push({x:canvas.width+20,top,bottom:top+gap,w:58,passed:false}); }
function flappyLoop(now){ if(!running||currentGame!=='flappy') return; const dt=Math.min(32,now-flappyLast); flappyLast=now; pipeTimer+=dt; if(pipeTimer>1450){ addPipe(); pipeTimer=0; } bird.vy+=gravity; bird.y+=bird.vy; for(const p of pipes){ p.x-=2.7; if(!p.passed&&p.x+p.w<bird.x){ p.passed=true; score+=1; updateHud(); if(score>=targetScore) finish(true,'target_score'); } const inX=bird.x+bird.r>p.x&&bird.x-bird.r<p.x+p.w; if(inX&&(bird.y-bird.r<p.top||bird.y+bird.r>p.bottom)) finish(false,'hit_pipe'); } pipes=pipes.filter(p=>p.x>-80); if(bird.y-bird.r<0||bird.y+bird.r>canvas.height) finish(false,'out_of_bounds'); drawFlappy(); animationId=requestAnimationFrame(flappyLoop); }
function drawFlappy(){ ctx.clearRect(0,0,canvas.width,canvas.height); const sky=ctx.createLinearGradient(0,0,0,canvas.height); sky.addColorStop(0,'#0f2a44'); sky.addColorStop(1,'#07101e'); ctx.fillStyle=sky; ctx.fillRect(0,0,canvas.width,canvas.height); ctx.fillStyle='#14b8a6'; for(const p of pipes){ ctx.fillRect(p.x,0,p.w,p.top); ctx.fillRect(p.x,p.bottom,p.w,canvas.height-p.bottom); } ctx.beginPath(); ctx.arc(bird.x,bird.y,bird.r,0,Math.PI*2); ctx.fillStyle='#facc15'; ctx.fill(); ctx.strokeStyle='rgba(255,255,255,.7)'; ctx.stroke(); }

// CROSSY ROADS
let crossy, lanes, crossyMoveCooldown;
const CROSSY_ROW_H = 62;
const CROSSY_BOTTOM_Y = 526;
const CROSSY_LANE_COUNT = 7;
const CROSSY_TOP_ROW = CROSSY_LANE_COUNT + 1;

function crossyYForRow(row) {
    return CROSSY_BOTTOM_Y - (row * CROSSY_ROW_H);
}

function startCrossy(){
    score = 0;
    updateHud();

    lanes = [];
    for (let row = 1; row <= CROSSY_LANE_COUNT; row++) {
        const direction = row % 2 === 0 ? 1 : -1;
        const speed = direction * (1.65 + row * 0.22);
        const lane = { row, y: crossyYForRow(row), speed, cars: [] };

        for (let c = 0; c < 3; c++) {
            lane.cars.push({
                x: ((c * 185) + (row * 71)) % (canvas.width + 160) - 110,
                w: 58 + Math.random() * 34,
                h: 34
            });
        }

        lanes.push(lane);
    }

    crossy = {
        x: Math.floor(canvas.width / 2),
        row: 0,
        y: crossyYForRow(0),
        size: 28
    };

    crossyMoveCooldown = 0;
    animationId = requestAnimationFrame(crossyLoop);
}

function crossyPlayerRect() {
    return {
        x: crossy.x - crossy.size / 2,
        y: crossy.y - crossy.size / 2,
        w: crossy.size,
        h: crossy.size
    };
}

function rectsOverlap(a, b) {
    return a.x < b.x + b.w &&
           a.x + a.w > b.x &&
           a.y < b.y + b.h &&
           a.y + a.h > b.y;
}

function checkCrossyCollision() {
    if (!crossy) return false;
    const player = crossyPlayerRect();

    for (const lane of lanes) {
        // Only cars on the player's current row can hit them.
        if (lane.row !== crossy.row) continue;

        for (const car of lane.cars) {
            const carRect = {
                x: car.x,
                y: lane.y - car.h / 2,
                w: car.w,
                h: car.h
            };

            if (rectsOverlap(player, carRect)) {
                finish(false, 'hit_car');
                return true;
            }
        }
    }

    return false;
}

function crossyLoop(){
    if(!running || currentGame !== 'crossy') return;

    crossyMoveCooldown = Math.max(0, crossyMoveCooldown - 16);

    for (const lane of lanes) {
        for (const car of lane.cars) {
            car.x += lane.speed;

            if (lane.speed > 0 && car.x > canvas.width + 90) car.x = -car.w - 90;
            if (lane.speed < 0 && car.x + car.w < -90) car.x = canvas.width + 90;
        }
    }

    if (checkCrossyCollision()) return;

    drawCrossy();
    animationId = requestAnimationFrame(crossyLoop);
}

function drawCrossy(){
    ctx.clearRect(0,0,canvas.width,canvas.height);
    ctx.fillStyle = '#0b1320';
    ctx.fillRect(0,0,canvas.width,canvas.height);

    // Draw bottom safe row, traffic lanes, and top reset row.
    for (let row = 0; row <= CROSSY_TOP_ROW; row++) {
        const y = crossyYForRow(row);
        const isSafe = row === 0 || row === CROSSY_TOP_ROW;
        ctx.fillStyle = isSafe ? '#0b1b18' : (row % 2 ? '#182235' : '#101a2c');
        ctx.fillRect(0, y - CROSSY_ROW_H / 2, canvas.width, CROSSY_ROW_H - 2);
        ctx.strokeStyle = isSafe ? 'rgba(101,255,79,.22)' : 'rgba(101,255,79,.10)';
        ctx.beginPath();
        ctx.moveTo(0, y + CROSSY_ROW_H / 2 - 1);
        ctx.lineTo(canvas.width, y + CROSSY_ROW_H / 2 - 1);
        ctx.stroke();
    }

    for (const lane of lanes) {
        ctx.fillStyle = '#38bdf8';
        for (const car of lane.cars) {
            ctx.fillRect(car.x, lane.y - car.h / 2, car.w, car.h);
        }
    }

    ctx.fillStyle = '#65ff4f';
    ctx.fillRect(crossy.x - crossy.size / 2, crossy.y - crossy.size / 2, crossy.size, crossy.size);
    ctx.fillStyle = '#000';
    ctx.fillRect(crossy.x - 7, crossy.y - 5, 4, 4);
    ctx.fillRect(crossy.x + 4, crossy.y - 5, 4, 4);
}

document.addEventListener('keydown',(e)=>{
    if(!running || currentGame !== 'crossy' || !crossy || crossyMoveCooldown > 0) return;

    let moved = false;

    if(e.key === 'ArrowUp'){
        crossy.row++;
        moved = true;
        score++;
    }

    if(e.key === 'ArrowDown' && crossy.row > 0){
        crossy.row--;
        moved = true;
    }

    if(e.key === 'ArrowLeft'){
        crossy.x -= 46;
        moved = true;
    }

    if(e.key === 'ArrowRight'){
        crossy.x += 46;
        moved = true;
    }

    if(!moved) return;

    crossy.x = Math.max(18, Math.min(canvas.width - 18, crossy.x));

    // Reaching the top safe row counts, then loops back to the start row.
    if (crossy.row >= CROSSY_TOP_ROW) {
        crossy.row = 0;
        crossy.x = Math.floor(canvas.width / 2);
    }

    crossy.y = crossyYForRow(crossy.row);
    crossyMoveCooldown = 90;

    updateHud();

    if(score >= targetScore) {
        finish(true, 'target_score');
        return;
    }

    // Check instantly after moving, so walking into a car fails right away.
    checkCrossyCollision();
});

// MEMORY MATCH
let cards, firstCard, secondCard, lockMemory;
function startMemory(){ const tiles = Math.max(8, Number(targetScore || 8)); const pairs = Math.floor(tiles/2); const vals=[]; for(let i=1;i<=pairs;i++){ vals.push(i,i); } vals.sort(()=>Math.random()-.5); cards=vals.map((v,i)=>({v,i,open:false,matched:false})); firstCard=null; secondCard=null; lockMemory=false; score=0; targetScore=tiles; updateHud(); drawMemory(); }
canvas.addEventListener('click',(e)=>{ if(!running||currentGame!=='memory'||lockMemory) return; const r=canvas.getBoundingClientRect(); const x=(e.clientX-r.left)*(canvas.width/r.width); const y=(e.clientY-r.top)*(canvas.height/r.height); const idx=memoryHit(x,y); if(idx<0) return; const card=cards[idx]; if(card.open||card.matched) return; card.open=true; if(!firstCard) firstCard=card; else { secondCard=card; lockMemory=true; if(firstCard.v===secondCard.v){ firstCard.matched=secondCard.matched=true; score+=2; updateHud(); firstCard=secondCard=null; lockMemory=false; if(score>=targetScore) finish(true,'target_score'); } else { setTimeout(()=>{ firstCard.open=false; secondCard.open=false; firstCard=secondCard=null; lockMemory=false; drawMemory(); },650); } } drawMemory(); });
function memoryLayout(){ const cols = cards.length > 16 ? 6 : 4; const gap = cards.length > 16 ? 10 : 16; const size = cards.length > 16 ? 58 : cards.length > 8 ? 76 : 90; const startX=(canvas.width-(cols*size+(cols-1)*gap))/2, startY=cards.length > 16 ? 70 : 90; return {cols,gap,size,startX,startY}; }
function memoryHit(x,y){ const l=memoryLayout(); for(let i=0;i<cards.length;i++){ const cx=l.startX+(i%l.cols)*(l.size+l.gap), cy=l.startY+Math.floor(i/l.cols)*(l.size+l.gap); if(x>=cx&&x<=cx+l.size&&y>=cy&&y<=cy+l.size) return i; } return -1; }
function drawMemory(){ ctx.clearRect(0,0,canvas.width,canvas.height); ctx.fillStyle='#07101e'; ctx.fillRect(0,0,canvas.width,canvas.height); const l=memoryLayout(); ctx.font=`bold ${l.size > 70 ? 30 : 22}px Courier New`; ctx.textAlign='center'; ctx.textBaseline='middle'; cards.forEach((card,i)=>{ const x=l.startX+(i%l.cols)*(l.size+l.gap), y=l.startY+Math.floor(i/l.cols)*(l.size+l.gap); ctx.fillStyle=card.matched?'rgba(101,255,79,.18)':card.open?'rgba(56,189,248,.20)':'rgba(101,255,79,.07)'; ctx.fillRect(x,y,l.size,l.size); ctx.strokeStyle=card.matched?'#65ff4f':'rgba(101,255,79,.55)'; ctx.strokeRect(x,y,l.size,l.size); ctx.fillStyle=card.open||card.matched?'#65ff4f':'#b7ffc0'; ctx.fillText(card.open||card.matched?String(card.v):'?',x+l.size/2,y+l.size/2); }); }

// RANDOM CODE TYPING HACK
let typingTarget = '';
let typingIndex = 0;
let typingResults = [];
let typoCount = 0;
let maxTypos = 3;
const SYMBOLS = '{}[]()<>+-=*/%&|!?:;.,_$#@~^\\\'"';
const WORDS = ['charCode','inputString','packet','cipher','buffer','token','payload','hash','nonce','byte','index','vector','auth','seed','hex','access','trace','node','relay','signal'];
function randomInt(min,max){ return Math.floor(Math.random()*(max-min+1))+min; }
function pick(arr){ return arr[Math.floor(Math.random()*arr.length)]; }
function randomChunk(len){ const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789' + SYMBOLS; let s=''; for(let i=0;i<len;i++) s += chars[Math.floor(Math.random()*chars.length)]; return s; }
function randomCodeLine(minLen,maxLen){
    const templates = [
        () => `Dim ${pick(WORDS)}_${randomInt(10,99)} = ${randomChunk(randomInt(4,8))}`,
        () => `${pick(WORDS)} = Asc(Mid(${pick(WORDS)}, ${randomInt(1,9)}, ${randomInt(1,4)}))`,
        () => `if (${pick(WORDS)}_${randomInt(1,9)} >= 0x${randomChunk(2)}) { ${pick(WORDS)} += ${randomInt(7,999)}; }`,
        () => `for (i=${randomInt(0,3)}; i<${randomInt(12,64)}; i++) ${pick(WORDS)}[i] ^= 0x${randomChunk(2)}`,
        () => `${pick(WORDS)}::${pick(WORDS)}(${randomChunk(randomInt(6,12))});`,
        () => `return ${pick(WORDS)}.${pick(['decode','encode','splice','verify','inject'])}("${randomChunk(randomInt(6,10))}")`,
        () => `0x${randomChunk(randomInt(6,10))} ${pick(['&&','||','==','!=','>=','<='])} ${pick(WORDS)}_${randomInt(100,999)}`,
        () => randomChunk(randomInt(minLen,maxLen))
    ];
    let line = pick(templates)();
    while (line.length < minLen) line += pick(['_', '.', ':', '-', '+']) + randomChunk(randomInt(2,5));
    if (line.length > maxLen + 12) line = line.slice(0, maxLen + 12);
    return line;
}
function generateTypingText(){
    const cfg = options.typing || {};
    const lines = Number(cfg.lines || 4);
    const minLen = Number(cfg.minLen || 16);
    const maxLen = Number(cfg.maxLen || 26);
    const out = [];
    for(let i=0;i<lines;i++) out.push(randomCodeLine(minLen,maxLen));
    return out.join('\n');
}
function startTyping(){
    typingTarget = generateTypingText();
    typingIndex = 0; typingResults = []; typoCount = 0;
    maxTypos = Number((options.typing && options.typing.maxErrors) || options.maxErrors || 3);
    score = 0; targetScore = typingTarget.length; updateHud();
    updateTypingErrors(); renderTyping();
}
function updateTypingErrors(){ typingErrors.textContent = `[ ERRORS: ${typoCount}/${maxTypos} ]`; }
function renderTyping(){
    typingText.innerHTML = '';
    for(let i=0;i<typingTarget.length;i++){
        const span = document.createElement('span');
        span.className = 'char';
        span.textContent = typingTarget[i];
        if (typingTarget[i] === '\n') span.textContent = '\n';
        if (typingResults[i]) span.classList.add(typingResults[i].correct ? 'correct' : 'incorrect');
        else if (i === typingIndex) span.classList.add('current');
        typingText.appendChild(span);
    }
}
function typingHit(){
    typingGame.classList.remove('hit'); void typingGame.offsetWidth; typingGame.classList.add('hit'); glitchSfx();
}
document.addEventListener('keydown', (e) => {
    if(!running || currentGame !== 'typing') return;
    if(e.key === 'Escape') return;
    if(e.key === 'Backspace' || e.key === 'Delete') { e.preventDefault(); return; }
    let typed = e.key;
    if (typed === 'Enter') typed = '\n';
    if (typed === 'Tab') { typed = '\t'; e.preventDefault(); }
    if (typed.length !== 1) return;
    e.preventDefault();
    const expected = typingTarget[typingIndex];
    const correct = typed === expected;
    typingResults[typingIndex] = { correct };
    if (correct) { score += 1; keySfx(); }
    else { typoCount += 1; typingHit(); }
    typingIndex += 1;
    updateTypingErrors(); updateHud(); renderTyping();
    if (typoCount >= maxTypos) { finish(false, 'typing_errors'); return; }
    if (typingIndex >= typingTarget.length) finish(true, 'typing_complete');
});

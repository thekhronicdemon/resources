const app = document.getElementById('app')
let state = { players: [], admins: [], activity: [], jobButtons: [], devAccess: false }
let selectedCitizenId = null
let selectedPlayerId = null

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).then(r => r.json())
const esc = s => String(s ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))

window.addEventListener('message', e => {
  if (e.data.action === 'open') { state = e.data.data; app.classList.remove('hidden'); render(); loadAudit(); loadLogs('') }
  if (e.data.action === 'close') app.classList.add('hidden')
})

document.querySelectorAll('aside button[data-tab]').forEach(btn => btn.onclick = () => switchTab(btn.dataset.tab))
function switchTab(tab) {
  document.querySelectorAll('aside button').forEach(b => b.classList.remove('active'))
  document.querySelector(`aside button[data-tab="${tab}"]`)?.classList.add('active')
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'))
  document.getElementById(tab).classList.add('active')
}

document.getElementById('closeBtn').onclick = () => { app.classList.add('hidden'); post('close') }
document.getElementById('refreshBtn').onclick = refreshDashboard
document.addEventListener('keydown', e => { if (e.key === 'Escape') document.getElementById('closeBtn').click() })

function playerRow(p) {
  return `<div class="row clickable" onclick="openProfile('${esc(p.citizenid)}','${esc(p.id)}')"><div><strong>${esc(p.name)}</strong> <span class="muted">[${esc(p.id)}]</span><div class="muted">${esc(p.citizenid || 'unknown')} | ${esc(p.jobLabel || p.job)} ${esc(p.grade || '')} | ping ${esc(p.ping || 0)}</div></div><div class="actions"><button>Profile</button></div></div>`
}
function adminRow(a) { return `<div class="row"><div><strong>${esc(a.name)}</strong><div class="muted">ID ${esc(a.id)} | ${esc(a.citizenid)}</div></div><span class="muted">${esc(a.ping)}ms</span></div>` }

function render() {
  document.getElementById('playerCount').textContent = state.players.length
  document.getElementById('adminCount').textContent = state.admins.length
  document.getElementById('hourPeak').textContent = Math.max(...(state.activity || []).map(a => Number(a.count || 0)), 0)
  document.getElementById('playersList').innerHTML = state.players.map(playerRow).join('') || '<p class="muted">No players online.</p>'
  document.getElementById('adminsList').innerHTML = state.admins.map(adminRow).join('') || '<p class="muted">No admins online.</p>'
  document.getElementById('jobButtons').innerHTML = state.jobButtons.map(j => `<button onclick="filterJob('${esc(j.job)}')">${esc(j.label)}</button>`).join('')
  document.getElementById('devLocked').classList.toggle('hidden', state.devAccess)
  document.getElementById('devTools').classList.toggle('hidden', !state.devAccess)
  drawActivity()
}

async function refreshDashboard() { const fresh = await post('refresh'); if (fresh) { state = fresh; render() } }
function filterJob(job) { document.getElementById('playersList').innerHTML = state.players.filter(p => p.job === job).map(playerRow).join('') || '<p class="muted">Nobody online for this job.</p>' }
document.getElementById('allOnlineBtn').onclick = () => document.getElementById('playersList').innerHTML = state.players.map(playerRow).join('')
document.getElementById('allPlayersBtn').onclick = () => { switchTab('search'); document.getElementById('searchInput').focus() }
window.filterJob = filterJob

function resultRow(p) {
  const warnCount = Number(p.warn_count || 0)
  return `<div class="row clickable" onclick="openProfile('${esc(p.citizenid)}','${esc(p.id)}')">
    <div><strong>${esc(p.name)}</strong> <span class="pill">${p.online ? 'ONLINE ID ' + esc(p.id) : 'OFFLINE'}</span><span class="pill">Warnings ${warnCount}</span><div class="muted">${esc(p.citizenid)} | ${esc(p.jobLabel || p.job)} | Notes ${(p.notes || []).length}</div></div>
    <div class="actions"><button>Open Profile</button>${p.online ? `<button class="warn" onclick="event.stopPropagation();kick('${esc(p.id)}')">Kick</button><button class="danger" onclick="event.stopPropagation();ban('${esc(p.id)}')">Ban</button>` : ''}</div>
  </div>`
}
document.getElementById('searchBtn').onclick = doSearch
async function doSearch() {
  const query = document.getElementById('searchInput').value
  const results = await post('searchPlayer', { query })
  document.getElementById('searchResults').innerHTML = (results || []).map(resultRow).join('') || '<p class="muted">No players found.</p>'
}
window.kick = id => { const reason = prompt('Kick reason?') || 'Kicked by admin.'; post('kickPlayer', { id, reason }) }
window.ban = id => { const reason = prompt('Ban reason?') || 'Banned by admin.'; const hours = Number(prompt('Ban hours? Use 0 for permanent.', '24') || 24); post('banPlayer', { id, reason, hours }).then(() => { loadAudit(); if (selectedCitizenId) openProfile(selectedCitizenId, selectedPlayerId) }) }
window.openProfile = async (citizenid, id) => {
  selectedCitizenId = citizenid
  selectedPlayerId = id || selectedPlayerId
  switchTab('search')
  const p = await post('getProfile', { citizenid, id })
  renderProfile(p)
}

function renderProfile(p) {
  const notes = (p.notes || []).map(n => `<div class="noteCard"><div class="noteBody">${n.note_html || esc(n.note || '')}</div><div class="noteFooter"><span>Added by ${esc(n.admin_name || 'Unknown Admin')}</span><span>${esc(n.created_at || '')}</span></div></div>`).join('') || '<p class="muted">No notes for this player.</p>'
  const bans = (p.bans || []).map(b => `<div class="row"><div><strong>${esc(b.reason || 'No reason')}</strong><div class="muted">By ${esc(b.bannedby || b.admin_name || 'Unknown')} | expires ${esc(b.expire_label || b.expire || 'unknown')}</div></div></div>`).join('') || '<p class="muted">No ban history found.</p>'
  const logs = (p.logs || []).map(l => `<div class="row"><div><strong>${esc(l.event_type)}</strong><div class="muted">${esc(l.created_at)} — ${esc(l.details || '')}</div></div></div>`).join('') || '<p class="muted">No logs found.</p>'
  const flags = (p.flags || []).map(f => `<div class="row"><div><strong>${esc(f.flag_type)}</strong><div class="muted">${esc(f.reason)} — ${esc(f.created_at)} by ${esc(f.admin_name)}</div></div></div>`).join('') || '<p class="muted">No flags yet.</p>'
  const inv = (p.inventory || []).map(i => {
    const name = esc(i.name || 'item')
    const label = esc(i.label || i.name || 'Item')
    const amount = esc(i.amount || i.count || 1)
    const slot = esc(i.slot || '-')
    const image = esc(i.image || `${i.name || 'item'}.png`)
    return `<div class="invItem"><div class="invImageWrap"><img src="nui://qb-inventory/html/images/${image}" onerror="this.style.display='none'; this.parentElement.classList.add('noImg')" /></div><div class="invLabel">${label}</div><div class="muted">${name}</div><div class="invMeta"><span>x${amount}</span><span>Slot ${slot}</span></div><button class="danger smallBtn" onclick="removeItem('${esc(p.citizenid)}','${name}','${slot}')">Remove</button></div>`
  }).join('') || '<p class="muted">No inventory data available.</p>'
  const money = p.money || {}
  document.getElementById('profilePanel').classList.remove('hidden')
  document.getElementById('profilePanel').innerHTML = `
    <div class="topline"><div><h2>${esc(p.name || 'Player Profile')}</h2><p class="muted">${esc(p.citizenid)} ${p.online ? '• ONLINE ID ' + esc(p.id) : '• OFFLINE'}</p></div><div class="actions">${p.online ? `<button class="warn" onclick="kick('${esc(p.id)}')">Kick</button><button class="danger" onclick="ban('${esc(p.id)}')">Ban</button>` : ''}</div></div>
    <div class="profileGrid">
      <div class="panel"><h2>Character</h2><span class="pill">${esc(p.jobLabel || p.job || 'Unknown Job')}</span><span class="pill">${esc(p.gangLabel || p.gang || 'No Gang')}</span><span class="pill">Warnings ${esc(p.warn_count || 0)}</span><div class="moneyGrid"><div class="miniCard"><span class="muted">Cash</span><strong>$${esc(money.cash || 0)}</strong></div><div class="miniCard"><span class="muted">Bank</span><strong>$${esc(money.bank || 0)}</strong></div><div class="miniCard"><span class="muted">Crypto</span><strong>${esc(money.crypto || 0)}</strong></div></div><div class="moneyEditor"><h3>Edit Money</h3><label>Cash</label><div class="inlineEdit"><input id="moneyCash" type="number" min="0" value="${esc(money.cash || 0)}" /><button onclick="setMoney('${esc(p.citizenid)}','cash')">Save Cash</button></div><label>Bank</label><div class="inlineEdit"><input id="moneyBank" type="number" min="0" value="${esc(money.bank || 0)}" /><button onclick="setMoney('${esc(p.citizenid)}','bank')">Save Bank</button></div><label>Crypto</label><div class="inlineEdit"><input id="moneyCrypto" type="number" min="0" value="${esc(money.crypto || 0)}" /><button onclick="setMoney('${esc(p.citizenid)}','crypto')">Save Crypto</button></div><p class="hint">This sets the exact balance, not add/remove.</p></div></div>
      <div class="panel"><h2>Flag / Warning</h2><div class="flagBox"><select id="flagType"><option value="warning">Warning</option><option value="watchlist">Watchlist</option><option value="cheating">Cheating Suspected</option><option value="toxicity">Toxicity</option></select><input id="flagReason" placeholder="Reason" /><button class="warn" onclick="addFlag('${esc(p.citizenid)}')">Add Flag</button></div><p class="hint">Auto-punish: at ${esc(p.autoPunishWarnings || 3)} warnings, the player gets automatically kicked. You can change this in config.lua.</p><div class="list">${flags}</div></div>
      <div class="full noteComposer"><h2>Create Admin Note</h2><div class="noteToolbar"><button onclick="fmt('bold')"><b>B</b></button><button onclick="fmt('underline')"><u>U</u></button><button onclick="fmt('italic')"><i>I</i></button><button onclick="fmt('insertUnorderedList')">• List</button><button onclick="fmt('insertOrderedList')">1. List</button><button onclick="fmt('removeFormat')">Clear</button></div><div id="noteEditor" class="editor" contenteditable="true" data-placeholder="Write clean admin notes here..."></div><div class="toolbar"><button class="success" onclick="saveNote('${esc(p.citizenid)}')">Save Note</button></div></div>
      <div class="panel full"><div class="topline"><h2>Admin Notes</h2><span id="noteStatus" class="muted"></span></div><div id="adminNotesList" class="list">${notes}</div></div>
      <div class="panel"><h2>Ban History</h2><div class="list">${bans}</div></div>
      <div class="panel"><h2>Player Logs</h2><div class="list">${logs}</div></div>
      <div class="panel full"><div class="topline"><h2>Inventory</h2><span class="pill">Images load from qb-inventory/html/images</span></div><div class="inventoryTools"><input id="addItemName" placeholder="item name e.g. water_bottle" /><input id="addItemAmount" type="number" min="1" value="1" /><button class="success" onclick="addItem('${esc(p.citizenid)}')">Add Item</button><input id="removeItemName" placeholder="remove item name" /><input id="removeItemAmount" type="number" min="1" value="1" /><button class="danger" onclick="removeItem('${esc(p.citizenid)}')">Remove Item</button></div><div class="inventoryGrid">${inv}</div></div>
    </div>`
}
window.fmt = command => { document.execCommand(command, false, null); document.getElementById('noteEditor')?.focus() }
function noteCard(n) {
  return `<div class="noteCard"><div class="noteBody">${n.note_html || esc(n.note_text || n.note || '')}</div><div class="noteFooter"><span>Added by ${esc(n.admin_name || 'Unknown Admin')}</span><span>${esc(n.created_at || 'Just now')}</span></div></div>`
}
window.saveNote = async citizenid => {
  const el = document.getElementById('noteEditor')
  const status = document.getElementById('noteStatus')
  const html = (el?.innerHTML || '').trim()
  const plain = (el?.innerText || '').trim()
  if (!plain) { if (status) status.textContent = 'Write a note first.'; return }
  if (status) status.textContent = 'Saving note...'
  const result = await post('addNote', { citizenid, note_html: html, note_text: plain })
  if (!result || !result.ok) {
    if (status) status.textContent = 'Note failed to save: ' + (result?.error || 'unknown error')
    console.error('prp-adminpanel note save failed', result)
    return
  }
  if (el) el.innerHTML = ''
  const list = document.getElementById('adminNotesList')
  if (list) {
    const empty = list.querySelector('p.muted')
    if (empty) empty.remove()
    list.insertAdjacentHTML('afterbegin', noteCard(result.note || { note_html: html, note_text: plain, admin_name: result.admin_name, created_at: 'Just now' }))
  }
  if (status) status.textContent = 'Note saved.'
}
window.addFlag = async citizenid => {
  const flagType = document.getElementById('flagType').value
  const reason = document.getElementById('flagReason').value || 'No reason supplied.'
  await post('addFlag', { citizenid, flagType, reason })
  await openProfile(citizenid, selectedPlayerId)
}

window.setMoney = async (citizenid, moneyType) => {
  const ids = { cash: 'moneyCash', bank: 'moneyBank', crypto: 'moneyCrypto' }
  const input = document.getElementById(ids[moneyType])
  const amount = Number(input?.value ?? 0)
  if (!Number.isFinite(amount) || amount < 0) return
  await post('setMoney', { citizenid, moneyType, amount: Math.floor(amount) })
  await openProfile(citizenid, selectedPlayerId)
  await loadAudit()
}

window.addItem = async citizenid => {
  const itemName = (document.getElementById('addItemName')?.value || '').trim()
  const amount = Number(document.getElementById('addItemAmount')?.value || 1)
  if (!itemName || !Number.isFinite(amount) || amount <= 0) return
  const result = await post('addItem', { citizenid, itemName, amount: Math.floor(amount) })
  if (!result || !result.ok) return console.log('Add item failed', result)
  await openProfile(citizenid, selectedPlayerId)
  await loadAudit()
}

window.removeItem = async (citizenid, prefillName = '', prefillSlot = '') => {
  const itemName = (prefillName || document.getElementById('removeItemName')?.value || '').trim()
  const amount = Number(document.getElementById('removeItemAmount')?.value || 1)
  const slot = Number(prefillSlot || 0)
  if (!itemName || !Number.isFinite(amount) || amount <= 0) return
  const result = await post('removeItem', { citizenid, itemName, amount: Math.floor(amount), slot: slot || undefined })
  if (!result || !result.ok) return console.log('Remove item failed', result)
  await openProfile(citizenid, selectedPlayerId)
  await loadAudit()
}

window.loadLogs = async (type = '') => {
  const logs = await post('getLogs', { type })
  document.getElementById('logsList').innerHTML = (logs || []).map(l => `<div class="row"><div><strong>${esc(l.event_type)}</strong> <span class="pill">${esc(l.name || l.citizenid || 'unknown')}</span><div class="muted">${esc(l.created_at)} — ${esc(l.details || '')}</div></div></div>`).join('') || '<p class="muted">No logs found.</p>'
}
window.loadAudit = async () => {
  const logs = await post('getAudit', {})
  document.getElementById('auditList').innerHTML = (logs || []).map(l => `<div class="row"><div><strong>${esc(l.action)}</strong> <span class="pill">${esc(l.admin_name)}</span><div class="muted">Target: ${esc(l.target_citizenid || l.target_id || '-')} | ${esc(l.created_at)}</div><div>${esc(l.details || '')}</div></div></div>`).join('') || '<p class="muted">No audit logs found.</p>'
}

document.querySelectorAll('[data-dev]').forEach(btn => btn.onclick = () => {
  const action = btn.dataset.dev
  const payload = { action }
  if (action === 'spawnObject') { payload.model = document.getElementById('objectModel').value; payload.freeze = document.getElementById('objectFreeze').checked }
  if (action === 'spawnVehicle') { payload.model = document.getElementById('vehicleModel').value; payload.limit = document.getElementById('vehicleLimit').checked }
  if (action === 'spawnPed') { payload.model = document.getElementById('pedModel').value; payload.anim = document.getElementById('pedAnim').value; payload.freeze = document.getElementById('pedFreeze').checked }
  post('devAction', payload)
})

function waveHeight(count, canvasHeight) { const usable = canvasHeight - 56; if (count <= 0) return 0; if (count <= 1) return usable*.08; if (count <= 20) return usable*(.08+(count-1)/19*.34); if (count <= 60) return usable*(.42+(count-20)/40*.32); if (count <= 100) return usable*(.74+(count-60)/40*.24); return usable }
function drawActivity() {
  const c = document.getElementById('activityCanvas'), ctx = c.getContext('2d'), data = state.activity || [], baseY = c.height - 36
  ctx.clearRect(0,0,c.width,c.height); ctx.fillStyle='rgba(255,255,255,.06)'; ctx.fillRect(0,0,c.width,c.height); ctx.font='12px Arial'
  ;[1,20,40,60,100].forEach(g=>{const y=baseY-waveHeight(g,c.height);ctx.strokeStyle='rgba(255,255,255,.10)';ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(c.width,y);ctx.stroke();ctx.fillStyle='rgba(255,255,255,.50)';ctx.fillText(`${g}`,8,y-4)})
  if(!data.length)return; const step=c.width/Math.max(1,data.length-1); const points=data.map((a,i)=>({x:i*step,y:baseY-waveHeight(Number(a.count||0),c.height),count:Number(a.count||0),hour:a.hour}))
  ctx.beginPath(); ctx.moveTo(points[0].x,baseY); points.forEach((p,i)=>{ if(i===0)ctx.lineTo(p.x,p.y); else {const prev=points[i-1], mid=(prev.x+p.x)/2; ctx.quadraticCurveTo(prev.x,prev.y,mid,(prev.y+p.y)/2); ctx.quadraticCurveTo(p.x,p.y,p.x,p.y)}}); ctx.lineTo(points.at(-1).x,baseY); ctx.closePath(); const grad=ctx.createLinearGradient(0,0,0,c.height); grad.addColorStop(0,'rgba(120,170,255,.68)'); grad.addColorStop(1,'rgba(120,170,255,.06)'); ctx.fillStyle=grad; ctx.fill()
  ctx.beginPath(); points.forEach((p,i)=>{ if(i===0)ctx.moveTo(p.x,p.y); else {const prev=points[i-1], mid=(prev.x+p.x)/2; ctx.quadraticCurveTo(prev.x,prev.y,mid,(prev.y+p.y)/2); ctx.quadraticCurveTo(p.x,p.y,p.x,p.y)}}); ctx.strokeStyle='rgba(238,247,255,.95)'; ctx.lineWidth=3; ctx.stroke(); ctx.fillStyle='rgba(255,255,255,.72)'; points.forEach((p,i)=>{if(i%2===0)ctx.fillText(String(p.hour).padStart(2,'0'),p.x+4,c.height-10); if(p.count>0)ctx.fillText(String(p.count),Math.min(c.width-24,p.x+4),p.y-8)})
}
setInterval(async()=>{ if(app.classList.contains('hidden'))return; await refreshDashboard(); if(document.getElementById('logs').classList.contains('active')) loadLogs(''); if(document.getElementById('audit').classList.contains('active')) loadAudit() }, 10000)

const app = document.getElementById('app')
let state = { players: [], admins: [], activity: [], jobButtons: [], devAccess: false }
let selectedCitizenId = null
let selectedServerId = null
const devToggleState = { objectFreeze: true, vehicleLimit: true, pedFreeze: true }

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).then(r => r.json())
const esc = s => String(s ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))
function relativeTime(value) { if (!value) return ''; const d = new Date(String(value).replace(' ', 'T')); const then = isNaN(d.getTime()) ? Number(value) : d.getTime(); if (!then) return esc(value); let sec = Math.max(1, Math.floor((Date.now() - then) / 1000)); const units=[['year',31536000],['month',2592000],['day',86400],['hour',3600],['minute',60]]; for (const [n,s] of units){const v=Math.floor(sec/s); if(v>=1)return `${v} ${n}${v===1?'':'s'} ago`}; return `${sec} seconds ago` }
function itemImage(name){ const clean=String(name||'').toLowerCase(); return `nui://qb-inventory/html/images/${clean}.png` }

function uiConfirm(opts = {}) {
  const title = opts.title || 'Confirm Action'
  const message = opts.message || 'Are you sure?'
  const confirmText = opts.confirmText || 'Confirm'
  const cancelText = opts.cancelText || 'Cancel'
  const danger = !!opts.danger
  return new Promise(resolve => {
    const old = document.getElementById('uiConfirmOverlay')
    if (old) old.remove()
    const overlay = document.createElement('div')
    overlay.id = 'uiConfirmOverlay'
    overlay.className = 'uiModalOverlay'
    overlay.innerHTML = `<div class="uiModalBox"><div class="uiModalGlow"></div><h2>${esc(title)}</h2><p>${esc(message)}</p><div class="uiModalActions"><button class="ghost" id="uiCancelBtn">${esc(cancelText)}</button><button class="${danger ? 'danger' : 'success'}" id="uiConfirmBtn">${esc(confirmText)}</button></div></div>`
    document.body.appendChild(overlay)
    const close = answer => { overlay.remove(); resolve(answer) }
    overlay.querySelector('#uiCancelBtn').onclick = () => close(false)
    overlay.querySelector('#uiConfirmBtn').onclick = () => close(true)
    overlay.addEventListener('click', e => { if (e.target === overlay) close(false) })
  })
}



function makeRichToolbar(editorId) {
  return `<div class="noteToolbar richToolbar" data-editor="${editorId}">
    <button type="button" data-cmd="bold" onclick="fmt('bold','${editorId}')"><b>B</b></button>
    <button type="button" data-cmd="underline" onclick="fmt('underline','${editorId}')"><u>U</u></button>
    <button type="button" data-cmd="italic" onclick="fmt('italic','${editorId}')"><i>I</i></button>
    <button type="button" data-cmd="insertUnorderedList" onclick="fmt('insertUnorderedList','${editorId}')">• List</button>
    <button type="button" data-cmd="insertOrderedList" onclick="fmt('insertOrderedList','${editorId}')">1. List</button>
    <button type="button" data-cmd="removeFormat" onclick="fmt('removeFormat','${editorId}')">Clear</button>
  </div>`
}
function updateRichToolbar(editorId) {
  const toolbar = document.querySelector(`.richToolbar[data-editor="${editorId}"]`)
  if (!toolbar) return
  const activeCommands = ['bold', 'underline', 'italic', 'insertUnorderedList', 'insertOrderedList']
  toolbar.querySelectorAll('button[data-cmd]').forEach(btn => {
    const cmd = btn.dataset.cmd
    let active = false
    if (activeCommands.includes(cmd)) {
      try { active = document.queryCommandState(cmd) } catch (e) { active = false }
    }
    btn.classList.toggle('activeFormat', !!active)
  })
}
function bindRichEditor(editorId) {
  const editor = document.getElementById(editorId)
  if (!editor) return
  ;['keyup','mouseup','input','focus'].forEach(evt => editor.addEventListener(evt, () => updateRichToolbar(editorId)))
  setTimeout(() => updateRichToolbar(editorId), 50)
}
document.addEventListener('selectionchange', () => {
  const active = document.activeElement
  if (active && active.classList && active.classList.contains('editor')) updateRichToolbar(active.id)
})
function uiNoteEditor(opts = {}) {
  const title = opts.title || 'Admin Note'
  const html = opts.html || ''
  const saveText = opts.saveText || 'Save Note'
  const editorId = opts.editorId || 'modalNoteEditor'
  return new Promise(resolve => {
    const old = document.getElementById('uiNoteOverlay')
    if (old) old.remove()
    const overlay = document.createElement('div')
    overlay.id = 'uiNoteOverlay'
    overlay.className = 'uiModalOverlay'
    overlay.innerHTML = `<div class="uiModalBox uiNoteModal"><div class="uiModalGlow"></div><h2>${esc(title)}</h2>${makeRichToolbar(editorId)}<div id="${editorId}" class="editor modalEditor" contenteditable="true" data-placeholder="Write clean admin notes here..."></div><div class="uiModalActions"><button class="ghost" id="noteCancelBtn">Cancel</button><button class="success" id="noteSaveBtn">${esc(saveText)}</button></div></div>`
    document.body.appendChild(overlay)
    const editor = overlay.querySelector(`#${editorId}`)
    editor.innerHTML = html
    bindRichEditor(editorId)
    editor.focus()
    const close = result => { overlay.remove(); resolve(result) }
    overlay.querySelector('#noteCancelBtn').onclick = () => close(null)
    overlay.querySelector('#noteSaveBtn').onclick = () => {
      const note_html = editor.innerHTML.trim()
      const note_text = editor.innerText.trim()
      if (!note_text) return
      close({ note_html, note_text })
    }
    overlay.addEventListener('click', e => { if (e.target === overlay) close(null) })
  })
}
window.addEventListener('message', e => { if (e.data.action === 'open') { state = e.data.data; app.classList.remove('hidden'); render(); loadAudit(); loadLogs('') } if (e.data.action === 'close') app.classList.add('hidden') })
document.querySelectorAll('aside button[data-tab]').forEach(btn => btn.onclick = () => switchTab(btn.dataset.tab))
function switchTab(tab){ document.querySelectorAll('aside button').forEach(b=>b.classList.remove('active')); document.querySelector(`aside button[data-tab="${tab}"]`)?.classList.add('active'); document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active')); document.getElementById(tab).classList.add('active') }
document.getElementById('closeBtn').onclick = () => { app.classList.add('hidden'); post('close') }
document.getElementById('refreshBtn').onclick = refreshDashboard
document.addEventListener('keydown', e => { if (e.key === 'Escape') document.getElementById('closeBtn').click() })

function playerRow(p){ return `<div class="row clickable" onclick="openProfile('${esc(p.citizenid)}','${esc(p.id)}')"><div><strong>${esc(p.name)}</strong> <span class="muted">[${esc(p.id)}]</span><div class="muted">${esc(p.citizenid||'unknown')} | ${esc(p.jobLabel||p.job)} ${esc(p.grade||'')} | ping ${esc(p.ping||0)}</div></div><div class="actions"><button>Profile</button></div></div>` }
function adminRow(a){ return `<div class="row"><div><strong>${esc(a.name)}</strong><div class="muted">ID ${esc(a.id)} | ${esc(a.citizenid)}</div></div><span class="muted">${esc(a.ping)}ms</span></div>` }
function render(){ document.getElementById('playerCount').textContent=Number(state.onlineCount ?? state.players.length); document.getElementById('adminCount').textContent=state.admins.length; document.getElementById('hourPeak').textContent=Number(state.currentHourPeak ?? Math.max(...(state.activity||[]).map(a=>Number(a.count||0)),0)); document.getElementById('playersList').innerHTML=state.players.map(playerRow).join('')||'<p class="muted">No players online.</p>'; document.getElementById('adminsList').innerHTML=state.admins.map(adminRow).join('')||'<p class="muted">No admins online.</p>'; document.getElementById('jobButtons').innerHTML=state.jobButtons.map(j=>`<button onclick="filterJob('${esc(j.job)}')">${esc(j.label)}</button>`).join(''); document.getElementById('devLocked').classList.toggle('hidden', state.devAccess); document.getElementById('devTools').classList.toggle('hidden', !state.devAccess); drawActivity() }
async function refreshDashboard(){ const fresh=await post('refresh'); if(fresh){ state=fresh; render() } }
function filterJob(job){ document.getElementById('playersList').innerHTML=state.players.filter(p=>p.job===job).map(playerRow).join('')||'<p class="muted">Nobody online for this job.</p>' }
document.getElementById('allOnlineBtn').onclick=()=>document.getElementById('playersList').innerHTML=state.players.map(playerRow).join('')
document.getElementById('allPlayersBtn').onclick=()=>{ switchTab('search'); document.getElementById('searchInput').focus() }
window.filterJob=filterJob

function resultRow(p){ const warn=Number(p.warn_count||0); return `<div class="row clickable" onclick="openProfile('${esc(p.citizenid)}','${esc(p.id)}')"><div><strong>${esc(p.name)}</strong> <span class="pill">${p.online?'ONLINE ID '+esc(p.id):'OFFLINE'}</span><span class="pill">Warnings ${warn}</span><div class="muted">${esc(p.citizenid)} | ${esc(p.jobLabel||p.job)} | Notes ${(p.notes||[]).length}</div></div><div class="actions"><button>Open Profile</button>${p.online?`<button class="warn" onclick="event.stopPropagation();kick('${esc(p.id)}')">Kick</button><button class="danger" onclick="event.stopPropagation();ban('${esc(p.id)}')">Ban</button>`:''}</div></div>` }
document.getElementById('searchBtn').onclick=doSearch
async function doSearch(){ const results=await post('searchPlayer',{query:document.getElementById('searchInput').value}); document.getElementById('searchResults').innerHTML=(results||[]).map(resultRow).join('')||'<p class="muted">No players found.</p>' }
window.kick=async id=>{ const reason=prompt('Kick reason?','Kicked by admin.'); if(!reason)return; await post('kickPlayer',{id,reason}); loadAudit(); setTimeout(()=>openProfile(selectedCitizenId, selectedServerId),350) }
window.ban=async id=>{ const reason=prompt('Ban reason?','Banned by admin.'); if(!reason)return; const hours=Number(prompt('Ban hours? Use 0 for permanent.','24')||24); await post('banPlayer',{id,reason,hours}); loadAudit(); setTimeout(()=>openProfile(selectedCitizenId, selectedServerId),350) }
window.playerAction=async(action,id)=>{ await post('playerAction',{action,id}); setTimeout(()=>{ loadAudit(); if(selectedCitizenId) openProfile(selectedCitizenId, selectedServerId || id) },350) }
window.openProfile=async(citizenid,id)=>{ selectedCitizenId=citizenid; selectedServerId=(id && id!=='offline')?id:selectedServerId; switchTab('search'); const p=await post('getProfile',{citizenid,id:selectedServerId||id}); renderProfile(p) }

function vehicleStateLabel(state){ const n=Number(state); if(n===0)return'Out'; if(n===1)return'Garage'; if(n===2)return'Impound'; return 'State '+esc(state ?? '-') }
function renderLicenseList(p){ const licenses=Array.isArray(p.licenses)?p.licenses:Object.entries(p.licenses||{}).map(([key,has])=>({key,label:key,has:!!has})); return licenses.map(l=>`<div class="licenseCard ${l.has?'active':'revoked'}"><div><span class="muted">${esc(l.label||l.key)}</span><strong>${l.has?'Active':'Revoked'}</strong></div>${l.has?`<button class="danger" onclick="revokeLicense('${esc(p.citizenid)}','${esc(l.key)}','${esc(l.label||l.key)}')">Revoke</button>`:'<span class="pill dangerPill">No License</span>'}</div>`).join('')||'<p class="muted">No license metadata found.</p>' }
function renderVehicleList(p){ const vehicles=p.vehicles||[]; return vehicles.map(v=>`<div class="vehicleCard"><div><strong>${esc(v.label||v.vehicle||'Vehicle')}</strong><div class="muted">Plate ${esc(v.plate||'-')} | ${esc(v.garage||'unknown')} | ${vehicleStateLabel(v.state)}</div><div class="muted">Fuel ${esc(v.fuel ?? '-')} | Engine ${esc(Math.round(Number(v.engine||0)))} | Body ${esc(Math.round(Number(v.body||0)))}</div></div><div class="actions"><button onclick="spawnOwnedVehicle('${esc(p.citizenid)}','${esc(v.plate)}')">Spawn</button><button class="danger" onclick="deleteOwnedVehicle('${esc(p.citizenid)}','${esc(v.plate)}')">Remove</button></div></div>`).join('')||'<p class="muted">No owned cars found.</p>' }

function renderProfile(p){
  selectedCitizenId=p.citizenid||selectedCitizenId; selectedServerId=p.online?p.id:selectedServerId
  const notes=(p.notes||[]).map(n=>`<div class="noteCard" data-note="${esc(n.id)}"><div class="noteBody" id="noteBody_${esc(n.id)}">${n.note_html||esc(n.note_text||n.note||'')}</div><div class="noteFooter"><span>Added by ${esc(n.admin_name||'Unknown Admin')}</span><span>${relativeTime(n.created_at)}</span></div><div class="actions noteActions"><button onclick="editNote('${esc(n.id)}')">Edit</button><button class="danger" onclick="deleteNote('${esc(n.id)}')">Delete</button></div></div>`).join('')||'<p class="muted">No notes for this player.</p>'
  const bans=(p.bans||[]).map(b=>`<div class="row"><div><strong>${esc(b.reason||'No reason')}</strong><div class="muted">By ${esc(b.bannedby||b.admin_name||'Unknown')} | expires ${esc(b.expire_label||b.expire||'unknown')}</div></div></div>`).join('')||'<p class="muted">No ban history found.</p>'
  const logs=(p.logs||[]).map(l=>`<div class="row"><div><strong>${esc(l.event_type)}</strong><div class="muted">${relativeTime(l.created_at)} — ${esc(l.details||'')}</div></div></div>`).join('')||'<p class="muted">No logs found.</p>'
  const flags=(p.flags||[]).map(f=>`<div class="row"><div><strong>${esc(f.flag_type)}</strong><div class="muted">${esc(f.reason)} — ${relativeTime(f.created_at)} by ${esc(f.admin_name)}</div></div><div class="actions"><button onclick="editFlag('${esc(f.id)}','${esc(f.reason)}')">Edit</button><button class="danger" onclick="deleteFlag('${esc(f.id)}')">Delete</button></div></div>`).join('')||'<p class="muted">No flags yet.</p>'
  const inventoryList = Array.isArray(p.inventory)
    ? p.inventory
    : Object.values(p.inventory || {})
  const cleanInventory = inventoryList.filter(i => i && i.name)
  const inv = cleanInventory.map(i=>{const name=i.name||i.label||'item'; const amount=i.amount||i.count||1; return `<div class="invItem"><img src="${itemImage(name)}" onerror="this.src='images/item-placeholder.png';this.onerror=null"/><strong>${esc(i.label||name)}</strong><div class="muted">${esc(name)}</div><div class="muted">amount: ${esc(amount)}</div><div class="muted">slot: ${esc(i.slot||'-')}</div><button class="danger" onclick="removeItem('${esc(p.citizenid)}','${esc(name)}','${esc(amount)}')">Remove</button></div>`}).join('')||'<p class="muted">No inventory data available.</p>'
  const licenses = renderLicenseList(p)
  const vehicles = renderVehicleList(p)
  const money=p.money||{}
  document.getElementById('profilePanel').classList.remove('hidden')
  document.getElementById('profilePanel').innerHTML=`
    <div class="topline"><div><h2>${esc(p.name||'Player Profile')}</h2><p class="muted">${esc(p.citizenid)} ${p.online?'• ONLINE ID '+esc(p.id):'• OFFLINE'}</p></div><div class="actions">${p.online?`<button onclick="playerAction('spectate','${esc(p.id)}')">Spectate</button><button onclick="playerAction('goto','${esc(p.id)}')">Spawn-To</button><button onclick="playerAction('freeze','${esc(p.id)}')">Freeze</button><button class="danger" onclick="playerAction('kill','${esc(p.id)}')">Kill</button><button class="success" onclick="playerAction('revive','${esc(p.id)}')">Revive</button><button class="warn" onclick="kick('${esc(p.id)}')">Kick</button><button class="danger" onclick="ban('${esc(p.id)}')">Ban</button>`:''}</div></div>
    <div class="profileGrid">
      <div class="panel"><h2>Character</h2><span class="pill">${esc(p.jobLabel||p.job||'Unknown Job')}</span><span class="pill">${esc(p.gangLabel||p.gang||'No Gang')}</span><span class="pill">Warnings ${esc(p.warn_count||0)}</span><div class="moneyGrid"><div class="miniCard"><span class="muted">Cash</span><strong>$${esc(money.cash||0)}</strong><input id="money_cash" type="number" value="${esc(money.cash||0)}"><button onclick="setMoney('${esc(p.citizenid)}','cash')">Save Cash</button></div><div class="miniCard"><span class="muted">Bank</span><strong>$${esc(money.bank||0)}</strong><input id="money_bank" type="number" value="${esc(money.bank||0)}"><button onclick="setMoney('${esc(p.citizenid)}','bank')">Save Bank</button></div><div class="miniCard"><span class="muted">Crypto</span><strong>${esc(money.crypto||0)}</strong><input id="money_crypto" type="number" value="${esc(money.crypto||0)}"><button onclick="setMoney('${esc(p.citizenid)}','crypto')">Save Crypto</button></div></div></div>
      <div class="panel"><h2>Licenses</h2><div class="licenseGrid">${licenses}</div></div>
      <div class="panel"><h2>Flag / Warning</h2><div class="flagBox"><select id="flagType"><option value="warning">Warning</option><option value="watchlist">Watchlist</option><option value="cheating">Cheating Suspected</option><option value="toxicity">Toxicity</option></select><input id="flagReason" placeholder="Reason" /><button class="warn" onclick="addFlag('${esc(p.citizenid)}')">Add Flag</button></div><p class="hint">Auto-punish: at ${esc(p.autoPunishWarnings||3)} warnings, the player gets automatically kicked. You can change this in config.lua.</p><div class="list">${flags}</div></div>
      <div class="panel"><h2>Owned Cars</h2><div class="vehicleList">${vehicles}</div></div>
      <div class="full noteComposer"><h2>Create Admin Note</h2>${makeRichToolbar('noteEditor')}<div id="noteEditor" class="editor" contenteditable="true" data-placeholder="Write clean admin notes here..."></div><div class="toolbar"><button class="success" onclick="saveNote('${esc(p.citizenid)}')">Save Note</button></div></div>
      <div class="panel full"><h2>Admin Notes</h2><div class="list">${notes}</div></div>
      <div class="panel"><h2>Ban History</h2><div class="list">${bans}</div></div><div class="panel"><h2>Player Logs</h2><div class="list">${logs}</div></div>
      <div class="panel full"><h2>Inventory</h2><div class="inventoryControls"><input id="addItemName" placeholder="item name e.g. water_bottle"><input id="addItemAmount" type="number" value="1" min="1"><button class="success" onclick="addItem('${esc(p.citizenid)}')">Add Item</button><button class="danger" onclick="removeItem('${esc(p.citizenid)}')">Remove Item</button></div><p class="hint">Images load from qb-inventory/html/images using item name PNG.</p><div class="inventoryGrid">${inv}</div></div>
    </div>`
  bindRichEditor('noteEditor')
}
window.fmt=(cmd, editorId='noteEditor')=>{
  const editor=document.getElementById(editorId)
  if(editor) editor.focus()
  document.execCommand(cmd,false,null)
  updateRichToolbar(editorId)
}
window.saveNote=async cid=>{
  const el=document.getElementById('noteEditor')
  const html=el.innerHTML.trim()
  const plain=el.innerText.trim()
  if(!plain)return
  await post('addNote',{citizenid:cid,note_html:html,note_text:plain})
  el.innerHTML=''
  updateRichToolbar('noteEditor')
  await openProfile(cid,selectedServerId)
}
window.editNote=async id=>{
  const body=document.getElementById(`noteBody_${id}`)
  const result=await uiNoteEditor({title:'Edit Admin Note', html: body?body.innerHTML:'', saveText:'Save Changes', editorId:`editNoteEditor_${id}`})
  if(!result)return
  await post('editNote',{id,note_html:result.note_html,note_text:result.note_text})
  await openProfile(selectedCitizenId, selectedServerId)
}
window.deleteNote=async id=>{ const ok = await uiConfirm({title:'Delete Admin Note', message:'This will permanently delete this admin note. This cannot be undone.', confirmText:'Delete Note', cancelText:'Keep Note', danger:true}); if(!ok)return; await post('deleteNote',{id}); await openProfile(selectedCitizenId,selectedServerId) }
window.addFlag=async cid=>{await post('addFlag',{citizenid:cid,flagType:document.getElementById('flagType').value,reason:document.getElementById('flagReason').value||'No reason supplied.'}); await openProfile(cid,selectedServerId)}
window.editFlag=async(id,oldReason)=>{const reason=prompt('Edit flag/warning reason:',oldReason); if(reason===null)return; await post('editFlag',{id,reason}); await openProfile(selectedCitizenId,selectedServerId)}
window.deleteFlag=async id=>{ const ok = await uiConfirm({title:'Delete Flag / Warning', message:'This will permanently delete this flag or warning. This cannot be undone.', confirmText:'Delete Warning', cancelText:'Keep Warning', danger:true}); if(!ok)return; await post('deleteFlag',{id}); await openProfile(selectedCitizenId,selectedServerId) }
window.setMoney=async(cid,type)=>{const val=Number(document.getElementById(`money_${type}`).value||0); await post('setMoney',{citizenid:cid,type,amount:val,id:selectedServerId}); await openProfile(cid,selectedServerId)}
window.addItem=async cid=>{await post('addItem',{citizenid:cid,item:document.getElementById('addItemName').value,amount:Number(document.getElementById('addItemAmount').value||1),id:selectedServerId}); await openProfile(cid,selectedServerId)}
window.removeItem=async(cid,item,amount)=>{const name=item||document.getElementById('addItemName').value; const amt=Number(amount||document.getElementById('addItemAmount').value||1); if(!name)return; await post('removeItem',{citizenid:cid,item:name,amount:amt,id:selectedServerId}); await openProfile(cid,selectedServerId)}

window.loadLogs=async(type='')=>{const logs=await post('getLogs',{type});document.getElementById('logsList').innerHTML=(logs||[]).map(l=>`<div class="row"><div><strong>${esc(l.event_type)}</strong> <span class="pill">${esc(l.name||l.citizenid||'unknown')}</span><div class="muted">${relativeTime(l.created_at)} — ${esc(l.details||'')}</div></div></div>`).join('')||'<p class="muted">No logs found.</p>'}
window.loadAudit=async()=>{const logs=await post('getAudit',{});document.getElementById('auditList').innerHTML=(logs||[]).map(l=>`<div class="row"><div><strong>${esc(l.action)}</strong> <span class="pill">${esc(l.admin_name)}</span><div class="muted">Target: ${esc(l.target_citizenid||l.target_id||'-')} | ${relativeTime(l.created_at)}</div><div>${esc(l.details||'')}</div></div></div>`).join('')||'<p class="muted">No audit logs found.</p>'}
document.querySelectorAll('[data-admin-action]').forEach(btn=>btn.onclick=()=>post('adminMassAction',{action:btn.dataset.adminAction}).then(loadAudit))
document.querySelectorAll('[data-toggle]').forEach(btn=>btn.onclick=()=>{const k=btn.dataset.toggle;devToggleState[k]=!devToggleState[k];btn.classList.toggle('on',devToggleState[k])})
document.querySelectorAll('[data-devtoggle]').forEach(btn=>btn.onclick=()=>{btn.classList.toggle('on');post('devAction',{action:btn.dataset.devtoggle})})
document.querySelectorAll('[data-dev]').forEach(btn=>btn.onclick=()=>{const action=btn.dataset.dev;const payload={action};if(action==='spawnObject'){payload.model=document.getElementById('objectModel').value;payload.freeze=devToggleState.objectFreeze} if(action==='spawnVehicle'){payload.model=document.getElementById('vehicleModel').value;payload.limit=devToggleState.vehicleLimit} if(action==='spawnPed'){payload.model=document.getElementById('pedModel').value;payload.anim=document.getElementById('pedAnim').value;payload.freeze=devToggleState.pedFreeze} post('devAction',payload)})

window.revokeLicense=async(cid,license,label)=>{const ok=await uiConfirm({title:'Revoke License',message:`Revoke ${label||license} license from this player?`,confirmText:'Revoke License',cancelText:'Keep License',danger:true});if(!ok)return;await post('revokeLicense',{citizenid:cid,license});loadAudit();setTimeout(()=>openProfile(cid,selectedServerId),350)}
window.spawnOwnedVehicle=async(cid,plate)=>{await post('spawnOwnedVehicle',{citizenid:cid,plate});loadAudit()}
window.deleteOwnedVehicle=async(cid,plate)=>{const ok=await uiConfirm({title:'Remove Owned Car',message:`Remove vehicle ${plate} from this player completely?`,confirmText:'Remove Car',cancelText:'Keep Car',danger:true});if(!ok)return;await post('deleteOwnedVehicle',{citizenid:cid,plate});loadAudit();setTimeout(()=>openProfile(cid,selectedServerId),350)}

function getNiceActivityMax(value){if(value<=10)return 10;if(value<=20)return 20;if(value<=40)return 40;if(value<=60)return 60;if(value<=100)return 100;return Math.ceil(value/50)*50}
function setupActivityCanvas(canvas){const rect=canvas.getBoundingClientRect();const cssWidth=Math.max(900,Math.floor(rect.width||canvas.clientWidth||1200));const cssHeight=Math.max(300,Math.floor(rect.height||canvas.clientHeight||300));let scale=Math.min(4,3840/cssWidth,2160/cssHeight);scale=Math.max(1,scale);const pixelWidth=Math.round(cssWidth*scale);const pixelHeight=Math.round(cssHeight*scale);if(canvas.width!==pixelWidth||canvas.height!==pixelHeight){canvas.width=pixelWidth;canvas.height=pixelHeight}const ctx=canvas.getContext('2d');ctx.setTransform(scale,0,0,scale,0,0);return{ctx,width:cssWidth,height:cssHeight,scale}}
function drawSmoothPath(ctx,pts){if(!pts.length)return;ctx.moveTo(pts[0].x,pts[0].y);for(let i=1;i<pts.length;i++){const prev=pts[i-1],cur=pts[i],mid=(prev.x+cur.x)/2;ctx.bezierCurveTo(mid,prev.y,mid,cur.y,cur.x,cur.y)}}
function roundedRectPath(ctx,x,y,w,h,r){const rr=Math.min(r,w/2,h/2);ctx.moveTo(x+rr,y);ctx.lineTo(x+w-rr,y);ctx.quadraticCurveTo(x+w,y,x+w,y+rr);ctx.lineTo(x+w,y+h-rr);ctx.quadraticCurveTo(x+w,y+h,x+w-rr,y+h);ctx.lineTo(x+rr,y+h);ctx.quadraticCurveTo(x,y+h,x,y+h-rr);ctx.lineTo(x,y+rr);ctx.quadraticCurveTo(x,y,x+rr,y)}
function drawActivity(){const c=document.getElementById('activityCanvas');if(!c)return;const chart=setupActivityCanvas(c),ctx=chart.ctx,w=chart.width,h=chart.height,data=state.activity||[];ctx.clearRect(0,0,w,h);ctx.fillStyle='#111412';ctx.fillRect(0,0,w,h);const pad={top:28,right:28,bottom:42,left:50};const plotW=w-pad.left-pad.right,plotH=h-pad.top-pad.bottom,baseY=h-pad.bottom;const maxCount=Math.max(0,...data.map(a=>Number(a.count||0)));const maxY=getNiceActivityMax(maxCount);ctx.save();ctx.font='700 11px Inter, Segoe UI, Arial';ctx.textBaseline='middle';for(let i=0;i<=4;i++){const value=Math.round(maxY*(i/4));const y=baseY-(value/maxY)*plotH;ctx.strokeStyle=i===0?'rgba(214,179,95,.28)':'rgba(202,211,203,.09)';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(pad.left,y+.5);ctx.lineTo(w-pad.right,y+.5);ctx.stroke();ctx.fillStyle='rgba(215,208,195,.65)';ctx.textAlign='right';ctx.fillText(String(value),pad.left-12,y)}ctx.strokeStyle='rgba(202,211,203,.16)';ctx.beginPath();ctx.moveTo(pad.left,baseY+.5);ctx.lineTo(w-pad.right,baseY+.5);ctx.stroke();ctx.restore();if(!data.length){ctx.fillStyle='rgba(215,208,195,.62)';ctx.font='700 14px Inter, Segoe UI, Arial';ctx.textAlign='center';ctx.fillText('No activity data available',w/2,h/2);return}const step=plotW/Math.max(1,data.length-1);const pts=data.map((a,i)=>{const count=Number(a.count||0);return{x:pad.left+(i*step),y:baseY-(count/maxY)*plotH,count,hour:a.hour}});ctx.save();ctx.beginPath();ctx.moveTo(pts[0].x,baseY);drawSmoothPath(ctx,pts);ctx.lineTo(pts[pts.length-1].x,baseY);ctx.closePath();const area=ctx.createLinearGradient(0,pad.top,0,baseY);area.addColorStop(0,'rgba(86,182,164,.30)');area.addColorStop(1,'rgba(86,182,164,.02)');ctx.fillStyle=area;ctx.fill();ctx.beginPath();drawSmoothPath(ctx,pts);ctx.strokeStyle='#56b6a4';ctx.lineWidth=2.5;ctx.stroke();ctx.restore();const labelEvery=Math.max(1,Math.ceil(data.length/8));ctx.save();ctx.font='700 11px Inter, Segoe UI, Arial';ctx.textAlign='center';ctx.textBaseline='top';pts.forEach((p,i)=>{if(i%labelEvery===0||i===pts.length-1){ctx.fillStyle='rgba(215,208,195,.58)';ctx.fillText(String(p.hour).padStart(2,'0'),p.x,baseY+14);ctx.strokeStyle='rgba(202,211,203,.07)';ctx.beginPath();ctx.moveTo(p.x,pad.top);ctx.lineTo(p.x,baseY);ctx.stroke()}});ctx.restore();ctx.save();pts.forEach(p=>{if(p.count<=0)return;ctx.beginPath();ctx.fillStyle='#101311';ctx.strokeStyle='#56b6a4';ctx.lineWidth=2;ctx.arc(p.x,p.y,3.2,0,Math.PI*2);ctx.fill();ctx.stroke()});const last=pts[pts.length-1];ctx.fillStyle='rgba(214,179,95,.16)';ctx.strokeStyle='rgba(214,179,95,.5)';ctx.lineWidth=1;const badge=`${last.count} online`;ctx.font='800 12px Inter, Segoe UI, Arial';const badgeW=ctx.measureText(badge).width+22;const bx=Math.min(w-pad.right-badgeW,Math.max(pad.left,last.x-badgeW/2));const by=Math.max(pad.top,last.y-34);ctx.beginPath();roundedRectPath(ctx,bx,by,badgeW,24,6);ctx.fill();ctx.stroke();ctx.fillStyle='#ffe4a3';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(badge,bx+badgeW/2,by+12);ctx.restore()}
window.addEventListener('resize',()=>{if(!app.classList.contains('hidden'))drawActivity()})
setInterval(async()=>{if(app.classList.contains('hidden'))return;await refreshDashboard();if(document.getElementById('logs').classList.contains('active'))loadLogs('');if(document.getElementById('audit').classList.contains('active'))loadAudit()},10000)

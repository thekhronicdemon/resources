const res = () => GetParentResourceName();
let state = { charges: [], currentCase: null, currentProfile: null, openTabs: [{type:'home', id:'home', title:'Home'}], activeTab: 'home', confirmCb: null, suggestTimer: null };
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
async function nui(name, data={}){ const r = await fetch(`https://${res()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); return await r.json(); }
function esc(s){ return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function timeAgo(d){ const diff=(Date.now()-new Date(d).getTime())/1000; if(isNaN(diff))return d||''; if(diff<60)return Math.floor(diff)+'s ago'; if(diff<3600)return Math.floor(diff/60)+'m ago'; if(diff<86400)return Math.floor(diff/3600)+'h ago'; if(diff<2592000)return Math.floor(diff/86400)+'d ago'; return Math.floor(diff/2592000)+'mo ago'; }
function normalizeImgUrl(url){ url=String(url||'').trim(); if(!url) return ''; url=url.replace(/^http:\/\//i,'https://'); if(url.includes('imgur.com') && !url.includes('i.imgur.com')){ const m=url.match(/imgur\.com\/(?:gallery\/|a\/)?([A-Za-z0-9]+)/); if(m) url=`https://i.imgur.com/${m[1]}.png`; } return url; }
function testImageLoad(url){ return new Promise((resolve)=>{ url=normalizeImgUrl(url); if(!url) return resolve(false); const img=new Image(); img.referrerPolicy='no-referrer'; img.onload=()=>resolve(true); img.onerror=()=>resolve(false); img.src=url+(url.includes('?')?'&':'?')+'cb='+Date.now(); setTimeout(()=>resolve(false),5000); }); }
function showTab(tab){
  $$('.page').forEach(p=>p.classList.remove('active')); $('#'+tab)?.classList.add('active');
  $$('.nav').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
}
function setActiveTab(id){ const t=state.openTabs.find(x=>x.id===id); if(!t) return; state.activeTab=id; renderTabs(); if(t.type==='home') showTab('home'); if(t.type==='cases') showTab('cases'); if(t.type==='profiles') showTab('profiles'); }
function addWorkTab(type,id,title){ const existing=state.openTabs.find(t=>t.id===id); if(existing){ existing.title=title||existing.title; } else state.openTabs.push({type,id,title:title||id}); setActiveTab(id); }
function closeWorkTab(id){ const i=state.openTabs.findIndex(t=>t.id===id); if(i<=0) return; state.openTabs.splice(i,1); const next=state.openTabs[Math.max(0,i-1)]; setActiveTab(next.id); if(next.type==='cases' && next.case_id) openCase(next.case_id,true); if(next.type==='profiles' && next.citizenid) openProfile(next.citizenid,true); }
function renderTabs(){
  const tabsEl = $('#tabs');
  tabsEl.classList.toggle('compactTabs', state.openTabs.length > 5);
  tabsEl.classList.toggle('tinyTabs', state.openTabs.length > 8);
  tabsEl.innerHTML = state.openTabs.map(t=>`<button class='tab ${state.activeTab===t.id?'active':''}' onclick="setActiveTab('${esc(t.id)}')" title="${esc(t.title)}"><span class='tabTitle'>${esc(t.title)}</span>${t.id!=='home'?` <span class='tabX' onclick="event.stopPropagation();closeWorkTab('${esc(t.id)}')">×</span>`:''}</button>`).join('') + `<button class='tab new' id='newCaseBtn'>New Report</button><button class='tab plus' title='Open new case screen'>+</button>`;
  $('#newCaseBtn').onclick=openCreateCase; $('.tab.plus').onclick=openCreateCase;
}
window.setActiveTab=setActiveTab; window.closeWorkTab=closeWorkTab;
window.addEventListener('message', e=>{ if(e.data.action==='open'){ $('#app').classList.remove('hidden'); renderTabs(); refreshDashboard(); } if(e.data.action==='hydrate'){ state.charges=e.data.data.charges||state.charges; refreshDashboard(); }});
$('#closeBtn').onclick=()=>{ nui('close'); $('#app').classList.add('hidden'); };
$$('.nav').forEach(b=>b.onclick=()=>{ if(b.dataset.tab==='home') setActiveTab('home'); else showTab(b.dataset.tab); });
document.addEventListener('keydown',e=>{ if(e.key==='Escape') $('#closeBtn').click(); });
async function refreshDashboard(){ const r=await nui('getDashboard'); if(!r.ok)return; state.charges=r.charges||[]; renderDuty(r.dutyPolice||[]); renderRecent(r.recentCases||[]); renderAudit(r.audit||[]); renderCharges(); }
setInterval(()=>{ if(!$('#app').classList.contains('hidden')) refreshDashboard(); },15000);
function renderDuty(list){ const html=list.map(o=>`<div class='item'><b>${esc(o.callsign)}</b> ${esc(o.name)} <span class='muted'>StateID ${o.stateid} • ${esc(o.grade)}</span></div>`).join('')||'<p class=muted>No on-duty officers.</p>'; $('#homeDuty').innerHTML=html; $('#dutyList').innerHTML=html; }
function renderRecent(list){ $('#recentCases').innerHTML=list.map(c=>`<div class='item' onclick="openCase('${esc(c.case_id)}')"><b>${esc(c.case_id)}</b> ${esc(c.title)} <span class='pill'>${esc(c.status)}</span><div class='muted'>Updated ${timeAgo(c.updated_at)}</div></div>`).join('')||'<p class=muted>No cases.</p>'; }
function renderAudit(list){ $('#auditLog').innerHTML=list.map(a=>`<div class='item'><b>${esc(a.action)}</b> <span class='muted'>${timeAgo(a.created_at)} by ${esc(a.admin_name)}</span><br>${esc(a.target)} ${esc(a.detail)}</div>`).join('')||'<p class=muted>No audit logs.</p>'; }
async function doGlobalSearch(){ const q=$('#globalSearch').value; const [p,c]=await Promise.all([nui('searchPlayers',{query:q}),nui('searchCases',{query:q})]); $('#globalResults').innerHTML=`${(p.players||[]).map(x=>`<div class='item' onclick="openProfile('${esc(x.citizenid)}')">👤 <b>${esc(x.name)}</b><br><span class='muted'>${esc(x.citizenid)} • ${esc(x.job)}</span></div>`).join('')}${(c.cases||[]).map(x=>`<div class='item' onclick="openCase('${esc(x.case_id)}')">📁 <b>${esc(x.case_id)}</b> ${esc(x.title)}</div>`).join('')}`; }
$('#doGlobalSearch').onclick=doGlobalSearch;
$('#searchPlayers').onclick=async()=>{ const r=await nui('searchPlayers',{query:$('#playerSearch').value}); $('#playerResults').innerHTML=(r.players||[]).map(x=>`<div class='item' onclick="openProfile('${esc(x.citizenid)}')"><b>${esc(x.name)}</b><br><span class='muted'>${esc(x.citizenid)} • ${esc(x.job)}</span></div>`).join('')||'<p class=muted>No players found.</p>'; };
window.openProfile=async(cid,skipTab=false)=>{ if(!skipTab){ addWorkTab('profiles','profile-'+cid,'Profile '+cid); state.openTabs.find(t=>t.id==='profile-'+cid).citizenid=cid; } showTab('profiles'); const r=await nui('getProfile',{citizenid:cid}); if(!r.ok)return; state.currentProfile=r.profile; const p=r.profile; const photo=normalizeImgUrl(p.photo); const lic=Object.entries(p.licenses||{}).map(([k,v])=>`<span class='lic ${!!v}'>${esc(k)}: ${v?'true':'false'}</span>`).join(''); const veh=(p.vehicles||[]).map(v=>`<span class='vehicle'>${esc(v.vehicle)} • ${esc(v.plate)}</span>`).join('')||'<p class=muted>No registered cars.</p>'; $('#profileView').innerHTML=`<div class='profile'><div><img class='mug' referrerpolicy='no-referrer' src='${esc(photo||'images/logo.png')}' onerror="this.onerror=null;this.src='images/logo.png';document.getElementById('photoStatus').innerText='Image failed to load inside FiveM NUI.'"><input id='photoUrl' value='${esc(p.photo||'')}' placeholder='Paste direct image URL / Imgur link'><div class='row'><button onclick='previewPhoto()'>Preview</button><button onclick='savePhoto()'>Save Photo</button></div><p id='photoStatus' class='muted'>Direct Imgur links are supported. Example: https://i.imgur.com/yjsflyF.png</p></div><div><h2>${esc(p.name)}</h2><p class='muted'>${esc(p.citizenid)} • ${esc(p.dob||'')}</p><p>Job: <b>${esc(p.job?.label||p.job?.name||'')}</b></p><h3>Licenses</h3>${lic}<h3>Registered Cars</h3>${veh}<h3>Profile Notes</h3><div>${esc(p.notes||'No profile notes.')}</div><div class='profileCasesBox'><h3>Current Cases</h3><div id='profileCurrentCases'><p class=muted>Loading current cases...</p></div><h3>Past Cases</h3><div id='profilePastCases'><p class=muted>Loading past cases...</p></div></div></div></div>`; loadProfileCases(cid); };
window.previewPhoto=async()=>{ const url=normalizeImgUrl($('#photoUrl').value); $('#photoStatus').innerText='Testing image...'; const ok=await testImageLoad(url); const img=document.querySelector('.mug'); if(img) img.src=ok?url:'images/logo.png'; $('#photoStatus').innerText=ok?'Preview loaded. You can save this photo.':'Image failed inside FiveM NUI. Use a direct public https://i.imgur.com/*.png link.'; };
window.savePhoto=async()=>{ const url=normalizeImgUrl($('#photoUrl').value); $('#photoStatus').innerText='Saving photo...'; const ok=await testImageLoad(url); if(!ok){ $('#photoStatus').innerText='Not saved: image failed to load inside FiveM NUI.'; return; } const res=await nui('saveProfilePhoto',{citizenid:state.currentProfile.citizenid,photo:url}); $('#photoStatus').innerText=res&&res.ok?'Photo saved.':'Save failed. Check server console.'; openProfile(state.currentProfile.citizenid,true); };
function resetCreateCase(){ $('#newCaseTitle').value=''; $('#newCaseStatus').value='open'; $('#newCaseSummary').value=''; $('#newCaseReport').innerHTML=''; $('#createCaseStatus').innerText=''; }
function openCreateCase(){ resetCreateCase(); $('#caseCreateModal').classList.remove('hidden'); setTimeout(()=>$('#newCaseTitle').focus(),50); }
function closeCreateCase(){ $('#caseCreateModal').classList.add('hidden'); }
$('#closeCreateCase').onclick=closeCreateCase; $('#cancelCreateCase').onclick=closeCreateCase;
$('#submitCreateCase').onclick=async()=>{ const title=$('#newCaseTitle').value.trim(); const summary=$('#newCaseSummary').value.trim(); const report_html=await prepareReportHtml($('#newCaseReport').innerHTML.trim()); if(!title){ $('#createCaseStatus').innerText='Please add a case name first.'; return; } $('#createCaseStatus').innerText='Creating case...'; const r=await nui('createCase',{title,summary,report_html,status:$('#newCaseStatus').value}); if(r.ok){ closeCreateCase(); await openCase(r.case_id); refreshDashboard(); } else $('#createCaseStatus').innerText=r.error||'Failed to create case.'; };
$('#searchCasesBtn').onclick=async()=>{ const r=await nui('searchCases',{query:$('#caseSearch').value}); $('#casesList').innerHTML=(r.cases||[]).map(c=>`<div class='item' onclick="openCase('${esc(c.case_id)}')"><b>${esc(c.case_id)}</b> ${esc(c.title)}<br><span class='muted'>${esc(c.status)} • ${timeAgo(c.updated_at)}</span></div>`).join('')||'<p class=muted>No cases.</p>'; };
window.openCase=async(id,skipTab=false)=>{ if(!skipTab){ addWorkTab('cases','case-'+id,id); const t=state.openTabs.find(t=>t.id==='case-'+id); t.case_id=id; } showTab('cases'); const r=await nui('getCase',{case_id:id}); if(!r.ok)return; state.currentCase=r.case; const c=r.case; $('#caseWorkspace').classList.remove('hidden'); $('#caseTitle').innerText=`${c.case_id} • ${c.status}`; $('#caseEditTitle').value=c.title||''; $('#caseSummary').value=c.summary||''; $('#caseReport').innerHTML=c.report_html||''; renderCaseBits(); loadEvidence(c.case_id); };
function renderCaseBits(){ const c=state.currentCase||{}; $('#casePeople').innerHTML=(c.people||[]).map(p=>`<div class='item casePerson'><div onclick="openProfile('${esc(p.citizenid)}')"><b>${esc(p.role)}</b> ${esc(p.name||p.citizenid)} <span class='muted'>${esc(p.citizenid)}</span></div><button class='miniDanger' onclick="event.stopPropagation();removeCasePerson('${esc(p.citizenid)}')">×</button></div>`).join('')||'<p class=muted>No people assigned.</p>'; let fine=0,months=0; $('#caseCharges').innerHTML=(c.charges||[]).map(ch=>{fine+=Number(ch.fine||0);months+=Number(ch.months||0);return `<div class='item'><b>${esc(ch.title)}</b><br><span class='muted'>$${ch.fine} • ${ch.months} months</span></div>`}).join('')||'<p class=muted>No charges.</p>'; $('#chargeTotals').innerText=`Total: $${fine.toLocaleString()} • ${months} months`; }
async function prepareReportHtml(html){ const ids=[...new Set((html.match(/@([A-Za-z0-9]+)/g)||[]).map(x=>x.substring(1)))]; for(const id of ids){ const r=await nui('getProfile',{citizenid:id}); if(r.ok){ const p=r.profile; const photo=normalizeImgUrl(p.photo)||'images/logo.png'; const chip=`<span class="mention" contenteditable="false" onclick="openProfile('${esc(id)}')"><img src="${esc(photo)}" onerror="this.src='images/logo.png'">${esc(p.name)} <small>${esc(id)}</small></span>`; html=html.replaceAll('@'+id, chip); } } return html; }
$('#saveCase').onclick=async()=>{ if(!state.currentCase)return; const report_html=await prepareReportHtml($('#caseReport').innerHTML); await nui('updateCase',{case_id:state.currentCase.case_id,title:$('#caseEditTitle').value,summary:$('#caseSummary').value,report_html}); openCase(state.currentCase.case_id,true); };
$('#closeCase').onclick=async()=>{ if(!state.currentCase)return; await nui('closeCase',{case_id:state.currentCase.case_id,status:'closed'}); openCase(state.currentCase.case_id,true); };
$('#deleteCase').onclick=()=>{ if(!state.currentCase)return; showConfirm('Delete Case',`Delete ${state.currentCase.case_id}? This cannot be undone.`,async()=>{ const id=state.currentCase.case_id; await nui('deleteCase',{case_id:id}); closeWorkTab('case-'+id); $('#caseWorkspace').classList.add('hidden'); refreshDashboard(); }); };
$('#assignSelf').onclick=async()=>{ if(!state.currentCase)return; await nui('assignCase',{case_id:state.currentCase.case_id}); openCase(state.currentCase.case_id,true); };
$('#addCasePerson').onclick=async()=>{ if(!state.currentCase)return; await nui('addCasePerson',{case_id:state.currentCase.case_id,citizenid:$('#casePersonCitizenid').value,role:$('#casePersonRole').value}); $('#casePersonCitizenid').value=''; openCase(state.currentCase.case_id,true); };
window.removeCasePerson=async(cid)=>{
  if(!state.currentCase) return;
  await nui('removeCasePerson',{case_id:state.currentCase.case_id,citizenid:cid});
  openCase(state.currentCase.case_id,true);
};

function showConfirm(title,text,cb){ $('#confirmTitle').innerText=title; $('#confirmText').innerText=text; state.confirmCb=cb; $('#confirmModal').classList.remove('hidden'); }
$('#confirmNo').onclick=$('#confirmCancel').onclick=()=>$('#confirmModal').classList.add('hidden'); $('#confirmYes').onclick=async()=>{ $('#confirmModal').classList.add('hidden'); if(state.confirmCb) await state.confirmCb(); state.confirmCb=null; };
$$('.toolbar button').forEach(b=>{ b.onmousedown=e=>e.preventDefault(); b.onclick=()=>{ document.execCommand(b.dataset.cmd,false,null); updateToolbar(); }; });
function updateToolbar(){ $$('.toolbar button').forEach(b=>b.classList.toggle('active',document.queryCommandState(b.dataset.cmd))); }
document.addEventListener('selectionchange',updateToolbar);
$('#openCharges').onclick=()=>{ $('#chargeModal').classList.remove('hidden'); renderCharges(); }; $('#closeCharges').onclick=()=>$('#chargeModal').classList.add('hidden'); $('#chargeSearch').oninput=renderCharges;
function renderCharges(){ const q=($('#chargeSearch')?.value||'').toLowerCase(); $('#chargeGrid').innerHTML=(state.charges||[]).filter(c=>!q||JSON.stringify(c).toLowerCase().includes(q)).map(c=>`<div class='charge'><h3>${esc(c.title)}</h3><div><span class='pill'>${esc(c.category)}</span><span class='pill'>$${Number(c.fine).toLocaleString()}</span><span class='pill'>${c.months} months</span></div><p>${esc(c.description)}</p><button onclick="addCharge('${esc(c.id)}')">Add Charge</button></div>`).join(''); }
window.addCharge=async(id)=>{ if(!state.currentCase)return; await nui('addCharge',{case_id:state.currentCase.case_id,chargeId:id}); $('#chargeModal').classList.add('hidden'); openCase(state.currentCase.case_id,true); };
$('#saveCallsign').onclick=async()=>{ const r=await nui('saveCallsign',{citizenid:$('#bossCitizenid').value,callsign:$('#bossCallsign').value,rank_label:$('#bossRank').value}); $('#appsPreview').innerHTML=`<p class='${r.ok?'ok':'bad'}'>${r.ok?'Saved callsign.':'Boss only / failed.'}</p>`; };
async function loadApps(){ const r=await nui('getApplications'); const html=(r.applications||[]).map(a=>`<div class='item'><b>${esc(a.name)}</b> <span class='pill'>${esc(a.status)}</span><br><span class='muted'>${esc(a.citizenid)} • ${timeAgo(a.created_at)}</span><p>${esc(a.answers)}</p><button onclick="appStatus(${a.id},'accepted')">Accept</button> <button onclick="appStatus(${a.id},'denied')">Deny</button></div>`).join('')||'<p class=muted>No applications.</p>'; $('#applicationsList').innerHTML=html; $('#appsPreview').innerHTML=html; }
$('#loadApps').onclick=loadApps; window.appStatus=async(id,status)=>{ await nui('setApplicationStatus',{id,status}); loadApps(); };
async function handleSuggest(input){ const type=input.dataset.suggest, q=input.value.trim(), box=input.parentElement.querySelector('.suggestions'); if(!box) return; if(q.length<1){ box.classList.remove('show'); box.innerHTML=''; return; } clearTimeout(state.suggestTimer); state.suggestTimer=setTimeout(async()=>{ let html=''; if(type==='cases'||type==='global'){ const r=await nui('searchCases',{query:q}); html+=(r.cases||[]).slice(0,8).map(c=>`<div onclick="openCase('${esc(c.case_id)}');hideSuggests()">📁 <b>${esc(c.case_id)}</b><span>${esc(c.title)}</span></div>`).join(''); } if(type==='players'||type==='global'){ const r=await nui('searchPlayers',{query:q}); html+=(r.players||[]).slice(0,8).map(p=>`<div onclick="${input.id==='casePersonCitizenid'?`document.getElementById('casePersonCitizenid').value='${esc(p.citizenid)}'`:`openProfile('${esc(p.citizenid)}')`};hideSuggests()">👤 <b>${esc(p.name)}</b><span>${esc(p.citizenid)}</span></div>`).join(''); } box.innerHTML=html||'<div>No close matches.</div>'; box.classList.add('show'); },180); }
function hideSuggests(){ $$('.suggestions').forEach(x=>x.classList.remove('show')); }
$$('input[data-suggest]').forEach(i=>{ i.addEventListener('input',()=>handleSuggest(i)); i.addEventListener('focus',()=>handleSuggest(i)); });
document.addEventListener('click',e=>{ if(!e.target.closest('.suggestWrap')) hideSuggests(); });
$('#caseReport').addEventListener('input',()=>detectMention($('#caseReport'))); $('#newCaseReport').addEventListener('input',()=>detectMention($('#newCaseReport')));
async function detectMention(ed){ const txt=window.getSelection()?.anchorNode?.textContent||''; const m=txt.match(/@([A-Za-z0-9]{2,})$/); if(!m) return; const r=await nui('searchPlayers',{query:m[1]}); let box=$('#mentionSuggest'); if(!box){ box=document.createElement('div'); box.id='mentionSuggest'; box.className='suggestions mentionBox'; document.body.appendChild(box); } box.innerHTML=(r.players||[]).slice(0,5).map(p=>`<div onclick="insertMention('${esc(p.citizenid)}','${esc(p.name)}')">👤 <b>${esc(p.name)}</b><span>${esc(p.citizenid)}</span></div>`).join('')||'<div>No player found.</div>'; box.classList.add('show'); box.style.left='42vw'; box.style.top='32vh'; }
window.insertMention=(cid,name)=>{ document.execCommand('insertHTML',false,`<span class="mention" contenteditable="false" onclick="openProfile('${cid}')"><img src="images/logo.png">${name} <small>${cid}</small></span>&nbsp;`); $('#mentionSuggest')?.classList.remove('show'); };
renderTabs();


// ---------- Evidence System ----------
state.currentEvidenceId = null;
function itemImagePath(item){
  const image = item.image || (item.name ? item.name + '.png' : 'logo.png');
  return 'nui://qb-inventory/html/images/' + image;
}
async function loadEvidence(caseId){
  if(!caseId) return;
  const r = await nui('getEvidence',{case_id:caseId});
  const photos = r.photos || [];
  const items = r.items || [];
  const photoGrid = $('#photoEvidenceGrid');
  const itemGrid = $('#itemEvidenceGrid');
  if(photoGrid) photoGrid.innerHTML = photos.map(function(e){
    const url = normalizeImgUrl(e.url || '');
    return '<div class="evidenceCard" onclick="inspectEvidence('+Number(e.id)+',\'photo\')"><img src="'+esc(url)+'" referrerpolicy="no-referrer" onerror="this.src=\'images/logo.png\'"><b>'+esc(e.label||'Photo Evidence')+'</b><span>'+esc(e.added_by||'Unknown')+' • '+timeAgo(e.created_at)+'</span></div>';
  }).join('') || '<p class=muted>No photo evidence.</p>';
  if(itemGrid) itemGrid.innerHTML = items.map(function(it){
    return '<div class="evidenceCard itemEvidence"><img src="'+esc(itemImagePath(it))+'" onerror="this.src=\'images/logo.png\'"><b>'+esc(it.label||it.name||'Item')+'</b><span>x'+Number(it.amount||it.count||1)+' • '+esc(it.slot?'Slot '+it.slot:'Evidence Locker')+'</span></div>';
  }).join('') || '<p class=muted>No item evidence yet. Click Open Evidence Inventory and drag items into the case stash.</p>';
}
function openPhotoEvidenceModal(){ if(!state.currentCase) return; $('#photoEvidenceLabel').value=''; $('#photoEvidenceUrl').value=''; $('#photoEvidencePreview').src='images/logo.png'; $('#photoEvidenceStatus').innerText='Paste a direct public image URL. Imgur may still be blocked by FiveM NUI, but it will save to the case.'; $('#photoEvidenceModal').classList.remove('hidden'); }
function closePhotoEvidenceModal(){ $('#photoEvidenceModal').classList.add('hidden'); }
async function previewPhotoEvidence(){ const url=normalizeImgUrl($('#photoEvidenceUrl').value); $('#photoEvidencePreview').src=url||'images/logo.png'; $('#photoEvidenceStatus').innerText='Preview loaded if FiveM NUI allows this host.'; }
async function savePhotoEvidence(){
  if(!state.currentCase) return;
  const label=$('#photoEvidenceLabel').value.trim() || 'Photo Evidence';
  const url=normalizeImgUrl($('#photoEvidenceUrl').value);
  if(!url){ $('#photoEvidenceStatus').innerText='Add an image URL first.'; return; }
  $('#photoEvidenceStatus').innerText='Saving evidence...';
  const r=await nui('addEvidencePhoto',{case_id:state.currentCase.case_id,label:label,url:url});
  if(r.ok){ closePhotoEvidenceModal(); loadEvidence(state.currentCase.case_id); } else $('#photoEvidenceStatus').innerText=r.error||'Failed to save evidence.';
}
window.inspectEvidence = async function(id,type){
  if(type !== 'photo') return;
  const r=await nui('getEvidence',{case_id:state.currentCase.case_id});
  const e=(r.photos||[]).find(function(x){return Number(x.id)===Number(id)}); if(!e) return;
  state.currentEvidenceId=id;
  $('#inspectEvidenceTitle').innerText=e.label||'Photo Evidence';
  $('#inspectEvidenceBody').innerHTML='<img class="inspectImg" src="'+esc(normalizeImgUrl(e.url))+'" referrerpolicy="no-referrer" onerror="this.src=\'images/logo.png\'"><p class="muted">Added by '+esc(e.added_by||'Unknown')+' • '+timeAgo(e.created_at)+'</p><p>'+esc(e.url)+'</p>';
  $('#evidenceInspectModal').classList.remove('hidden');
}
async function deleteCurrentEvidence(){
  if(!state.currentEvidenceId || !state.currentCase) return;
  await nui('deleteEvidence',{id:state.currentEvidenceId});
  $('#evidenceInspectModal').classList.add('hidden');
  loadEvidence(state.currentCase.case_id);
}
function bindEvidenceButtons(){
  $('#addPhotoEvidence') && ($('#addPhotoEvidence').onclick=openPhotoEvidenceModal);
  $('#closePhotoEvidence') && ($('#closePhotoEvidence').onclick=closePhotoEvidenceModal);
  $('#previewPhotoEvidence') && ($('#previewPhotoEvidence').onclick=previewPhotoEvidence);
  $('#savePhotoEvidence') && ($('#savePhotoEvidence').onclick=savePhotoEvidence);
  $('#closeInspectEvidence') && ($('#closeInspectEvidence').onclick=function(){ $('#evidenceInspectModal').classList.add('hidden'); });
  $('#deleteEvidenceBtn') && ($('#deleteEvidenceBtn').onclick=function(){ showConfirm('Delete Evidence','Delete this evidence photo from the case?',deleteCurrentEvidence); });
  $('#openEvidenceInventory') && ($('#openEvidenceInventory').onclick=async function(){ if(!state.currentCase) return; await nui('openEvidenceInventory',{case_id:state.currentCase.case_id}); setTimeout(function(){loadEvidence(state.currentCase.case_id)},1500); });
}
bindEvidenceButtons();


function renderProfileCases(containerId, list, emptyText){
  const el = document.getElementById(containerId);
  if(!el) return;
  el.innerHTML = (list||[]).map(c=>`
    <div class="profileCaseLink" onclick="openCase('${esc(c.case_id)}')">
      <div><b>${esc(c.case_id)}</b> ${esc(c.title||'Untitled Case')}</div>
      <span class="pill">${esc(c.status||'open')}</span>
      <small>${esc(c.role||'Attached')} • Updated ${timeAgo(c.updated_at)}</small>
    </div>
  `).join('') || `<p class="muted">${emptyText}</p>`;
}

async function loadProfileCases(citizenid){
  const r = await nui('getCasesForPlayer',{citizenid});
  if(!r || !r.ok){
    renderProfileCases('profileCurrentCases', [], 'Could not load current cases.');
    renderProfileCases('profilePastCases', [], 'Could not load past cases.');
    return;
  }
  renderProfileCases('profileCurrentCases', r.current || [], 'No current cases attached.');
  renderProfileCases('profilePastCases', r.past || [], 'No past cases attached.');
}


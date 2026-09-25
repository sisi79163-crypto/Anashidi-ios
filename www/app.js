const defaultTracks = [
  {id:'1',title:'نور القلب',artist:'منشد تجريبي',category:'روحانيات',duration:'3:42',cover:'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=600&q=80',audio:'',lyrics:'يا رب زد قلبي نوراً وطمأنينة.\nهذا نص تجريبي فقط.'},
  {id:'2',title:'يا رمضان',artist:'صوت الهدى',category:'رمضان',duration:'4:10',cover:'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=600&q=80',audio:'',lyrics:'مرحباً يا شهر الخير.\nنص تجريبي غير مقتبس من عمل محمي.'},
  {id:'3',title:'سبيل السلام',artist:'فرقة النور',category:'بدون إيقاع',duration:'3:18',cover:'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=600&q=80',audio:'',lyrics:'نسير إلى الخير بخطى ثابتة.'},
  {id:'4',title:'همة الشباب',artist:'منشد تجريبي',category:'حماسية',duration:'2:57',cover:'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=600&q=80',audio:'',lyrics:'نص تجريبي لعرض شكل الكلمات.'},
  {id:'5',title:'ابتسامة صغيرة',artist:'براعم',category:'أطفال',duration:'2:35',cover:'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=80',audio:'',lyrics:'نشيد تجريبي للأطفال.'},
  {id:'6',title:'ذكر وطمأنينة',artist:'صوت السكينة',category:'روحانيات',duration:'5:02',cover:'https://images.unsplash.com/photo-1500534314209-a25ddb2bd4297?auto=format&fit=crop&w=600&q=80',audio:'',lyrics:'ألا بذكر الله تطمئن القلوب.'}
];

let tracks = JSON.parse(localStorage.getItem('anashidi_tracks')||'null') || defaultTracks;
let favorites = new Set(JSON.parse(localStorage.getItem('anashidi_favs')||'[]'));
let recent = JSON.parse(localStorage.getItem('anashidi_recent')||'[]');
let route = 'home';
let currentIndex = 0;
let repeat = false;
const app = document.getElementById('app');
const audio = document.getElementById('audio');
const mini = document.getElementById('miniPlayer');
const playerDialog = document.getElementById('playerDialog');
const detailsDialog = document.getElementById('detailsDialog');

function persist(){ localStorage.setItem('anashidi_tracks',JSON.stringify(tracks)); localStorage.setItem('anashidi_favs',JSON.stringify([...favorites])); localStorage.setItem('anashidi_recent',JSON.stringify(recent)); }
function toast(msg){ const t=document.createElement('div');t.className='toast';t.textContent=msg;document.body.appendChild(t);setTimeout(()=>t.remove(),1800); }
function esc(s=''){return s.replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));}
function favIcon(id){return favorites.has(id)?'♥':'♡'}
function trackCard(t){return `<article class="card" onclick="openDetails('${t.id}')"><img class="cover" src="${t.cover}" alt="غلاف ${esc(t.title)}"><h3>${esc(t.title)}</h3><p>${esc(t.artist)} · ${esc(t.category)}</p></article>`}
function trackRow(t){return `<div class="track-row"><img src="${t.cover}" alt=""><div onclick="openDetails('${t.id}')"><strong>${esc(t.title)}</strong><small>${esc(t.artist)} · ${t.duration}</small></div><div class="track-actions"><button class="ghost" onclick="event.stopPropagation();toggleFav('${t.id}')">${favIcon(t.id)}</button><button class="ghost" onclick="event.stopPropagation();playTrack('${t.id}')">▶</button></div></div>`}

function render(){
  document.querySelectorAll('.nav-item').forEach(b=>b.classList.toggle('active',b.dataset.route===route));
  if(route==='home') renderHome();
  if(route==='search') renderSearch();
  if(route==='favorites') renderFavorites();
  if(route==='library') renderLibrary();
  if(route==='admin') renderAdmin();
}

function renderHome(){
  const cats=[...new Set(tracks.map(t=>t.category))];
  app.innerHTML=`<section class="hero"><div class="eyebrow">تطبيقك العربي للأناشيد</div><h2>اسمع بهدوء</h2><p>واجهة بسيطة للأناشيد، المفضلة، والبحث. أضف الملفات الصوتية المصرّح لك باستخدامها من لوحة الإدارة.</p><button class="primary" onclick="playTrack('${tracks[0]?.id||''}')">تشغيل الآن</button></section>
  <section class="section"><div class="section-head"><h2>استمع الآن</h2></div><div class="grid">${tracks.slice(0,6).map(trackCard).join('')}</div></section>
  <section class="section"><div class="section-head"><h2>حسب التصنيف</h2></div><div class="chips">${cats.map(c=>`<button class="chip" onclick="filterCategory('${c}')">${c}</button>`).join('')}</div></section>
  <section class="section"><div class="section-head"><h2>أضيف حديثاً</h2></div><div class="row-list">${tracks.slice().reverse().slice(0,5).map(trackRow).join('')}</div></section>`;
}

function renderSearch(){
  app.innerHTML=`<section class="section"><div class="section-head"><h2>البحث</h2></div><input id="searchInput" class="searchbox" placeholder="ابحث باسم النشيد أو المنشد..." autocomplete="off"><div id="searchResults" class="row-list" style="margin-top:14px">${tracks.map(trackRow).join('')}</div></section>`;
  document.getElementById('searchInput').addEventListener('input',e=>{const q=e.target.value.trim().toLowerCase();const r=tracks.filter(t=>(t.title+' '+t.artist+' '+t.category).toLowerCase().includes(q));document.getElementById('searchResults').innerHTML=r.length?r.map(trackRow).join(''):'<div class="empty">لا توجد نتائج.</div>';});
}
function renderFavorites(){const f=tracks.filter(t=>favorites.has(t.id));app.innerHTML=`<section class="section"><div class="section-head"><h2>المفضلة</h2></div><div class="row-list">${f.length?f.map(trackRow).join(''):'<div class="empty">لم تضف أي نشيد إلى المفضلة بعد.</div>'}</div></section>`}
function renderLibrary(){const r=recent.map(id=>tracks.find(t=>t.id===id)).filter(Boolean);app.innerHTML=`<section class="section"><div class="section-head"><h2>مكتبتي</h2><button onclick="route='admin';render()">لوحة الإدارة</button></div><h3>استمعت مؤخراً</h3><div class="row-list">${r.length?r.map(trackRow).join(''):'<div class="empty">لا يوجد سجل استماع بعد.</div>'}</div></section>`}
function renderAdmin(){app.innerHTML=`<section class="section"><div class="section-head"><h2>لوحة الإدارة</h2><button onclick="route='library';render()">رجوع</button></div><p class="small-note">أدخل فقط روابط ملفات صوتية تملك حق استخدامها أو لديك إذن بنشرها.</p><form id="adminForm" class="admin-form"><input name="title" placeholder="اسم النشيد" required><input name="artist" placeholder="اسم المنشد" required><select name="category"><option>روحانيات</option><option>رمضان</option><option>بدون إيقاع</option><option>حماسية</option><option>أطفال</option></select><input name="cover" placeholder="رابط صورة الغلاف" required><input name="audio" placeholder="رابط ملف MP3 المصرّح به"><textarea name="lyrics" placeholder="الكلمات - اختياري"></textarea><button class="primary" type="submit">إضافة النشيد</button></form><section class="section"><div class="row-list">${tracks.map(t=>`<div class="track-row"><img src="${t.cover}"><div><strong>${esc(t.title)}</strong><small>${esc(t.artist)}</small></div><button class="ghost" onclick="deleteTrack('${t.id}')">×</button></div>`).join('')}</div></section></section>`;document.getElementById('adminForm').addEventListener('submit',e=>{e.preventDefault();const d=Object.fromEntries(new FormData(e.target));tracks.push({id:Date.now().toString(),title:d.title,artist:d.artist,category:d.category,duration:'—',cover:d.cover,audio:d.audio,lyrics:d.lyrics});persist();toast('تمت إضافة النشيد');renderAdmin();});}

window.filterCategory=(c)=>{app.innerHTML=`<section class="section"><div class="section-head"><h2>${c}</h2><button onclick="renderHome()">الكل</button></div><div class="grid">${tracks.filter(t=>t.category===c).map(trackCard).join('')}</div></section>`};
window.toggleFav=(id)=>{favorites.has(id)?favorites.delete(id):favorites.add(id);persist();toast(favorites.has(id)?'أضيف إلى المفضلة':'حذف من المفضلة');render();syncCurrent();};
window.openDetails=(id)=>{const t=tracks.find(x=>x.id===id);if(!t)return;document.getElementById('detailsContent').innerHTML=`<img class="full-cover" src="${t.cover}" alt=""><h2 style="text-align:center">${esc(t.title)}</h2><p style="text-align:center;color:var(--muted)">${esc(t.artist)} · ${esc(t.category)} · ${t.duration}</p><div style="display:flex;gap:10px;justify-content:center;margin:16px 0"><button class="primary" onclick="playTrack('${t.id}');detailsDialog.close()">تشغيل</button><button class="ghost" onclick="toggleFav('${t.id}')">${favIcon(t.id)}</button></div><section class="lyrics-card"><h3>الكلمات</h3><p>${esc(t.lyrics||'لا توجد كلمات مضافة.').replace(/\n/g,'<br>')}</p></section>`;detailsDialog.showModal();};
window.playTrack=(id)=>{const i=tracks.findIndex(t=>t.id===id);if(i<0)return;currentIndex=i;const t=tracks[i];recent=[t.id,...recent.filter(x=>x!==t.id)].slice(0,20);persist();mini.classList.remove('hidden');if(!t.audio){audio.removeAttribute('src');audio.load();toast('هذا نشيد تجريبي. أضف رابط MP3 من لوحة الإدارة.');syncCurrent(false);return;}audio.src=t.audio;audio.play().catch(()=>toast('تعذر تشغيل الملف الصوتي'));syncCurrent(true);};
window.deleteTrack=(id)=>{tracks=tracks.filter(t=>t.id!==id);favorites.delete(id);recent=recent.filter(x=>x!==id);persist();renderAdmin();toast('تم حذف النشيد');};

function syncCurrent(isPlaying=!audio.paused){const t=tracks[currentIndex];if(!t)return;document.getElementById('miniCover').src=t.cover;document.getElementById('miniTitle').textContent=t.title;document.getElementById('miniArtist').textContent=t.artist;document.getElementById('playPauseBtn').textContent=isPlaying?'❚❚':'▶';document.getElementById('fullCover').src=t.cover;document.getElementById('fullTitle').textContent=t.title;document.getElementById('fullArtist').textContent=t.artist;document.getElementById('lyrics').innerHTML=esc(t.lyrics||'لا توجد كلمات مضافة لهذا النشيد.').replace(/\n/g,'<br>');document.getElementById('favCurrent').textContent=favIcon(t.id);document.getElementById('fullPlay').textContent=isPlaying?'❚❚':'▶';}
function playPause(){const t=tracks[currentIndex];if(!t)return;if(!t.audio){toast('أضف رابط MP3 من لوحة الإدارة.');return;}if(audio.paused)audio.play();else audio.pause();}
function next(){if(!tracks.length)return;currentIndex=(currentIndex+1)%tracks.length;playTrack(tracks[currentIndex].id)}
function prev(){if(!tracks.length)return;currentIndex=(currentIndex-1+tracks.length)%tracks.length;playTrack(tracks[currentIndex].id)}
function formatTime(v){if(!isFinite(v))return'0:00';const m=Math.floor(v/60),s=Math.floor(v%60).toString().padStart(2,'0');return`${m}:${s}`}

document.querySelectorAll('.nav-item').forEach(b=>b.addEventListener('click',()=>{route=b.dataset.route;render()}));
document.getElementById('playPauseBtn').onclick=playPause;document.getElementById('fullPlay').onclick=playPause;document.getElementById('nextBtn').onclick=next;document.getElementById('fullNext').onclick=next;document.getElementById('prevBtn').onclick=prev;document.getElementById('fullPrev').onclick=prev;document.getElementById('openPlayer').onclick=()=>{syncCurrent();playerDialog.showModal()};document.getElementById('closePlayer').onclick=()=>playerDialog.close();document.getElementById('closeDetails').onclick=()=>detailsDialog.close();document.getElementById('favCurrent').onclick=()=>{const t=tracks[currentIndex];if(t)toggleFav(t.id)};document.getElementById('repeatBtn').onclick=()=>{repeat=!repeat;audio.loop=repeat;toast(repeat?'تم تشغيل التكرار':'تم إيقاف التكرار')};
audio.addEventListener('play',()=>syncCurrent(true));audio.addEventListener('pause',()=>syncCurrent(false));audio.addEventListener('ended',()=>{if(!repeat)next()});audio.addEventListener('timeupdate',()=>{document.getElementById('seek').value=audio.duration?(audio.currentTime/audio.duration)*100:0;document.getElementById('currentTime').textContent=formatTime(audio.currentTime);document.getElementById('duration').textContent=formatTime(audio.duration)});document.getElementById('seek').addEventListener('input',e=>{if(audio.duration)audio.currentTime=(e.target.value/100)*audio.duration});
document.getElementById('themeBtn').onclick=()=>toast('المظهر الداكن هو الافتراضي حالياً');
if('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(()=>{});
render();

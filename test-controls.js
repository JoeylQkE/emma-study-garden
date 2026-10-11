'use strict';
function testDate(){try{const d=localStorage.getItem('emma-garden-test-date');return /^\d{4}-\d{2}-\d{2}$/.test(d||'')?d:G.dayKey(new Date())}catch{return G.dayKey(new Date())}}
window.labLuck=()=> $('luckOverride').value==='random'?Math.random:()=> $('luckOverride').value==='yes'?0:.999;
window.labPrize=()=> $('prizeOverride').value==='random'?Math.random:()=> (Number($('prizeOverride').value)+.5)/4;
window.renderLab=()=>{try{localStorage.setItem('emma-garden-test-date',date)}catch{} $('testDate').value=date;document.querySelectorAll('#testPanel button,#testPanel input,#testPanel select').forEach(e=>e.disabled=busy)};
$('testDate').onchange=()=>{if(!test||busy||!$('testDate').value)return;setDate($('testDate').value)};
function profile(){return Array.from({length:Number($('taskProfile').value)},(_,i)=>i)}
$('completeToday').onclick=()=>{if(!test||busy)return;if(state.days.includes(date)){toast('这一天已经签到。可以换日期或重置测试数据。');return}state.tasks[date]=profile();save();sign()};$('nextDay').onclick=()=>{if(test&&!busy)setDate(G.shift(date,1))};
function simulate(start,count,all=false){if(!test||busy)return;let added=0;const cards=[];for(let i=0;i<count;i++){const d=G.shift(start,i);if(!state.days.includes(d)){state.tasks[d]=all?[0,1,2,3,4]:profile();const result=G.checkIn(state,d,luckRandom());if(result.ok){added++;cards.push(...result.unlocked)}}}date=G.shift(start,count-1);calendarMonth=date.slice(0,7);save();render();flowers();toast(`模拟 ${count} 天，新增 ${added} 次有效打卡。`);openRewards(cards)}
document.querySelectorAll('[data-run]').forEach(b=>b.onclick=()=>simulate(date,Number(b.dataset.run)));$('fullAttendance').onclick=()=>simulate(G.START,G.attendance(state).total,true);
$('gapScenario').onclick=()=>{if(!test||busy)return;if(!confirm('建立断签测试场景会重置测试记录，日常记录不受影响。继续吗？'))return;state=G.empty();for(const d of ['2026-10-11','2026-10-12','2026-10-13','2026-10-15','2026-10-16','2026-10-17']){state.tasks[d]=d==='2026-10-11'?[0]:[0,1,2];G.checkIn(state,d,()=>.99)}date='2026-10-17';calendarMonth='2026-10';save();render();toast('10 月 14 日漏签，周六获得 1 次补签机会。点击月历中的 14 日试试。')};
$('addTicket').onclick=()=>{if(!test||busy)return;state.bonus=(state.bonus||0)+1;save();render();toast('已添加一次测试抽奖机会 🎟️')};$('resetTest').onclick=()=>{if(!test||busy)return;if(!confirm('清空全部测试打卡、奖励和抽奖记录？日常数据不会被删除。'))return;state=G.empty();date=G.dayKey(new Date());calendarMonth=date.slice(0,7);save();rotation=0;$('wheel').style.transform='rotate(0deg)';render();toast('测试数据已重置。')};
date=testDate();calendarMonth=date.slice(0,7);render();

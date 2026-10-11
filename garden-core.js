(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.Garden=api})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
const START='2026-10-11',END='2026-11-09';
const prizes=['一次爱心外卖','为你唱一首歌','为你读一个故事','一杯喜欢的奶茶'];
const milestones=[{days:3,name:'一份外卖',icon:'🍱',art:'meal'},{days:7,name:'巧克力',icon:'🍫',art:'chocolate'},{days:14,name:'零食大礼包',icon:'🍪',art:'snacks'}];
const prizeArt=['meal','song','story','tea'];
function dayKey(d){return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`}
function shift(key,n){const d=new Date(key+'T12:00:00');d.setDate(d.getDate()+n);return dayKey(d)}
function weekend(date){return [0,6].includes(new Date(date+'T12:00:00').getDay())}
function empty(){return {version:3,days:[],tasks:{},luck:{},probabilities:{},draws:[],unlocked:[],bonus:0,makeupEarned:[],makeups:{},rewards:[]}}
function rules(s,date){const items=[...new Set(s.tasks[date]||[])].filter(n=>Number.isInteger(n)&&n>=0&&n<5),words=items.includes(0),extras=items.filter(n=>n!==0).length,isWeekend=weekend(date);return {words,extras,isWeekend,eligible:words&&(isWeekend||extras>=2),probability:words?(extras>=4?.8:extras===3?.55:extras===2?.35:0):0,makeupEligible:isWeekend&&words&&extras>=2}}
function streak(s,date){let d=s.days.includes(date)?date:shift(date,-1),n=0;while(s.days.includes(d)){n++;d=shift(d,-1)}return n}
function tickets(s){return Math.max(0,Object.values(s.luck).filter(Boolean).length+(s.bonus||0)-s.draws.length)}
function makeupTickets(s){return Math.max(0,s.makeupEarned.length-Object.keys(s.makeups).length)}
function reward(s,id,date,name,source,art){if(s.rewards.some(r=>r.id===id))return null;const r={id,date,name,source,art};s.rewards.push(r);return r}
function unlock(s,date){const added=[];let best=0,run=0,previous=null;for(const d of [...s.days].sort()){run=previous&&shift(previous,1)===d?run+1:1;best=Math.max(best,run);previous=d}for(const m of milestones){if(best>=m.days&&!s.unlocked.includes(m.days)){s.unlocked.push(m.days);const r=reward(s,'milestone-'+m.days,date,m.name,`连续签到 ${m.days} 天` ,m.art);if(r)added.push(r)}}if(attendance(s).complete){const r=reward(s,'attendance',date,'神秘惊喜','考前全勤','mystery');if(r)added.push(r)}return added}
function checkIn(s,date,random=Math.random){if(s.days.includes(date))return {ok:false,reason:'这一天已经打卡，不能重复抽取机会'};const r=rules(s,date);if(!r.eligible)return {ok:false,reason:r.isWeekend?'周末完成背单词即可打卡':'工作日需完成背单词，再完成至少两项练习'};s.days.push(date);s.days.sort();const lucky=r.probability>0&&random()<r.probability;s.luck[date]=lucky;s.probabilities[date]=r.probability;if(r.makeupEligible&&!s.makeupEarned.includes(date))s.makeupEarned.push(date);return {ok:true,lucky,probability:r.probability,makeup:r.makeupEligible,unlocked:unlock(s,date)}}
function draw(s,date,random=Math.random){if(!tickets(s))return null;const index=Math.min(3,Math.floor(random()*4));const id='draw-'+(s.draws.length+1);const result={id,date,index,prize:prizes[index]};s.draws.push(result);result.reward=reward(s,id,date,prizes[index],'幸运转盘',prizeArt[index]);return result}
function attendance(s){let count=0,total=0;for(let d=START;d<=END;d=shift(d,1)){total++;if(s.days.includes(d))count++}return {count,total,complete:count===total}}
function growth(s,date){const n=s.days.filter(d=>d<=date).length;return n===0?0:n<3?1:n<7?2:n<14?3:4}
function missing(s,date){const days=[];for(let d=START;d<date&&d<=END;d=shift(d,1))if(!s.days.includes(d))days.push(d);return days}
function makeup(s,target,date){if(!makeupTickets(s))return {ok:false,reason:'还没有补签机会，周末完成背单词＋两项练习即可获得'};if(!missing(s,date).includes(target))return {ok:false,reason:'只能补签学习区间内已经过去、还未签到的日期'};s.makeups[target]={usedOn:date};s.days.push(target);s.days.sort();return {ok:true,unlocked:unlock(s,date)}}
function normalize(old,date){if(!old||!Array.isArray(old.days))return empty();const s=Object.assign(empty(),old,{version:3});s.days=[...new Set(old.days)].filter(d=>/^\d{4}-\d{2}-\d{2}$/.test(d));for(const name of ['tasks','luck','probabilities','makeups'])if(!s[name]||Array.isArray(s[name])||typeof s[name]!=='object')s[name]={};for(const name of ['draws','unlocked','makeupEarned','rewards'])if(!Array.isArray(s[name]))s[name]=[];if(old.version!==3){for(const d of s.days){s.tasks[d]=s.tasks[d]||[0,1,2];if(!(d in s.probabilities))s.probabilities[d]=.5}for(const m of milestones)if(s.unlocked.includes(m.days))reward(s,'milestone-'+m.days,date,m.name,`连续签到 ${m.days} 天`,m.art);s.draws.forEach((r,i)=>{r.id=r.id||'draw-'+(i+1);reward(s,r.id,r.date,prizes[r.index]||r.prize,'幸运转盘',prizeArt[r.index]||'mystery')});unlock(s,date)}return s}
return {START,END,prizes,prizeArt,milestones,dayKey,shift,weekend,empty,rules,streak,tickets,makeupTickets,checkIn,draw,attendance,growth,missing,makeup,normalize};
});

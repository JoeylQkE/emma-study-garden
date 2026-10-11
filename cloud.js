'use strict';
window.GardenCloud=(()=>{
const config=window.GARDEN_CLOUD_CONFIG||{},url=(config.url||'').replace(/\/$/,''),key=config.publishableKey||'';
const configured=/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url)&&Boolean(key),storageKey='emma-auth:'+url;
let session=null,refreshing=null;
function stored(name){try{return JSON.parse(localStorage.getItem(name))}catch{return null}}
function persist(s){session=s;try{if(s)localStorage.setItem(storageKey,JSON.stringify(s));else localStorage.removeItem(storageKey)}catch{throw new Error('请允许浏览器保存登录状态，再重新登录。')}}
function tokenSession(s){return {access_token:s.access_token,refresh_token:s.refresh_token,expires_at:s.expires_at||Math.floor(Date.now()/1000)+s.expires_in}}
if(configured)session=stored(storageKey);
async function send(path,body,token){const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),15000);try{const headers={'apikey':key,'Content-Type':'application/json'};if(token)headers.Authorization='Bearer '+token;const r=await fetch(url+path,{method:'POST',headers,body:JSON.stringify(body),signal:ctrl.signal,cache:'no-store',credentials:'omit'});let data;try{data=await r.json()}catch{data={}}if(!r.ok){const message=r.status>=500?'连接暂时不稳定，尚未确认保存，请重新同步。':data.code==='PGRST202'?'花园还没有完成初始化，请联系 Joey。':data.message||data.msg||data.error_description||'暂时无法完成操作，请重试。';const e=new Error(message);e.status=r.status;e.code=data.code;throw e}return data}catch(e){if(!e.status){const failure=new Error('连接暂时中断，尚未确认保存。请重新同步。');failure.status=0;throw failure}throw e}finally{clearTimeout(timer)}}
async function refresh(){if(refreshing)return refreshing;if(!session?.refresh_token)throw new Error('请先登录。');refreshing=(async()=>{try{const s=await send('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token});persist(tokenSession(s));return session.access_token}catch(e){if(e.status===400||e.status===401)persist(null);throw e}finally{refreshing=null}})();return refreshing}
async function rpc(name,body){if(!session)throw new Error('请先登录。');let token=session.access_token;if(session.expires_at*1000<Date.now()+30000)token=await refresh();try{return await send('/rest/v1/rpc/'+name,body,token)}catch(e){if(e.status!==401)throw e;token=await refresh();return send('/rest/v1/rpc/'+name,body,token)}}
function pendingKey(){return storageKey+':pending:'+(session?.access_token?userId(): 'none')}
function userId(){try{return JSON.parse(atob(session.access_token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).sub}catch{return 'session'}}
function pending(){return session?stored(pendingKey()):null}
function remember(body){try{localStorage.setItem(pendingKey(),JSON.stringify(body))}catch{throw new Error('请允许浏览器存储，才能可靠保存学习记录。')}}
function clearPending(){try{localStorage.removeItem(pendingKey())}catch{}}
async function resolvePending(){const p=pending();if(!p)return null;try{const result=await rpc('garden_action',p);clearPending();return result}catch(e){if(e.status>=400&&e.status<500&&e.status!==401)clearPending();throw e}}
async function action(name,args={}){if(pending())throw new Error('先重新同步，确认上一次操作，再继续。');const body={p_action:name,p_request_id:crypto.randomUUID(),...args};remember(body);return resolvePending()}
async function login(email,password){const s=await send('/auth/v1/token?grant_type=password',{email,password});persist(tokenSession(s));return snapshot()}
async function logout(){try{if(session)await send('/auth/v1/logout',{},session.access_token)}catch{}persist(null)}
async function snapshot(){const saved=await resolvePending();return saved||rpc('garden_snapshot',{})}
window.addEventListener('storage',e=>{if(e.key===storageKey){session=stored(storageKey);window.dispatchEvent(new Event('garden-auth-change'))}});
return {configured,hasSession:()=>Boolean(session),hasPending:()=>Boolean(pending()),snapshot,action,login,logout};
})();

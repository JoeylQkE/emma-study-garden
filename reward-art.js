'use strict';
window.paintReward=function(canvas,r,isTest){
const c=canvas.getContext('2d'),W=720,H=900;const palettes={meal:['#e4b196','#e9c3aa'],song:['#b9c6df','#dce1ed'],story:['#b5c8a8','#dfe6d4'],tea:['#d4b2bc','#ead6d9'],chocolate:['#bba28d','#e3d2bf'],snacks:['#e1bb75','#f0dfb7'],mystery:['#c4afd1','#e8dcee']};const [accent,pale]=palettes[r.art]||palettes.mystery;
c.clearRect(0,0,W,H);c.fillStyle='#fff9ee';c.fillRect(0,0,W,H);
function round(x,y,w,h,rad,fill,stroke){c.beginPath();c.roundRect(x,y,w,h,rad);if(fill){c.fillStyle=fill;c.fill()}if(stroke){c.strokeStyle=stroke;c.lineWidth=3;c.stroke()}}
function ellipse(x,y,rx,ry,fill,rotation=0){c.beginPath();c.ellipse(x,y,rx,ry,rotation,0,Math.PI*2);c.fillStyle=fill;c.fill()}
function line(points,color='#76604f',width=4){c.beginPath();c.moveTo(...points[0]);for(let i=1;i<points.length;i++)c.lineTo(...points[i]);c.strokeStyle=color;c.lineWidth=width;c.lineCap='round';c.lineJoin='round';c.stroke()}
function text(str,x,y,size,color='#405741',weight='400'){c.font=`${weight} ${size}px "Noto Sans CJK SC","Microsoft YaHei",sans-serif`;c.fillStyle=color;c.textAlign='center';c.fillText(str,x,y)}
function flower(x,y,size=1){c.save();c.translate(x,y);c.scale(size,size);for(let i=0;i<5;i++)ellipse(Math.sin(i*Math.PI*2/5)*12,Math.cos(i*Math.PI*2/5)*12,8,12,accent,i*Math.PI*2/5);ellipse(0,0,6,6,'#e4c678');c.restore()}
round(22,22,676,856,28,null,pale);c.setLineDash([4,10]);round(37,37,646,826,22,null,pale);c.setLineDash([]);flower(68,70,.9);flower(651,70,.9);flower(68,831,.7);flower(651,831,.7);
text('E M M A ’ S   L I T T L E   G A R D E N',360,92,17,'#939b7e','500');round(222,117,276,38,19,pale);text(isTest?'测试兑换卡 · 仅供体验':'一份努力，一份偏爱',360,144,18,'#6b715b');
text('Emma，你的小惊喜到了',360,208,32,'#405741','600');text(r.source,360,248,19,'#999a82');
ellipse(360,414,204,142,pale);ellipse(360,533,161,15,'#d8dac4');
// A soft little rabbit holding a different gift on every card.
ellipse(315,349,21,70,'#fdf6e5',-.17);ellipse(404,347,21,70,'#fdf6e5',.17);ellipse(315,350,9,51,'#ecc7bc',-.17);ellipse(404,348,9,51,'#ecc7bc',.17);
ellipse(360,467,94,77,'#f9f0dd');ellipse(305,530,30,13,'#f9f0dd');ellipse(415,530,30,13,'#f9f0dd');ellipse(360,391,83,64,'#fdf6e5');ellipse(327,396,4,6,'#77634f');ellipse(393,396,4,6,'#77634f');ellipse(309,411,13,6,'#edb8ae');ellipse(410,411,13,6,'#edb8ae');ellipse(360,410,4,3,'#ad8b76');line([[360,413],[360,420],[351,423]],'#ad8b76',2);line([[360,420],[368,423]],'#ad8b76',2);
if(r.art==='meal'){round(303,449,115,61,14,'#edc29f','#b79271');round(311,457,42,43,8,'#fff6df');round(360,457,50,20,7,'#a8bc82');ellipse(385,489,19,13,'#d99a78');ellipse(330,477,9,8,'#e5c974')}
else if(r.art==='tea'){round(326,441,69,85,13,'#d8b68d','#b09274');line([[368,459],[384,418]],'#806b57',6);round(329,470,63,16,3,'#f3dcc0');for(let i=0;i<6;i++)ellipse(338+(i%3)*18,501+Math.floor(i/3)*12,4,4,'#79614e');round(321,441,79,10,4,'#f0d2b3')}
else if(r.art==='story'){round(299,444,62,76,5,'#a7bc91','#809568');round(361,444,62,76,5,'#e9dfbc','#b5aa84');line([[361,444],[361,520]],'#809568',3);for(let i=0;i<4;i++)line([[374,460+i*11],[408,460+i*11]],'#b1a985',2);flower(330,478,.7)}
else if(r.art==='song'){c.beginPath();c.arc(360,385,76,Math.PI,2*Math.PI);c.strokeStyle='#8493b0';c.lineWidth=9;c.stroke();round(278,375,20,42,8,'#acb9cd');round(422,375,20,42,8,'#acb9cd');round(348,443,24,38,12,'#8093b3');line([[360,479],[360,506]],'#8093b3',6);line([[345,507],[375,507]],'#8093b3',4);text('♪',469,342,36,accent);text('♫',245,460,28,accent)}
else if(r.art==='chocolate'){round(325,440,73,84,8,'#8c6851');for(let i=0;i<6;i++)round(332+(i%2)*30,446+Math.floor(i/2)*23,24,18,3,'#ae8162');c.beginPath();c.moveTo(325,482);c.lineTo(398,476);c.lineTo(398,524);c.lineTo(325,524);c.closePath();c.fillStyle='#e5c7bb';c.fill();flower(362,503,.65)}
else if(r.art==='snacks'){round(310,467,106,57,9,'#d4af73');round(316,431,31,64,7,'#d8b99d');round(350,420,35,76,7,'#b5c08e');round(384,439,29,56,7,'#ecc59a');ellipse(331,461,10,10,'#bc8e67');for(let i=0;i<4;i++)ellipse(326+(i%2)*9,456+Math.floor(i/2)*9,1.5,1.5,'#6f5745');text('♡',368,457,22,'#fff6dd')}
else {round(307,455,111,69,9,'#c6b1d3');round(300,449,125,16,6,'#b69cc6');round(353,449,17,75,0,'#f4ddb7');ellipse(345,439,21,10,'#efd6b3',.3);ellipse(375,439,21,10,'#efd6b3',-.3)}
ellipse(301,478,13,23,'#fdf6e5',-.45);ellipse(420,478,13,23,'#fdf6e5',.45);flower(179,355,.7);flower(534,465,.6);
text(r.name,360,595,35,'#405741','600');round(125,628,470,85,16,pale);text('请找 Joey 兑换',360,680,31,'#4e6349','600');text('谢谢你认真照顾自己的每一天 ♡',360,754,20,'#949980');text(`${r.date}  ·  ${r.id.toUpperCase()}`,360,794,15,'#aaa58e');text(isTest?'TEST CARD · 不作为正式兑换凭证':'MADE WITH LOVE · KEEP THIS LITTLE MEMORY',360,835,12,'#b0aa91');
};

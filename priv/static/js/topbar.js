/**
 * Bundled by jsDelivr using Rollup v2.79.2 and Terser v5.39.0.
 * Original file: /npm/topbar@3.0.0/topbar.js
 *
 * Do NOT use SRI with dynamically generated files! More information: https://www.jsdelivr.com/using-sri-with-dynamic-files
 */
var e,n="undefined"!=typeof globalThis?globalThis:"undefined"!=typeof window?window:"undefined"!=typeof global?global:"undefined"!=typeof self?self:{},a={exports:{}};
/**
 * @license MIT
 * topbar 3.0.0
 * http://buunguyen.github.io/topbar
 * Copyright (c) 2024 Buu Nguyen
 */
e=a,function(n,a){var o,t,r,i=null,s=null,l=null,d={autoRun:!0,barThickness:3,barColors:{0:"rgba(26,  188, 156, .9)",".25":"rgba(52,  152, 219, .9)",".50":"rgba(241, 196, 15,  .9)",".75":"rgba(230, 126, 34,  .9)","1.0":"rgba(211, 84,  0,   .9)"},shadowBlur:10,shadowColor:"rgba(0,   0,   0,   .6)",className:null},u=function(){o.width=n.innerWidth,o.height=5*d.barThickness;var e=o.getContext("2d");e.shadowBlur=d.shadowBlur,e.shadowColor=d.shadowColor;var a=e.createLinearGradient(0,0,o.width,0);for(var r in d.barColors)a.addColorStop(r,d.barColors[r]);e.lineWidth=d.barThickness,e.beginPath(),e.moveTo(0,d.barThickness/2),e.lineTo(Math.ceil(t*o.width),d.barThickness/2),e.strokeStyle=a,e.stroke()},c={config:function(e){for(var n in e)d.hasOwnProperty(n)&&(d[n]=e[n])},show:function(e){var h,f,p,g;if(!r)if(e){if(l)return;l=setTimeout((()=>c.show()),e)}else r=!0,null!==s&&n.cancelAnimationFrame(s),o||((g=(o=a.createElement("canvas")).style).position="fixed",g.top=g.left=g.right=g.margin=g.padding=0,g.zIndex=100001,g.display="none",d.className&&o.classList.add(d.className),f="resize",p=u,(h=n).addEventListener?h.addEventListener(f,p,!1):h.attachEvent?h.attachEvent("on"+f,p):h["on"+f]=p),o.parentElement||a.body.appendChild(o),o.style.opacity=1,o.style.display="block",c.progress(0),d.autoRun&&function e(){i=n.requestAnimationFrame(e),c.progress("+"+.05*Math.pow(1-Math.sqrt(t),2))}()},progress:function(e){return void 0===e||("string"==typeof e&&(e=(e.indexOf("+")>=0||e.indexOf("-")>=0?t:0)+parseFloat(e)),t=e>1?1:e,u()),t},hide:function(){clearTimeout(l),l=null,r&&(r=!1,null!=i&&(n.cancelAnimationFrame(i),i=null),function e(){if(c.progress("+.1")>=1&&(o.style.opacity-=.05,o.style.opacity<=.05))return o.style.display="none",void(s=null);s=n.requestAnimationFrame(e)}())}};e.exports=c}.call(n,window,document);var o=a.exports;export{o as default};
//# sourceMappingURL=/sm/46723fadaceadbbd248df3861525e8bb2da1942e049062eed866b45ad22ae873.map
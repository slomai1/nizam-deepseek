// توصيل كل المقطوعات — دفعة واحدة
const fs=require("fs"),p=require("path"),h=require("os").homedir(),f=p.join(h,".claude","settings.json"),j=JSON.parse(fs.readFileSync(f,"utf8")),d=p.join(h,".claude","scripts","hooks");

console.log("🔗 توصيل المقطوعات...\n");

// ============================================
// 1. تفعيل خوادم MCP المعطلة
// ============================================
const servers=["sequential-thinking","tavily","firecrawl","sqlite","ai-vision-mcp","playwright","code-index"];
j.enabledMcpjsonServers=j.enabledMcpjsonServers||[];
const beforeMcp=j.enabledMcpjsonServers.length;
for(const s of servers){if(!j.enabledMcpjsonServers.includes(s)){j.enabledMcpjsonServers.push(s);console.log("  ✅ MCP: "+s)}}
j.enableAllProjectMcpServers=true;
console.log("📡 خوادم MCP: "+beforeMcp+" → "+j.enabledMcpjsonServers.length+" (تم تفعيل "+(j.enabledMcpjsonServers.length-beforeMcp)+")\n");

// ============================================
// 2. تنظيف الجلسات + حلم تلقائي
// ============================================
j.cleanupPeriodDays=7;
j.autoDreamEnabled=true;
console.log("🧹 cleanupPeriodDays: 7");
console.log("💤 autoDreamEnabled: true\n");

// ============================================
// 3. إضافة مزامنة SQLite→Markdown لـ SessionStart
// ============================================
const syncCmd=fs.readFileSync(p.join(d,"..","sync-memory.js"),"utf8").trim();
const ss=j.hooks.SessionStart[0];
const curHooks=new Set(ss.hooks.map(hk=>hk.command.substring(0,80)));

// Add sync-memory if not already present
if(![...curHooks].some(c=>c.includes("sync-memory"))){
  ss.hooks.push({type:"command",command:"node "+p.join(h,".claude","scripts","sync-memory.js").replace(/\\/g,"\\\\"),shell:"powershell"});
  console.log("✅ SessionStart: +sync-memory (مزامنة تلقائية)\n");
}else{console.log("∎ sync-memory already in SessionStart\n")}

// ============================================
// 4. إضافة بناء PROJECT_CONTEXT تلقائي
// ============================================
const buildContextCmd='node -e "const{execSync}=require(\'child_process\');const fs=require(\'fs\');const ctxFile=\'PROJECT_CONTEXT.md\';if(!fs.existsSync(ctxFile)){console.log(\'🏗️ بناء سياق المشروع...\');try{execSync(\'claude --print \\\'قم بتحليل هذا المشروع واكتب ملخصاً شاملاً في نقاط: 1)الهدف 2)التقنيات 3)الهيكل 4)القواعد المهمة. اكتب النتيجة في ملف PROJECT_CONTEXT.md\\\' \',{timeout:30000,cwd:process.cwd()});console.log(\'✅ تم بناء سياق المشروع\')}catch(e){console.log(\'⚠️ تخطي — استخدم /project-context يدوياً\')}}else{console.log(\'✅ PROJECT_CONTEXT موجود\')}"';

if(![...curHooks].some(c=>c.includes("PROJECT_CONTEXT"))){
  ss.hooks.push({type:"command",command:buildContextCmd,shell:"powershell"});
  console.log("✅ SessionStart: +auto-build PROJECT_CONTEXT\n");
}else{console.log("∎ PROJECT_CONTEXT check already in SessionStart\n")}

// ============================================
// 5. كتابة الملف
// ============================================
fs.writeFileSync(f,JSON.stringify(j,null,2)+"\n","utf8");

// Final summary
const allCounts=Object.keys(j.hooks).reduce((a,k)=>{const hks=j.hooks[k];return a+(Array.isArray(hks)?hks.reduce((s,e)=>s+(e.hooks?e.hooks.length:0),0):0)},0);
console.log("───────────────────────────────");
console.log("✅ اكتمل التوصيل:");
console.log("   MCP: "+j.enabledMcpjsonServers.length+" خوادم مفعلة");
console.log("   SessionStart: "+ss.hooks.length+" هوكات");
console.log("   مجموع الهوكات: "+allCounts);
console.log("   cleanupPeriodDays: "+j.cleanupPeriodDays);
console.log("   autoDream: "+j.autoDreamEnabled);
console.log("───────────────────────────────");

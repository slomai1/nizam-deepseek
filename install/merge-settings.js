#!/usr/bin/env node
// دمج settings.template.json مع settings.json الحالي (إن وُجد) — يبقي ملحقات المستخدم
// الاستخدام:
//   node merge-settings.js --template <path> --target <path> [--shell <name>] [--dry-run]

const fs = require("fs");

function parseArgs(argv) {
  const a = {};
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k.startsWith("--")) {
      const name = k.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        a[name] = next;
        i++;
      } else a[name] = true;
    }
  }
  return a;
}

const args = parseArgs(process.argv);
const templatePath = args.template;
const targetPath = args.target;
const shell = args.shell || "bash";
const dryRun = !!args["dry-run"];

if (!templatePath || !targetPath) {
  console.error("يجب تمرير --template و --target");
  process.exit(1);
}

const template = JSON.parse(fs.readFileSync(templatePath, "utf8"));
const existing = fs.existsSync(targetPath)
  ? JSON.parse(fs.readFileSync(targetPath, "utf8"))
  : {};

function merge(obj, base) {
  const out = { ...base };
  for (const [k, v] of Object.entries(obj)) {
    // لا نوسّع صلاحيات مستخدم قائم أبداً — قائمته تبقى كما هي
    if (k === "permissions" && base.permissions) {
      continue;
    }
    if (v && typeof v === "object" && !Array.isArray(v)) {
      out[k] = merge(v, base[k] && typeof base[k] === "object" ? base[k] : {});
    } else if (Array.isArray(v)) {
      // اتحاد مع الحفاظ على ترتيب القالب وإبقاء ما لدى المستخدم
      const set = new Set(v);
      if (Array.isArray(base[k])) base[k].forEach((x) => set.add(x));
      out[k] = [...set];
    } else {
      out[k] = v;
    }
  }
  return out;
}

const merged = merge(template, existing);

// defaultShell حسب النظام (يأتي من سكربت التركيب)
if (shell) merged.defaultShell = shell;

const json = JSON.stringify(merged, null, 2) + "\n";

if (dryRun) {
  console.log("[معاينة] سيكتب settings.json مع:");
  console.log("  - env: ANTHROPIC_BASE_URL = " + merged.env.ANTHROPIC_BASE_URL);
  console.log("  - defaultShell = " + merged.defaultShell);
  console.log(
    "  - hooks: " +
      (merged.hooks ? Object.keys(merged.hooks).length : 0) +
      " خطافات",
  );
  console.log(
    "  - enabledPlugins: " + Object.keys(merged.enabledPlugins || {}).length,
  );
  console.log(
    "  - marketplaces: " +
      Object.keys(merged.extraKnownMarketplaces || {}).length,
  );
} else {
  fs.writeFileSync(targetPath, json, "utf8");
  console.log("✓ كُتب " + targetPath);
}

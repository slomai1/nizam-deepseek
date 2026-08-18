-- مخطط قاعدة بيانات الذاكرة — نظام DeepSeek × Claude Code
-- يُنشئ قاعدة فارغة عبر: sqlite3 deepseek.db < schema.sql
-- أو عبر سكربت التركيب (يستخدم node:sqlite)

PRAGMA foreign_keys = ON;

-- الجلسات
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE,
    project TEXT,
    started_at TEXT DEFAULT (datetime('now')),
    ended_at TEXT,
    summary TEXT,
    files_changed INTEGER DEFAULT 0,
    decisions_count INTEGER DEFAULT 0,
    errors_count INTEGER DEFAULT 0
);

-- القرارات المعمارية
CREATE TABLE IF NOT EXISTS decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    description TEXT NOT NULL,
    rationale TEXT,
    alternatives TEXT,
    impact TEXT CHECK(impact IN ('low', 'medium', 'high', 'critical')),
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- تغييرات الملفات
CREATE TABLE IF NOT EXISTS file_changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    file_path TEXT NOT NULL,
    change_type TEXT CHECK(change_type IN ('create', 'modify', 'delete')),
    reason TEXT,
    timestamp TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- سجل الهلوسات
CREATE TABLE IF NOT EXISTS hallucinations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    pattern_type TEXT CHECK(pattern_type IN ('path', 'function', 'library', 'config', 'other')),
    hallucinated_value TEXT NOT NULL,
    correct_value TEXT,
    context TEXT,
    lesson TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- الذكريات (المصدر: ملفات Markdown في مجلدات الذاكرة)
-- التفرّد مركّب (name, project) لا name وحده: لكل مشروع مساحة أسماء
-- مستقلة، وإلا استولت مزامنة مشروع على سجل مشروع آخر يحمل نفس الاسم.
CREATE TABLE IF NOT EXISTS memories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    type TEXT CHECK(type IN ('user', 'feedback', 'project', 'reference', 'pattern', 'tool', 'session')),
    content TEXT NOT NULL,
    tags TEXT,
    related_memories TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    usage_count INTEGER DEFAULT 0,
    project TEXT DEFAULT NULL,
    importance TEXT DEFAULT 'long-term' CHECK(importance IN ('permanent','long-term','temporary','expires-soon')),
    trigger TEXT DEFAULT NULL,
    reason TEXT DEFAULT NULL,
    source TEXT DEFAULT NULL,
    status TEXT DEFAULT 'active' CHECK(status IN ('active','outdated','replaced'))
);

-- الطبقة العامة تحمل project = NULL، وSQLite يعتبر كل NULL مميّزاً في UNIQUE،
-- لذا نضيف فهرسين جزئيين: أحدهما للسجلات ذات المشروع والآخر للعامة.
CREATE UNIQUE INDEX IF NOT EXISTS idx_memories_scope
    ON memories(name, project) WHERE project IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_memories_scope_global
    ON memories(name) WHERE project IS NULL;

-- استخدام الأدوات
CREATE TABLE IF NOT EXISTS tool_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    tool_name TEXT NOT NULL,
    success INTEGER DEFAULT 1,
    duration_ms INTEGER,
    error_message TEXT,
    timestamp TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

-- الفهارس
CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project);
CREATE INDEX IF NOT EXISTS idx_memories_name ON memories(name);
CREATE INDEX IF NOT EXISTS idx_memories_type ON memories(type);
CREATE INDEX IF NOT EXISTS idx_hallucinations_pattern ON hallucinations(pattern_type);
CREATE INDEX IF NOT EXISTS idx_tool_usage_name ON tool_usage(tool_name);
CREATE INDEX IF NOT EXISTS idx_tool_usage_session ON tool_usage(session_id);

-- Views
CREATE VIEW IF NOT EXISTS v_recent_memories AS
    SELECT name, type, description, usage_count, updated_at
    FROM memories
    ORDER BY updated_at DESC
    LIMIT 20;

CREATE VIEW IF NOT EXISTS v_memories_by_project AS
    SELECT project, type, importance, status, COUNT(*) as count
    FROM memories
    WHERE project IS NOT NULL
    GROUP BY project, type, importance, status
    ORDER BY project, type;

CREATE VIEW IF NOT EXISTS v_memory_effectiveness AS
    SELECT name, type, importance, status, usage_count, updated_at, reason
    FROM memories
    WHERE status = 'active'
    ORDER BY usage_count DESC
    LIMIT 20;

CREATE VIEW IF NOT EXISTS v_stale_memories AS
    SELECT name, type, importance, status, updated_at, reason
    FROM memories
    WHERE status IN ('outdated', 'replaced')
       OR (importance = 'expires-soon' AND julianday('now') - julianday(updated_at) > 30)
    ORDER BY updated_at;

CREATE VIEW IF NOT EXISTS v_frequent_hallucinations AS
    SELECT pattern_type, hallucinated_value, COUNT(*) as count, lesson
    FROM hallucinations
    GROUP BY pattern_type, hallucinated_value
    HAVING count > 1
    ORDER BY count DESC;

CREATE VIEW IF NOT EXISTS v_session_stats AS
    SELECT
        s.project,
        COUNT(DISTINCT s.id) as total_sessions,
        SUM(s.files_changed) as total_files,
        SUM(s.errors_count) as total_errors,
        AVG(s.decisions_count) as avg_decisions
    FROM sessions s
    GROUP BY s.project;

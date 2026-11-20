CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL,
 password_hash TEXT NOT NULL, timezone TEXT NOT NULL DEFAULT 'UTC',
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS projects (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id), title TEXT NOT NULL,
 description TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS project_members (
 project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES users(id), role TEXT NOT NULL CHECK(role IN ('owner','admin','collaborator','viewer')),
 PRIMARY KEY(project_id,user_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS one_project_owner ON project_members(project_id) WHERE role='owner';
CREATE TABLE IF NOT EXISTS goals (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id),
 project_id TEXT REFERENCES projects(id) ON DELETE CASCADE, title TEXT NOT NULL,
 description TEXT NOT NULL DEFAULT '', start_date TEXT, target_date TEXT,
 status TEXT NOT NULL CHECK(status IN ('active','completed','archived')),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS milestones (
 id TEXT PRIMARY KEY, goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
 title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', target_date TEXT,
 position INTEGER NOT NULL, completed BOOLEAN NOT NULL DEFAULT FALSE
);
-- Minimal task integration records for linked work; task editing remains Moetaz's UI.
CREATE TABLE IF NOT EXISTS tasks (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id),
 project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
 milestone_id TEXT REFERENCES milestones(id) ON DELETE SET NULL,
 title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
 status TEXT NOT NULL DEFAULT 'todo' CHECK(status IN ('todo','in_progress','blocked','completed','archived','cancelled')),
 estimated_minutes INTEGER NOT NULL CHECK(estimated_minutes > 0 AND estimated_minutes <= 1440),
 deadline TEXT, priority TEXT NOT NULL DEFAULT 'medium' CHECK(priority IN ('low','medium','high','urgent')),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS goal_tasks (
 goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
 task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
 PRIMARY KEY(goal_id,task_id)
);
CREATE TABLE IF NOT EXISTS task_assignments (
 task_id TEXT PRIMARY KEY REFERENCES tasks(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES users(id), assigned_by TEXT NOT NULL REFERENCES users(id), assigned_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS invitations (
 id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
 email TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('admin','collaborator','viewer')),
 token_hash TEXT UNIQUE NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','accepted','rejected','revoked')),
 invited_by TEXT NOT NULL REFERENCES users(id), expires_at TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS invitation_pending ON invitations(project_id,email) WHERE status='pending';
CREATE TABLE IF NOT EXISTS comments (
 id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
 author_id TEXT NOT NULL REFERENCES users(id), body TEXT NOT NULL, mentions JSONB NOT NULL DEFAULT '[]',
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS activity (
 id TEXT PRIMARY KEY, project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
 actor_id TEXT NOT NULL REFERENCES users(id), kind TEXT NOT NULL, message TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS conversations (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id),
 goal_id TEXT REFERENCES goals(id) ON DELETE SET NULL, project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
 title TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS messages (
 id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
 role TEXT NOT NULL CHECK(role IN ('user','assistant')), body TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS proposals (
 id TEXT PRIMARY KEY, conversation_id TEXT REFERENCES conversations(id) ON DELETE SET NULL,
 owner_id TEXT NOT NULL REFERENCES users(id), goal_id TEXT REFERENCES goals(id) ON DELETE SET NULL,
 title TEXT NOT NULL, explanation TEXT NOT NULL, actions JSONB NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('pending','executed','rejected','failed')),
 result JSONB, error TEXT, created_at TEXT NOT NULL, expires_at TEXT NOT NULL,
 resolved_at TEXT, revision INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS agent_audit (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id), proposal_id TEXT REFERENCES proposals(id) ON DELETE CASCADE,
 event TEXT NOT NULL, details TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS productivity_events (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
 kind TEXT NOT NULL CHECK(kind IN ('task_completed','goal_completed','focus_completed','plan_approved')),
 entity_id TEXT NOT NULL, occurred_at TEXT NOT NULL,
 UNIQUE(user_id,kind,entity_id)
);
CREATE TABLE IF NOT EXISTS user_challenges (
 user_id TEXT NOT NULL REFERENCES users(id), challenge_id TEXT NOT NULL,
 joined_at TEXT NOT NULL, expires_at TEXT NOT NULL, completed_at TEXT,
 PRIMARY KEY(user_id,challenge_id)
);
CREATE INDEX IF NOT EXISTS goals_owner ON goals(owner_id,updated_at);
CREATE INDEX IF NOT EXISTS tasks_owner ON tasks(owner_id,updated_at);
CREATE INDEX IF NOT EXISTS comments_project ON comments(project_id,created_at);
CREATE INDEX IF NOT EXISTS activity_project ON activity(project_id,created_at);
CREATE INDEX IF NOT EXISTS conversations_owner ON conversations(owner_id,updated_at);
CREATE INDEX IF NOT EXISTS proposals_owner ON proposals(owner_id,created_at);

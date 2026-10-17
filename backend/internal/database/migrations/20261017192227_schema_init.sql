-- migrate:up

CREATE SEQUENCE IF NOT EXISTS sync_version
    AS BIGINT
    START WITH 1
    INCREMENT BY 1;
  
CREATE TYPE "user_role" AS ENUM (
  'user',
  'admin');

CREATE TYPE "platform" AS ENUM (
  'android',
  'ios',
  'web',
  'linux',
  'windows'
);

CREATE TYPE "session_kind" AS ENUM (
  'device',
  'api_key'
);

CREATE TYPE "time_entry_stop_reason" AS ENUM (
  'manual',
  'task_switch',
  'task_completed',
  'idle_timeout',
  'session_ended',
  'auto_stop',
  'detection',
  'phase_complete'
);

CREATE TYPE "detection_action" AS ENUM (
  'start',
  'stop'
);

CREATE TYPE "activity_status" AS ENUM (
  'walking',
  'stationary'
);

CREATE TYPE "entry_kind" AS ENUM (
  'work',
  'break'
);

CREATE TYPE "idle_action" AS ENUM (
  'prompt',
  'pause'
);

CREATE TYPE "parallel_timer_action" AS ENUM (
  'ask',
  'run_both',
  'pause_others'
);

CREATE TYPE "member_role" AS ENUM (
  'owner',
  'member'
);

CREATE TABLE "users" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "username" varchar UNIQUE NOT NULL,
  "display_name" varchar NOT NULL,
  "password_hash" varchar,
  "role" user_role NOT NULL DEFAULT 'user',
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "login_sessions" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_agent" varchar NOT NULL,
  "user_id" uuid NOT NULL,
  "kind" session_kind NOT NULL,
  "token_hash" varchar UNIQUE NOT NULL,
  "platform" platform NOT NULL,
  "app_version" varchar,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "last_used_at" timestamptz NOT NULL DEFAULT (now()),
  "expires_at" timestamptz NOT NULL,
  "revoked_at" timestamptz,
  "push_topic" varchar
);

CREATE TABLE "projects" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "name" varchar NOT NULL,
  "is_todo" boolean NOT NULL DEFAULT false,
  "is_private" boolean NOT NULL DEFAULT true,
  "priority" integer NOT NULL DEFAULT 0,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz
);

CREATE TABLE "tasks" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "project_id" uuid NOT NULL,
  "name" varchar NOT NULL,
  "priority" integer NOT NULL DEFAULT 0,
  "completed_at" timestamptz,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz
);

CREATE TABLE "labels" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "name" varchar NOT NULL,
  "color" varchar,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz,
  CONSTRAINT "labels_color_hex" CHECK (color IS NULL OR color ~ '^#[0-9A-Fa-f]{6}$')
);

CREATE TABLE "task_labels" (
  "task_id" uuid NOT NULL,
  "label_id" uuid NOT NULL,
  PRIMARY KEY ("task_id", "label_id")
);

CREATE TABLE "time_blocking_templates" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "name" varchar NOT NULL,
  "phases" jsonb NOT NULL,
  "repeat_count" integer,
  "default_project_id" uuid,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz,
  CONSTRAINT "templates_phases_not_empty" CHECK (jsonb_typeof(phases) = 'array' AND jsonb_array_length(phases) >= 1),
  CONSTRAINT "templates_repeat_positive" CHECK (repeat_count IS NULL OR repeat_count >= 1)
);

CREATE TABLE "work_sessions" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "project_id" uuid NOT NULL,
  "started_at" timestamptz NOT NULL,
  "planned_end_at" timestamptz,
  "ended_at" timestamptz,
  "needs_review" boolean NOT NULL DEFAULT false,
  "time_blocking_template_id" uuid,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz,
  CONSTRAINT "sessions_end_after_start" CHECK (ended_at IS NULL OR ended_at > started_at)
);

CREATE TABLE "time_entries" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "session_id" uuid NOT NULL,
  "project_id" uuid NOT NULL,
  "task_id" uuid,
  "kind" entry_kind NOT NULL DEFAULT 'work',
  "started_at" timestamptz NOT NULL,
  "ended_at" timestamptz,
  "idle_stop_time" timestamptz,
  "needs_review" boolean NOT NULL DEFAULT false,
  "stop_reason" time_entry_stop_reason,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz,
  CONSTRAINT "time_entries_end_after_start" CHECK (ended_at IS NULL OR ended_at > started_at),
  CONSTRAINT "time_entries_idle_after_start" CHECK (idle_stop_time IS NULL OR idle_stop_time >= started_at),
  CONSTRAINT "time_entries_stop_reason_when_stopped" CHECK ((ended_at IS NULL) = (stop_reason IS NULL))
);

CREATE TABLE "locations" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "address_name" varchar NOT NULL,
  "coordinates" point NOT NULL,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz,
  CONSTRAINT "locations_valid_coordinates" CHECK (coordinates[0] BETWEEN -180 AND 180 AND coordinates[1] BETWEEN -90 AND 90)
);

CREATE TABLE "detection_rules" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "user_id" uuid NOT NULL,
  "action" detection_action NOT NULL,
  "project_id" uuid NOT NULL,
  "task_id" uuid,
  "is_enabled" boolean NOT NULL DEFAULT true,
  "min_speed" real,
  "wifi" boolean,
  "wifi_ssid" varchar,
  "location_id" uuid,
  "radius_meter" integer,
  "activity_status" activity_status,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz,
  CONSTRAINT "detection_rules_has_condition" CHECK (num_nonnulls(min_speed, wifi, wifi_ssid, location_id, activity_status) >= 1),
  CONSTRAINT "detection_rules_location_radius" CHECK ((radius_meter IS NULL) = (location_id IS NULL)),
  CONSTRAINT "detection_rules_ssid_needs_wifi" CHECK (NOT (wifi = false AND wifi_ssid IS NOT NULL)),
  CONSTRAINT "detection_rules_speed_positive" CHECK (min_speed IS NULL OR min_speed >= 0),
  CONSTRAINT "detection_rules_radius_positive" CHECK (radius_meter IS NULL OR radius_meter >= 1)
);

CREATE TABLE "user_settings" (
  "user_id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "timezone" varchar NOT NULL DEFAULT 'UTC',
  "week_start" integer NOT NULL DEFAULT 6,
  "language" varchar NOT NULL DEFAULT 'en',
  "parallel_timer_action" parallel_timer_action NOT NULL DEFAULT 'ask',
  "detection_parallel_timer_action" parallel_timer_action NOT NULL DEFAULT 'run_both',
  "long_timer_reminder_minutes" integer DEFAULT 180,
  "idle_threshold_minutes" integer,
  "idle_action" idle_action NOT NULL DEFAULT 'prompt',
  "auto_stop_after_minutes" integer,
  "not_tracking_reminder" boolean NOT NULL DEFAULT true,
  "active_hours_start" integer DEFAULT 540,
  "active_hours_end" integer DEFAULT 1020,
  "active_days" integer NOT NULL DEFAULT 79,
  "auto_start_breaks" boolean NOT NULL DEFAULT true,
  "auto_start_next_work" boolean NOT NULL DEFAULT false,
  "notify_phase_end" boolean NOT NULL DEFAULT true,
  "quiet_hours_start" integer,
  "quiet_hours_end" integer,
  "share_running_timer" boolean NOT NULL DEFAULT false,
  "client_prefs" jsonb,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "settings_week_start" CHECK (week_start BETWEEN 0 AND 6),
  CONSTRAINT "settings_active_days" CHECK (active_days BETWEEN 0 AND 127),
  CONSTRAINT "settings_active_start" CHECK (active_hours_start IS NULL OR active_hours_start BETWEEN 0 AND 1439),
  CONSTRAINT "settings_active_end" CHECK (active_hours_end IS NULL OR active_hours_end BETWEEN 0 AND 1439),
  CONSTRAINT "settings_quiet_start" CHECK (quiet_hours_start IS NULL OR quiet_hours_start BETWEEN 0 AND 1439),
  CONSTRAINT "settings_quiet_end" CHECK (quiet_hours_end IS NULL OR quiet_hours_end BETWEEN 0 AND 1439),
  CONSTRAINT "settings_quiet_pair" CHECK ((quiet_hours_start IS NULL) = (quiet_hours_end IS NULL)),
  CONSTRAINT "settings_long_timer_positive" CHECK (long_timer_reminder_minutes IS NULL OR long_timer_reminder_minutes >= 1),
  CONSTRAINT "settings_idle_positive" CHECK (idle_threshold_minutes IS NULL OR idle_threshold_minutes >= 1),
  CONSTRAINT "settings_auto_stop_positive" CHECK (auto_stop_after_minutes IS NULL OR auto_stop_after_minutes >= 1)
);

CREATE TABLE "groups" (
  "id" uuid PRIMARY KEY DEFAULT uuidv7(),
  "name" varchar NOT NULL,
  "invite_code" varchar UNIQUE NOT NULL,
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz
);

CREATE TABLE "group_members" (
  "group_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "role" member_role NOT NULL DEFAULT 'member',
  "joined_at" timestamptz NOT NULL DEFAULT (now()),
  "server_version" bigint NOT NULL DEFAULT (nextval('sync_version')),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz,
  PRIMARY KEY ("group_id", "user_id")
);

CREATE INDEX "login_sessions_by_user" ON "login_sessions" ("user_id");

CREATE INDEX "projects_sync" ON "projects" ("user_id", "server_version");

CREATE INDEX "tasks_sync" ON "tasks" ("user_id", "server_version");

CREATE UNIQUE INDEX "tasks_id_project" ON "tasks" ("id", "project_id");

CREATE INDEX "labels_sync" ON "labels" ("user_id", "server_version");

CREATE INDEX "task_labels_by_label" ON "task_labels" ("label_id");

CREATE INDEX "time_blocking_templates_sync" ON "time_blocking_templates" ("user_id", "server_version");

CREATE INDEX "sessions_sync" ON "work_sessions" ("user_id", "server_version");

CREATE INDEX "sessions_by_date" ON "work_sessions" ("user_id", "started_at");

CREATE UNIQUE INDEX "sessions_id_project" ON "work_sessions" ("id", "project_id");

CREATE INDEX "time_entries_sync" ON "time_entries" ("user_id", "server_version");

CREATE INDEX "time_entries_by_date" ON "time_entries" ("user_id", "started_at");

CREATE INDEX "time_entries_by_session" ON "time_entries" ("session_id");

CREATE INDEX "locations_sync" ON "locations" ("user_id", "server_version");

CREATE INDEX "detection_rules_sync" ON "detection_rules" ("user_id", "server_version");

CREATE INDEX "detection_rules_by_location" ON "detection_rules" ("location_id");

CREATE INDEX "user_settings_sync" ON "user_settings" ("server_version");

CREATE INDEX "groups_sync" ON "groups" ("server_version");

CREATE INDEX "group_members_sync" ON "group_members" ("user_id", "server_version");


ALTER TABLE "login_sessions" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "projects" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "tasks" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "tasks" ADD FOREIGN KEY ("project_id") REFERENCES "projects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "labels" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "task_labels" ADD FOREIGN KEY ("task_id") REFERENCES "tasks" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "task_labels" ADD FOREIGN KEY ("label_id") REFERENCES "labels" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "time_blocking_templates" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "time_blocking_templates" ADD FOREIGN KEY ("default_project_id") REFERENCES "projects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "work_sessions" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "work_sessions" ADD FOREIGN KEY ("project_id") REFERENCES "projects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "work_sessions" ADD FOREIGN KEY ("time_blocking_template_id") REFERENCES "time_blocking_templates" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "time_entries" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "time_entries" ADD CONSTRAINT "time_entries_session" FOREIGN KEY ("session_id", "project_id") REFERENCES "work_sessions" ("id", "project_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "time_entries" ADD CONSTRAINT "time_entries_task" FOREIGN KEY ("task_id", "project_id") REFERENCES "tasks" ("id", "project_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "locations" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "detection_rules" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "detection_rules" ADD FOREIGN KEY ("project_id") REFERENCES "projects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "detection_rules" ADD FOREIGN KEY ("location_id") REFERENCES "locations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "detection_rules" ADD CONSTRAINT "detection_rules_task" FOREIGN KEY ("task_id", "project_id") REFERENCES "tasks" ("id", "project_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "user_settings" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "group_members" ADD FOREIGN KEY ("group_id") REFERENCES "groups" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "group_members" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;
-- migrate:down
DROP TABLE IF EXISTS "group_members";
DROP TABLE IF EXISTS "user_settings";
DROP TABLE IF EXISTS "detection_rules";
DROP TABLE IF EXISTS "time_entries";
DROP TABLE IF EXISTS "work_sessions";
DROP TABLE IF EXISTS "task_labels";
DROP TABLE IF EXISTS "tasks";
DROP TABLE IF EXISTS "labels";
DROP TABLE IF EXISTS "time_blocking_templates";
DROP TABLE IF EXISTS "locations";
DROP TABLE IF EXISTS "projects";
DROP TABLE IF EXISTS "login_sessions";
DROP TABLE IF EXISTS "groups";
DROP TABLE IF EXISTS "users";

DROP TYPE IF EXISTS "member_role";
DROP TYPE IF EXISTS "parallel_timer_action";
DROP TYPE IF EXISTS "idle_action";
DROP TYPE IF EXISTS "entry_kind";
DROP TYPE IF EXISTS "activity_status";
DROP TYPE IF EXISTS "detection_action";
DROP TYPE IF EXISTS "time_entry_stop_reason";
DROP TYPE IF EXISTS "session_kind";
DROP TYPE IF EXISTS "platform";
DROP TYPE IF EXISTS "user_role";

DROP SEQUENCE IF EXISTS sync_version;

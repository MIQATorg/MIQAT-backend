\restrict dbmate

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: activity_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.activity_status AS ENUM (
    'walking',
    'stationary'
);


--
-- Name: detection_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.detection_action AS ENUM (
    'start',
    'stop'
);


--
-- Name: entry_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entry_kind AS ENUM (
    'work',
    'break'
);


--
-- Name: idle_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.idle_action AS ENUM (
    'prompt',
    'pause'
);


--
-- Name: member_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.member_role AS ENUM (
    'owner',
    'member'
);


--
-- Name: parallel_timer_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.parallel_timer_action AS ENUM (
    'ask',
    'run_both',
    'pause_others'
);


--
-- Name: platform; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.platform AS ENUM (
    'android',
    'ios',
    'web',
    'linux',
    'windows'
);


--
-- Name: session_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.session_kind AS ENUM (
    'device',
    'api_key'
);


--
-- Name: time_entry_stop_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.time_entry_stop_reason AS ENUM (
    'manual',
    'task_switch',
    'task_completed',
    'idle_timeout',
    'session_ended',
    'auto_stop',
    'detection',
    'phase_complete'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'user',
    'admin'
);


--
-- Name: sync_version; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sync_version
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: detection_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detection_rules (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    action public.detection_action NOT NULL,
    project_id uuid NOT NULL,
    task_id uuid,
    is_enabled boolean DEFAULT true NOT NULL,
    min_speed real,
    wifi boolean,
    wifi_ssid character varying,
    location_id uuid,
    radius_meter integer,
    activity_status public.activity_status,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT detection_rules_has_condition CHECK ((num_nonnulls(min_speed, wifi, wifi_ssid, location_id, activity_status) >= 1)),
    CONSTRAINT detection_rules_location_radius CHECK (((radius_meter IS NULL) = (location_id IS NULL))),
    CONSTRAINT detection_rules_radius_positive CHECK (((radius_meter IS NULL) OR (radius_meter >= 1))),
    CONSTRAINT detection_rules_speed_positive CHECK (((min_speed IS NULL) OR (min_speed >= (0)::double precision))),
    CONSTRAINT detection_rules_ssid_needs_wifi CHECK ((NOT ((wifi = false) AND (wifi_ssid IS NOT NULL))))
);


--
-- Name: group_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_members (
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role public.member_role DEFAULT 'member'::public.member_role NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying NOT NULL,
    invite_code character varying NOT NULL,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.labels (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    name character varying NOT NULL,
    color character varying,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT labels_color_hex CHECK (((color IS NULL) OR ((color)::text ~ '^#[0-9A-Fa-f]{6}$'::text)))
);


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    address_name character varying NOT NULL,
    coordinates point NOT NULL,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT locations_valid_coordinates CHECK ((((coordinates[0] >= ('-180'::integer)::double precision) AND (coordinates[0] <= (180)::double precision)) AND ((coordinates[1] >= ('-90'::integer)::double precision) AND (coordinates[1] <= (90)::double precision))))
);


--
-- Name: login_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_agent character varying NOT NULL,
    user_id uuid NOT NULL,
    kind public.session_kind NOT NULL,
    token_hash character varying NOT NULL,
    platform public.platform NOT NULL,
    app_version character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    push_topic character varying
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    name character varying NOT NULL,
    is_todo boolean DEFAULT false NOT NULL,
    is_private boolean DEFAULT true NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: task_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_labels (
    task_id uuid NOT NULL,
    label_id uuid NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    completed_at timestamp with time zone,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: time_blocking_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.time_blocking_templates (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    name character varying NOT NULL,
    phases jsonb NOT NULL,
    repeat_count integer,
    default_project_id uuid,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT templates_phases_not_empty CHECK (((jsonb_typeof(phases) = 'array'::text) AND (jsonb_array_length(phases) >= 1))),
    CONSTRAINT templates_repeat_positive CHECK (((repeat_count IS NULL) OR (repeat_count >= 1)))
);


--
-- Name: time_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.time_entries (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    session_id uuid NOT NULL,
    project_id uuid NOT NULL,
    task_id uuid,
    kind public.entry_kind DEFAULT 'work'::public.entry_kind NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone,
    idle_stop_time timestamp with time zone,
    needs_review boolean DEFAULT false NOT NULL,
    stop_reason public.time_entry_stop_reason,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT time_entries_end_after_start CHECK (((ended_at IS NULL) OR (ended_at > started_at))),
    CONSTRAINT time_entries_idle_after_start CHECK (((idle_stop_time IS NULL) OR (idle_stop_time >= started_at))),
    CONSTRAINT time_entries_stop_reason_when_stopped CHECK (((ended_at IS NULL) = (stop_reason IS NULL)))
);


--
-- Name: user_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_settings (
    user_id uuid NOT NULL,
    timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    week_start integer DEFAULT 6 NOT NULL,
    language character varying DEFAULT 'en'::character varying NOT NULL,
    parallel_timer_action public.parallel_timer_action DEFAULT 'ask'::public.parallel_timer_action NOT NULL,
    detection_parallel_timer_action public.parallel_timer_action DEFAULT 'run_both'::public.parallel_timer_action NOT NULL,
    long_timer_reminder_minutes integer DEFAULT 180,
    idle_threshold_minutes integer DEFAULT 15,
    idle_action public.idle_action DEFAULT 'prompt'::public.idle_action NOT NULL,
    auto_stop_after_minutes integer,
    not_tracking_reminder boolean DEFAULT true NOT NULL,
    active_hours_start integer DEFAULT 540,
    active_hours_end integer DEFAULT 1020,
    active_days integer DEFAULT 79 NOT NULL,
    auto_start_breaks boolean DEFAULT true NOT NULL,
    auto_start_next_work boolean DEFAULT false NOT NULL,
    notify_phase_end boolean DEFAULT true NOT NULL,
    quiet_hours_start integer,
    quiet_hours_end integer,
    share_running_timer boolean DEFAULT false NOT NULL,
    client_prefs jsonb,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT settings_active_days CHECK (((active_days >= 0) AND (active_days <= 127))),
    CONSTRAINT settings_active_end CHECK (((active_hours_end IS NULL) OR ((active_hours_end >= 0) AND (active_hours_end <= 1439)))),
    CONSTRAINT settings_active_start CHECK (((active_hours_start IS NULL) OR ((active_hours_start >= 0) AND (active_hours_start <= 1439)))),
    CONSTRAINT settings_auto_stop_positive CHECK (((auto_stop_after_minutes IS NULL) OR (auto_stop_after_minutes >= 1))),
    CONSTRAINT settings_idle_positive CHECK (((idle_threshold_minutes IS NULL) OR (idle_threshold_minutes >= 1))),
    CONSTRAINT settings_long_timer_positive CHECK (((long_timer_reminder_minutes IS NULL) OR (long_timer_reminder_minutes >= 1))),
    CONSTRAINT settings_quiet_end CHECK (((quiet_hours_end IS NULL) OR ((quiet_hours_end >= 0) AND (quiet_hours_end <= 1439)))),
    CONSTRAINT settings_quiet_pair CHECK (((quiet_hours_start IS NULL) = (quiet_hours_end IS NULL))),
    CONSTRAINT settings_quiet_start CHECK (((quiet_hours_start IS NULL) OR ((quiet_hours_start >= 0) AND (quiet_hours_start <= 1439)))),
    CONSTRAINT settings_week_start CHECK (((week_start >= 0) AND (week_start <= 6)))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT uuidv7() NOT NULL,
    username character varying(30) NOT NULL,
    display_name character varying NOT NULL,
    password_hash character varying,
    role public.user_role DEFAULT 'user'::public.user_role NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_english_only CHECK ((((username)::text ~ '^[A-Za-z0-9_.-]*$'::text) AND ((display_name)::text ~ '^[A-Za-z0-9_ .-]*$'::text)))
);


--
-- Name: work_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    project_id uuid NOT NULL,
    started_at timestamp with time zone NOT NULL,
    planned_end_at timestamp with time zone,
    ended_at timestamp with time zone,
    needs_review boolean DEFAULT false NOT NULL,
    time_blocking_template_id uuid,
    server_version bigint DEFAULT nextval('public.sync_version'::regclass) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT sessions_end_after_start CHECK (((ended_at IS NULL) OR (ended_at > started_at)))
);


--
-- Name: detection_rules detection_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_rules
    ADD CONSTRAINT detection_rules_pkey PRIMARY KEY (id);


--
-- Name: group_members group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_pkey PRIMARY KEY (group_id, user_id);


--
-- Name: groups groups_invite_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_invite_code_key UNIQUE (invite_code);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: labels labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.labels
    ADD CONSTRAINT labels_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: login_sessions login_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_sessions
    ADD CONSTRAINT login_sessions_pkey PRIMARY KEY (id);


--
-- Name: login_sessions login_sessions_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_sessions
    ADD CONSTRAINT login_sessions_token_hash_key UNIQUE (token_hash);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: task_labels task_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_labels
    ADD CONSTRAINT task_labels_pkey PRIMARY KEY (task_id, label_id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: time_blocking_templates time_blocking_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_blocking_templates
    ADD CONSTRAINT time_blocking_templates_pkey PRIMARY KEY (id);


--
-- Name: time_entries time_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries
    ADD CONSTRAINT time_entries_pkey PRIMARY KEY (id);


--
-- Name: user_settings user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_pkey PRIMARY KEY (user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: work_sessions work_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_sessions
    ADD CONSTRAINT work_sessions_pkey PRIMARY KEY (id);


--
-- Name: detection_rules_by_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX detection_rules_by_location ON public.detection_rules USING btree (location_id);


--
-- Name: detection_rules_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX detection_rules_sync ON public.detection_rules USING btree (user_id, server_version);


--
-- Name: group_members_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_members_sync ON public.group_members USING btree (user_id, server_version);


--
-- Name: groups_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX groups_sync ON public.groups USING btree (server_version);


--
-- Name: labels_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX labels_sync ON public.labels USING btree (user_id, server_version);


--
-- Name: locations_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_sync ON public.locations USING btree (user_id, server_version);


--
-- Name: login_sessions_by_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX login_sessions_by_user ON public.login_sessions USING btree (user_id);


--
-- Name: projects_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_sync ON public.projects USING btree (user_id, server_version);


--
-- Name: sessions_by_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_by_date ON public.work_sessions USING btree (user_id, started_at);


--
-- Name: sessions_id_project; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sessions_id_project ON public.work_sessions USING btree (id, project_id);


--
-- Name: sessions_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_sync ON public.work_sessions USING btree (user_id, server_version);


--
-- Name: task_labels_by_label; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_labels_by_label ON public.task_labels USING btree (label_id);


--
-- Name: tasks_id_project; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tasks_id_project ON public.tasks USING btree (id, project_id);


--
-- Name: tasks_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_sync ON public.tasks USING btree (user_id, server_version);


--
-- Name: time_blocking_templates_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX time_blocking_templates_sync ON public.time_blocking_templates USING btree (user_id, server_version);


--
-- Name: time_entries_by_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX time_entries_by_date ON public.time_entries USING btree (user_id, started_at);


--
-- Name: time_entries_by_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX time_entries_by_session ON public.time_entries USING btree (session_id);


--
-- Name: time_entries_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX time_entries_sync ON public.time_entries USING btree (user_id, server_version);


--
-- Name: user_settings_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_settings_sync ON public.user_settings USING btree (server_version);


--
-- Name: detection_rules detection_rules_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_rules
    ADD CONSTRAINT detection_rules_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) DEFERRABLE;


--
-- Name: detection_rules detection_rules_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_rules
    ADD CONSTRAINT detection_rules_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) DEFERRABLE;


--
-- Name: detection_rules detection_rules_task; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_rules
    ADD CONSTRAINT detection_rules_task FOREIGN KEY (task_id, project_id) REFERENCES public.tasks(id, project_id) DEFERRABLE;


--
-- Name: detection_rules detection_rules_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_rules
    ADD CONSTRAINT detection_rules_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: group_members group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) DEFERRABLE;


--
-- Name: group_members group_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: labels labels_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.labels
    ADD CONSTRAINT labels_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: locations locations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: login_sessions login_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_sessions
    ADD CONSTRAINT login_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: projects projects_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: task_labels task_labels_label_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_labels
    ADD CONSTRAINT task_labels_label_id_fkey FOREIGN KEY (label_id) REFERENCES public.labels(id) DEFERRABLE;


--
-- Name: task_labels task_labels_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_labels
    ADD CONSTRAINT task_labels_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) DEFERRABLE;


--
-- Name: tasks tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) DEFERRABLE;


--
-- Name: tasks tasks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: time_blocking_templates time_blocking_templates_default_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_blocking_templates
    ADD CONSTRAINT time_blocking_templates_default_project_id_fkey FOREIGN KEY (default_project_id) REFERENCES public.projects(id) DEFERRABLE;


--
-- Name: time_blocking_templates time_blocking_templates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_blocking_templates
    ADD CONSTRAINT time_blocking_templates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: time_entries time_entries_session; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries
    ADD CONSTRAINT time_entries_session FOREIGN KEY (session_id, project_id) REFERENCES public.work_sessions(id, project_id) DEFERRABLE;


--
-- Name: time_entries time_entries_task; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries
    ADD CONSTRAINT time_entries_task FOREIGN KEY (task_id, project_id) REFERENCES public.tasks(id, project_id) DEFERRABLE;


--
-- Name: time_entries time_entries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_entries
    ADD CONSTRAINT time_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: user_settings user_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: work_sessions work_sessions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_sessions
    ADD CONSTRAINT work_sessions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) DEFERRABLE;


--
-- Name: work_sessions work_sessions_time_blocking_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_sessions
    ADD CONSTRAINT work_sessions_time_blocking_template_id_fkey FOREIGN KEY (time_blocking_template_id) REFERENCES public.time_blocking_templates(id) DEFERRABLE;


--
-- Name: work_sessions work_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_sessions
    ADD CONSTRAINT work_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20261017192227');

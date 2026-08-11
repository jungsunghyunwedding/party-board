-- 파티 보드 Supabase 스키마 v2 (재실행해도 안전)
-- Supabase Dashboard → SQL Editor 에서 전체 실행

-- 1) 보드 상태 + version
CREATE TABLE IF NOT EXISTS party_board_state (
  board_key  TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{"parties":[],"nominations":[],"partyCounter":0}'::jsonb,
  version    BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE party_board_state
  ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;

INSERT INTO party_board_state (board_key, value, version)
VALUES (
  'party-board-state-v2',
  '{"parties":[],"nominations":[],"partyCounter":0}'::jsonb,
  0
)
ON CONFLICT (board_key) DO NOTHING;

ALTER TABLE party_board_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public read party board" ON party_board_state;
DROP POLICY IF EXISTS "public insert party board" ON party_board_state;
DROP POLICY IF EXISTS "public update party board" ON party_board_state;

CREATE POLICY "public read party board"
  ON party_board_state FOR SELECT USING (true);
CREATE POLICY "public insert party board"
  ON party_board_state FOR INSERT WITH CHECK (true);
CREATE POLICY "public update party board"
  ON party_board_state FOR UPDATE USING (true) WITH CHECK (true);

-- 2) 공유 입장 비밀번호 (SHA-256 hex)
-- 기본 비밀번호: party
-- SHA-256("party") = 1d0fea39ec33ff7543f345be85d1ccd34d6d864297d4151b737802cb294a338c
CREATE TABLE IF NOT EXISTS app_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO app_settings (key, value)
VALUES (
  'room_password_hash',
  '1d0fea39ec33ff7543f345be85d1ccd34d6d864297d4151b737802cb294a338c'
)
ON CONFLICT (key) DO NOTHING;

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public read app settings" ON app_settings;
CREATE POLICY "public read app settings"
  ON app_settings FOR SELECT USING (true);

-- 3) 접속자 presence
CREATE TABLE IF NOT EXISTS presence (
  client_id  TEXT PRIMARY KEY,
  nickname   TEXT NOT NULL,
  class      TEXT NOT NULL DEFAULT '',
  skills     TEXT[] NOT NULL DEFAULT '{}',
  last_seen  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE presence ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public read presence" ON presence;
DROP POLICY IF EXISTS "public insert presence" ON presence;
DROP POLICY IF EXISTS "public update presence" ON presence;
DROP POLICY IF EXISTS "public delete presence" ON presence;

CREATE POLICY "public read presence" ON presence FOR SELECT USING (true);
CREATE POLICY "public insert presence" ON presence FOR INSERT WITH CHECK (true);
CREATE POLICY "public update presence" ON presence FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "public delete presence" ON presence FOR DELETE USING (true);

-- 4) 로그인 IP 로그
CREATE TABLE IF NOT EXISTS login_logs (
  id         BIGSERIAL PRIMARY KEY,
  nickname   TEXT NOT NULL,
  ip         TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE login_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public insert login logs" ON login_logs;
DROP POLICY IF EXISTS "public read login logs" ON login_logs;
CREATE POLICY "public insert login logs" ON login_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "public read login logs" ON login_logs FOR SELECT USING (true);

-- 5) 실시간 채팅
CREATE TABLE IF NOT EXISTS chat_messages (
  id         BIGSERIAL PRIMARY KEY,
  nickname   TEXT NOT NULL,
  class      TEXT NOT NULL DEFAULT '',
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS chat_messages_created_at_idx ON chat_messages (created_at DESC);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public read chat" ON chat_messages;
DROP POLICY IF EXISTS "public insert chat" ON chat_messages;
CREATE POLICY "public read chat" ON chat_messages FOR SELECT USING (true);
CREATE POLICY "public insert chat" ON chat_messages FOR INSERT WITH CHECK (true);

-- Realtime
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'party_board_state'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE party_board_state;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'presence'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE presence;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  END IF;
END $$;

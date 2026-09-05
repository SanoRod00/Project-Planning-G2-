CREATE TABLE IF NOT EXISTS events (
  id BIGSERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS claims (
  rider_id TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  position INTEGER,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- 007 Clean Temp usage counter (Cloudflare D1)
CREATE TABLE IF NOT EXISTS installs (
  id         TEXT PRIMARY KEY,   -- random install ID made by the app
  first_seen TEXT NOT NULL,      -- yyyy-mm-dd (UTC)
  last_seen  TEXT NOT NULL,
  version    TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS pings (
  id      TEXT NOT NULL,
  day     TEXT NOT NULL,         -- yyyy-mm-dd (UTC)
  version TEXT NOT NULL,
  mode    TEXT NOT NULL,         -- gui or auto
  PRIMARY KEY (id, day)
);
CREATE INDEX IF NOT EXISTS pings_day ON pings(day);

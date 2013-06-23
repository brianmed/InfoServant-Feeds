BEGIN;
CREATE TABLE entry(
  id serial not null PRIMARY KEY,
  feed_name VARCHAR(128) NOT NULL,
  issued timestamp not null,
  title VARCHAR(512) not null,
  entry_id VARCHAR(512) not null,
  link VARCHAR(512) not null,
  html VARCHAR(65536) not null,
  updated timestamp default CURRENT_TIMESTAMP,
  inserted timestamp default CURRENT_TIMESTAMP,
  unique (feed_name, entry_id)
);

CREATE TRIGGER entry_timestamp BEFORE INSERT OR UPDATE ON entry
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE entry TO kevin;
GRANT INSERT ON TABLE entry TO kevin;
GRANT UPDATE ON TABLE entry TO kevin;
GRANT DELETE ON TABLE entry TO kevin;

GRANT USAGE, SELECT ON SEQUENCE entry_id_seq TO kevin;
COMMIT;

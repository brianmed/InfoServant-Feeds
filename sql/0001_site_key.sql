BEGIN;
CREATE TABLE site_key(
  id serial not null PRIMARY KEY,
  site_key VARCHAR(512) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP
);

CREATE TRIGGER site_key_timestamp BEFORE INSERT OR UPDATE ON site_key
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE site_key TO kevin;
GRANT INSERT ON TABLE site_key TO kevin;
GRANT UPDATE ON TABLE site_key TO kevin;
GRANT DELETE ON TABLE site_key TO kevin;

GRANT USAGE, SELECT ON SEQUENCE site_key_id_seq TO kevin;
COMMIT;

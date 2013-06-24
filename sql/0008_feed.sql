BEGIN;
CREATE TABLE feed(
  id serial not null PRIMARY KEY,
  xml_url VARCHAR(128) NOT NULL UNIQUE,
  updated timestamp default CURRENT_TIMESTAMP,
  inserted timestamp default CURRENT_TIMESTAMP,
);

CREATE TRIGGER feed_timestamp BEFORE INSERT OR UPDATE ON feed
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE feed TO kevin;
GRANT INSERT ON TABLE feed TO kevin;
GRANT UPDATE ON TABLE feed TO kevin;
GRANT DELETE ON TABLE feed TO kevin;

GRANT USAGE, SELECT ON SEQUENCE feed_id_seq TO kevin;
COMMIT;

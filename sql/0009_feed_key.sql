BEGIN;
CREATE TABLE feed_key(
  id serial not null PRIMARY KEY,
  feed_id integer not null,
  feed_key VARCHAR(512) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (feed_id) references feed (id),
  unique (feed_id, feed_key)
);

CREATE TRIGGER feed_key_timestamp BEFORE INSERT OR UPDATE ON feed_key
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE feed_key TO kevin;
GRANT INSERT ON TABLE feed_key TO kevin;
GRANT UPDATE ON TABLE feed_key TO kevin;
GRANT DELETE ON TABLE feed_key TO kevin;

GRANT USAGE, SELECT ON SEQUENCE feed_key_id_seq TO kevin;
COMMIT;

BEGIN;
CREATE TABLE feed_value(
  id serial not null PRIMARY KEY,
  feed_key_id integer not null unique,
  feed_value VARCHAR(4096) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (feed_key_id) references feed_key (id) on delete cascade
);

CREATE TRIGGER feed_value_timestamp BEFORE INSERT OR UPDATE ON feed_value
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE feed_value TO kevin;
GRANT INSERT ON TABLE feed_value TO kevin;
GRANT UPDATE ON TABLE feed_value TO kevin;
GRANT DELETE ON TABLE feed_value TO kevin;

GRANT USAGE, SELECT ON SEQUENCE feed_value_id_seq TO kevin;
COMMIT;

BEGIN;
CREATE TABLE feedme_key(
  id serial not null PRIMARY KEY,
  feedme_id integer not null,
  feedme_key VARCHAR(512) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (feedme_id) references feed (id) on delete cascade,
  unique (feedme_id, feedme_key)
);

CREATE TRIGGER feedme_key_timestamp BEFORE INSERT OR UPDATE ON feedme_key
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE feedme_key TO kevin;
GRANT INSERT ON TABLE feedme_key TO kevin;
GRANT UPDATE ON TABLE feedme_key TO kevin;
GRANT DELETE ON TABLE feedme_key TO kevin;

GRANT USAGE, SELECT ON SEQUENCE feedme_key_id_seq TO kevin;
COMMIT;

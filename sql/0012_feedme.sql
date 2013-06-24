BEGIN;
CREATE TABLE feedme(
  id serial not null PRIMARY KEY,
  account_id integer not null,
  feed_id integer not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (feed_id) references feed (id),
  foreign key (account_id) references feed (id)
);

CREATE TRIGGER feedme_timestamp BEFORE INSERT OR UPDATE ON feedme
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE feedme TO kevin;
GRANT INSERT ON TABLE feedme TO kevin;
GRANT UPDATE ON TABLE feedme TO kevin;
GRANT DELETE ON TABLE feedme TO kevin;

GRANT USAGE, SELECT ON SEQUENCE feedme_id_seq TO kevin;
COMMIT;

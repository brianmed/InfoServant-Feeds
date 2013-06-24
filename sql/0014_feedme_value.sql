BEGIN;
CREATE TABLE feedme_value(
  id serial not null PRIMARY KEY,
  feedme_key_id integer not null unique,
  feedme_value VARCHAR(4096) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (feedme_key_id) references feedme_key (id)
);

CREATE TRIGGER feedme_value_timestamp BEFORE INSERT OR UPDATE ON feedme_value
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE feedme_value TO kevin;
GRANT INSERT ON TABLE feedme_value TO kevin;
GRANT UPDATE ON TABLE feedme_value TO kevin;
GRANT DELETE ON TABLE feedme_value TO kevin;

GRANT USAGE, SELECT ON SEQUENCE feedme_value_id_seq TO kevin;
COMMIT;


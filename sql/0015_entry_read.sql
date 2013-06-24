BEGIN;
CREATE TABLE entry_read(
  id serial not null PRIMARY KEY,
  feed_title VARCHAR(128) NOT NULL,
  feed_name VARCHAR(128) NOT NULL,
  issued timestamp not null,
  title VARCHAR(512) not null,
  entry_id VARCHAR(512) not null,
  link VARCHAR(512) not null,
  feedme_id integer not null,
  foreign key (feedme_id) references feedme (id),
  updated timestamp default CURRENT_TIMESTAMP,
  inserted timestamp default CURRENT_TIMESTAMP,
  unique (feed_name, entry_id)
);

CREATE TRIGGER entry_read_timestamp BEFORE INSERT OR UPDATE ON entry_read
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE entry_read TO kevin;
GRANT INSERT ON TABLE entry_read TO kevin;
GRANT UPDATE ON TABLE entry_read TO kevin;
GRANT DELETE ON TABLE entry_read TO kevin;

GRANT USAGE, SELECT ON SEQUENCE entry_read_id_seq TO kevin;
COMMIT;

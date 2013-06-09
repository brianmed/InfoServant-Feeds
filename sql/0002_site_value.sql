BEGIN;
CREATE TABLE site_value(
  id serial not null PRIMARY KEY,
  site_key_id integer not null unique,
  site_value VARCHAR(4096) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (site_key_id) references site_key (id)
);

CREATE TRIGGER site_value_timestamp BEFORE INSERT OR UPDATE ON site_value
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE site_value TO kevin;
GRANT INSERT ON TABLE site_value TO kevin;
GRANT UPDATE ON TABLE site_value TO kevin;
GRANT DELETE ON TABLE site_value TO kevin;

GRANT USAGE, SELECT ON SEQUENCE site_value_id_seq TO kevin;
COMMIT;

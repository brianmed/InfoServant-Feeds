BEGIN;
CREATE TABLE account_value(
  id serial not null PRIMARY KEY,
  account_key_id integer not null unique,
  account_value VARCHAR(4096) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (account_key_id) references account_key (id) on delete cascade
);

CREATE TRIGGER account_value_timestamp BEFORE INSERT OR UPDATE ON account_value
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE account_value TO kevin;
GRANT INSERT ON TABLE account_value TO kevin;
GRANT UPDATE ON TABLE account_value TO kevin;
GRANT DELETE ON TABLE account_value TO kevin;

GRANT USAGE, SELECT ON SEQUENCE account_value_id_seq TO kevin;
COMMIT;

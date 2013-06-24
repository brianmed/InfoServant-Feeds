BEGIN;
CREATE TABLE account_key(
  id serial not null PRIMARY KEY,
  account_id integer not null,
  account_key VARCHAR(512) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (account_id) references account (id),
  unique (account_id, account_key)
);

CREATE TRIGGER account_key_timestamp BEFORE INSERT OR UPDATE ON account_key
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE account_key TO kevin;
GRANT INSERT ON TABLE account_key TO kevin;
GRANT UPDATE ON TABLE account_key TO kevin;
GRANT DELETE ON TABLE account_key TO kevin;

GRANT USAGE, SELECT ON SEQUENCE account_key_id_seq TO kevin;
COMMIT;

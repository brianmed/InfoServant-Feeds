CREATE TABLE account(
  id serial not null PRIMARY KEY,
  email VARCHAR(128) NOT NULL UNIQUE,
  username VARCHAR(30) NOT NULL UNIQUE,
  password VARCHAR(128) NOT NULL,
  updated timestamp default CURRENT_TIMESTAMP,
  inserted timestamp default CURRENT_TIMESTAMP
);

CREATE TRIGGER user_timestamp BEFORE INSERT OR UPDATE ON account
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE account TO kevin;
GRANT INSERT ON TABLE account TO kevin;
GRANT UPDATE ON TABLE account TO kevin;
GRANT DELETE ON TABLE account TO kevin;

GRANT USAGE, SELECT ON SEQUENCE account_id_seq TO kevin;
COMMIT;

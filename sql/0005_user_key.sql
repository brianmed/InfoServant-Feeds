BEGIN;
CREATE TABLE user_key(
  id serial not null PRIMARY KEY,
  account_id integer not null,
  user_key VARCHAR(512) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (account_id) references account (id),
  unique (account_id, user_key)
);

CREATE TRIGGER user_key_timestamp BEFORE INSERT OR UPDATE ON user_key
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE user_key TO kevin;
GRANT INSERT ON TABLE user_key TO kevin;
GRANT UPDATE ON TABLE user_key TO kevin;
GRANT DELETE ON TABLE user_key TO kevin;

GRANT USAGE, SELECT ON SEQUENCE user_key_id_seq TO kevin;
COMMIT;

BEGIN;
CREATE TABLE user_value(
  id serial not null PRIMARY KEY,
  user_key_id integer not null unique,
  user_value VARCHAR(4096) not null,
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (user_key_id) references user_key (id)
);

CREATE TRIGGER user_value_timestamp BEFORE INSERT OR UPDATE ON user_value
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE user_value TO kevin;
GRANT INSERT ON TABLE user_value TO kevin;
GRANT UPDATE ON TABLE user_value TO kevin;
GRANT DELETE ON TABLE user_value TO kevin;

GRANT USAGE, SELECT ON SEQUENCE user_value_id_seq TO kevin;
COMMIT;

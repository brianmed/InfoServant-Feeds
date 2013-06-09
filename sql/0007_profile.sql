BEGIN;
CREATE TABLE profile(
  id serial not null PRIMARY KEY,
  account_id integer not null,
  email_rcpt_voicemail varchar(10),
  updated timestamp not null default CURRENT_TIMESTAMP,
  inserted timestamp not null default CURRENT_TIMESTAMP,
  foreign key (account_id) references account (id)
);

CREATE TRIGGER profile_timestamp BEFORE INSERT OR UPDATE ON profile
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

GRANT SELECT ON TABLE profile TO kevin;
GRANT INSERT ON TABLE profile TO kevin;
GRANT UPDATE ON TABLE profile TO kevin;
GRANT DELETE ON TABLE profile TO kevin;

GRANT USAGE, SELECT ON SEQUENCE profile_id_seq TO kevin;
COMMIT;

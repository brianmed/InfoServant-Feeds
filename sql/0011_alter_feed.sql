BEGIN;
ALTER TABLE feed DROP CONSTRAINT feed_name_key;
ALTER TABLE feed ADD CONSTRAINT feed_account_id_name_key UNIQUE (account_id, name);
COMMIT;

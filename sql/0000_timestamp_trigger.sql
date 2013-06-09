BEGIN;
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
      NEW.updated = now(); 
      RETURN NEW;
END;
$$ language 'plpgsql';
COMMIT;

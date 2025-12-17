-- Remove the old, insecure column
ALTER TABLE profiles
DROP COLUMN IF EXISTS shopify_access_token;

-- Enable the plv8 extension if not already enabled
CREATE EXTENSION IF NOT EXISTS plv8;

-- Create the function to store secrets securely in the vault
CREATE OR REPLACE FUNCTION store_secret(name TEXT, secret TEXT)
RETURNS UUID AS $$
DECLARE
  secret_id UUID;
BEGIN
  -- Insert the secret into the vault and return its new ID
  INSERT INTO vault.secrets (name, secret)
  VALUES (name, secret)
  RETURNING id INTO secret_id;
  RETURN secret_id;
END;
$$ LANGUAGE plpgsql;

-- Create the function to retrieve secrets from the vault
CREATE OR REPLACE FUNCTION get_secret(name_in TEXT)
RETURNS TEXT AS $$
DECLARE
  secret_out TEXT;
BEGIN
  -- Select the decrypted secret from the vault view
  SELECT decrypted_secret INTO secret_out FROM vault.decrypted_secrets WHERE name = name_in;
  RETURN secret_out;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions to the authenticated and service roles
GRANT EXECUTE ON FUNCTION store_secret(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION store_secret(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION get_secret(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_secret(TEXT) TO service_role;

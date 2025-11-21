-- JWT Schema and Functions
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Function to generate JWT tokens (for reference/debugging)
CREATE OR REPLACE FUNCTION extensions.jwt_generate(
  payload json,
  secret text,
  algorithm text DEFAULT 'HS256'
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  header json;
  segments text[];
  signing_input text;
  signature text;
BEGIN
  header := json_build_object(
    'alg', algorithm,
    'typ', 'JWT'
  );

  segments := ARRAY[
    replace(replace(encode(convert_to(header::text, 'utf8'), 'base64'), '+', '-'), '/', '_'),
    replace(replace(encode(convert_to(payload::text, 'utf8'), 'base64'), '+', '-'), '/', '_')
  ];

  signing_input := array_to_string(segments, '.');

  signature := replace(replace(
    encode(
      extensions.hmac(signing_input, secret, 'sha256'),
      'base64'
    ), '+', '-'), '/', '_');

  RETURN signing_input || '.' || signature;
END;
$$;

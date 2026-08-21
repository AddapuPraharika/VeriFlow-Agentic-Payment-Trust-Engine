-- Strengthen evidence integrity: make evidence_records append-only.
-- Remove UPDATE and DELETE policies so evidence cannot be modified or deleted via the client.
-- Preserve INSERT (for new evidence) and SELECT (for verification/reading).

DROP POLICY IF EXISTS "anon_update_evidence_records" ON evidence_records;
DROP POLICY IF EXISTS "anon_delete_evidence_records" ON evidence_records;

-- Revoke column-level UPDATE and DELETE privileges from anon and authenticated
REVOKE UPDATE ON evidence_records FROM anon, authenticated;
REVOKE DELETE ON evidence_records FROM anon, authenticated;

-- Confirm: only SELECT and INSERT remain for anon/authenticated on evidence_records.
-- The verified flag is now set at INSERT time and cannot be changed afterward.
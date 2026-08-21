/*
# VeriFlow — Agentic Payment Trust Engine: Core Schema

1. Purpose
   VeriFlow is a trust and risk-control layer for agentic payments. It validates whether
   an AI agent's proposed payment stays within the user's authorization and transaction
   policy BEFORE execution, then creates a tamper-evident evidence trail for every decision.
   This is a prototype/demo using simulated Razorpay-style payment data and sandbox/mock
   execution. NEVER process real money.

2. New Tables
   - `users` — demo platform users who grant authorizations to agents.
     id (uuid pk), name (text), email (text unique), role (text: reviewer/admin),
     avatar_color (text), created_at (timestamptz).
   - `agents` — AI shopping/payment agents acting on behalf of users.
     id (uuid pk), name (text), type (text), status (text: active/suspended),
     trust_score (int), owner_id (uuid fk users), created_at (timestamptz).
   - `merchants` — merchants where transactions occur.
     id (uuid pk), name (text), category (text), country (text),
     risk_level (text: low/medium/high), created_at (timestamptz).
   - `authorizations` — user-granted payment authorizations scoped to an agent.
     id (uuid pk), user_id (uuid fk users), agent_id (uuid fk agents),
     max_amount (numeric), currency (text), allowed_merchants (text[]),
     allowed_categories (text[]), max_quantity (int), purpose (text),
     expires_at (timestamptz), status (text: active/expired/revoked),
     created_at (timestamptz).
   - `transactions` — agent-proposed transactions evaluated against authorizations.
     id (uuid pk), authorization_id (uuid fk authorizations), agent_id (uuid fk agents),
     user_id (uuid fk users), merchant_id (uuid fk merchants), amount (numeric),
     currency (text), quantity (int), purpose (text), status (text: pending/approved/
     blocked/escalated/executed/failed), decision (text), created_at (timestamptz).
   - `risk_decisions` — explainable risk evaluation for each transaction.
     id (uuid pk), transaction_id (uuid fk transactions), decision (text: approved/
     blocked/escalated), risk_score (int), risk_level (text: low/medium/high/critical),
     failed_checks (jsonb), passed_checks (jsonb), explanation (text),
     risk_factors (jsonb), created_at (timestamptz).
   - `policy_violations` — individual policy check failures.
     id (uuid pk), transaction_id (uuid fk transactions), check_name (text),
     severity (text), expected (text), actual (text), message (text),
     created_at (timestamptz).
   - `evidence_records` — tamper-evident evidence trail for each transaction lifecycle.
     id (uuid pk), transaction_id (uuid fk transactions), evidence_hash (text unique),
     payload (jsonb), chain_hash (text), previous_hash (text), verified (bool),
     created_at (timestamptz).
   - `payment_events` — simulated Razorpay-style payment lifecycle events.
     id (uuid pk), transaction_id (uuid fk transactions), event_type (text:
     order_created/payment_initiated/payment_success/payment_failed/captured/refunded),
     razorpay_order_id (text), razorpay_payment_id (text), razorpay_signature (text),
     amount (numeric), currency (text), status (text), metadata (jsonb),
     created_at (timestamptz).

3. Security
   - This is a single-tenant demo app with no sign-in screen, so all tables use
     `TO anon, authenticated` CRUD policies. The data is intentionally shared/public
     for demonstration purposes.
   - RLS enabled on every table.
   - Evidence hashes are generated client-side via SubtleCrypto and stored; the
     `verified` flag supports tamper-detection demonstration.

4. Notes
   - All amounts are numeric to support precise INR values.
   - JSONB columns store structured policy checks and risk factors for explainability.
   - `chain_hash` + `previous_hash` on evidence_records form a lightweight hash chain
     to demonstrate tamper detection across the evidence trail.
*/

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  role text NOT NULL DEFAULT 'reviewer' CHECK (role IN ('reviewer','admin')),
  avatar_color text NOT NULL DEFAULT '#2563eb',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL DEFAULT 'shopping',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended')),
  trust_score int NOT NULL DEFAULT 85,
  owner_id uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS merchants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL,
  country text NOT NULL DEFAULT 'India',
  risk_level text NOT NULL DEFAULT 'low' CHECK (risk_level IN ('low','medium','high')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS authorizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  max_amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  allowed_merchants text[] NOT NULL DEFAULT '{}',
  allowed_categories text[] NOT NULL DEFAULT '{}',
  max_quantity int NOT NULL DEFAULT 1,
  purpose text NOT NULL DEFAULT 'general',
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','revoked')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  authorization_id uuid NOT NULL REFERENCES authorizations(id) ON DELETE CASCADE,
  agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  merchant_id uuid NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  quantity int NOT NULL DEFAULT 1,
  purpose text NOT NULL DEFAULT 'general',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','blocked','escalated','executed','failed')),
  decision text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS risk_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('approved','blocked','escalated')),
  risk_score int NOT NULL DEFAULT 0,
  risk_level text NOT NULL DEFAULT 'low' CHECK (risk_level IN ('low','medium','high','critical')),
  failed_checks jsonb NOT NULL DEFAULT '[]',
  passed_checks jsonb NOT NULL DEFAULT '[]',
  explanation text NOT NULL,
  risk_factors jsonb NOT NULL DEFAULT '[]',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS policy_violations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  check_name text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('info','warning','critical')),
  expected text NOT NULL,
  actual text NOT NULL,
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS evidence_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  evidence_hash text UNIQUE NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}',
  chain_hash text NOT NULL,
  previous_hash text NOT NULL DEFAULT 'GENESIS',
  verified boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('order_created','payment_initiated','payment_success','payment_failed','captured','refunded')),
  razorpay_order_id text,
  razorpay_payment_id text,
  razorpay_signature text,
  amount numeric,
  currency text,
  status text NOT NULL DEFAULT 'pending',
  metadata jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_authorizations_user ON authorizations(user_id);
CREATE INDEX IF NOT EXISTS idx_authorizations_agent ON authorizations(agent_id);
CREATE INDEX IF NOT EXISTS idx_transactions_authorization ON transactions(authorization_id);
CREATE INDEX IF NOT EXISTS idx_transactions_agent ON transactions(agent_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_risk_decisions_transaction ON risk_decisions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_policy_violations_transaction ON policy_violations(transaction_id);
CREATE INDEX IF NOT EXISTS idx_evidence_transaction ON evidence_records(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_transaction ON payment_events(transaction_id);

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_events ENABLE ROW LEVEL SECURITY;

-- Single-tenant demo: anon + authenticated CRUD on all tables (data intentionally shared)
CREATE POLICY "anon_read_users" ON users FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_users" ON users FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_users" ON users FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_users" ON users FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_agents" ON agents FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_agents" ON agents FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_agents" ON agents FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_agents" ON agents FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_merchants" ON merchants FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_merchants" ON merchants FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_merchants" ON merchants FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_merchants" ON merchants FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_authorizations" ON authorizations FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_authorizations" ON authorizations FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_authorizations" ON authorizations FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_authorizations" ON authorizations FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_transactions" ON transactions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_transactions" ON transactions FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_transactions" ON transactions FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_transactions" ON transactions FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_risk_decisions" ON risk_decisions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_risk_decisions" ON risk_decisions FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_risk_decisions" ON risk_decisions FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_risk_decisions" ON risk_decisions FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_policy_violations" ON policy_violations FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_policy_violations" ON policy_violations FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_policy_violations" ON policy_violations FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_policy_violations" ON policy_violations FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_evidence_records" ON evidence_records FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_evidence_records" ON evidence_records FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_evidence_records" ON evidence_records FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_evidence_records" ON evidence_records FOR DELETE TO anon, authenticated USING (true);

CREATE POLICY "anon_read_payment_events" ON payment_events FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_payment_events" ON payment_events FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_payment_events" ON payment_events FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_payment_events" ON payment_events FOR DELETE TO anon, authenticated USING (true);
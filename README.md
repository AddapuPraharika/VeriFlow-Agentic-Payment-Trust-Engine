# VeriFlow — Agentic Payment Trust Engine

VeriFlow is a fintech MVP that adds a trust and risk-control layer before an AI agent can execute a payment. It compares the user's explicit authorization against the agent's proposed action, applies deterministic policy checks, explains the outcome, and seals the lifecycle in a tamper-evident evidence record.

This prototype uses simulated Razorpay-style payment data and mock execution only. It never processes real money.

## The problem

Autonomous shopping and payment agents can move from intent to action faster than a person can review them. A user might authorize a laptop purchase up to a certain amount, but the agent could propose a more expensive item, an unexpected merchant, or an unusual quantity. Traditional dashboards show what happened after the fact. VeriFlow controls the decision before execution.

## The solution

Every proposal flows through:

1. A user authorization with amount, currency, merchant/category, quantity, purpose, and expiry.
2. An agent identity check.
3. Deterministic policy validation.
4. Explainable risk evaluation.
5. APPROVED, BLOCKED, or ESCALATED decision.
6. Mock payment execution only after approval.
7. A hash-sealed evidence record and visual lifecycle timeline.

## Architecture

- React + TypeScript frontend with Tailwind CSS.
- Supabase Postgres persistence with row-level security enabled on every table.
- Core tables: users, agents, merchants, authorizations, transactions, risk_decisions, policy_violations, evidence_records, and payment_events.
- A RazorpayPaymentService abstraction with mock mode as the default. Future sandbox/live calls belong behind a server-side Supabase Edge Function and never expose secret keys to the browser.
- The browser uses Supabase only for the demo workspace. Production deployments should add authenticated, tenant-scoped policies and server-enforced mutation functions.

## AI/risk logic

The engine is deterministic and policy-first. It checks:

- Authorization active status and expiry.
- Amount limit and amount utilization.
- Merchant allow-list and category scope.
- Currency and quantity.
- Payment purpose.
- Merchant risk level.
- Agent trust score.
- Recent transaction frequency.
- Repeated failed attempts.
- Unusual amount patterns.

Critical policy failures block execution. Warning failures or elevated risk escalate for human review. Passing checks with low risk approves the request. The explanation is generated from the deterministic result; no language model can independently execute a financial action.

## Razorpay integration approach

The current service exposes separate functions for create order, validate payment, simulate payment success/failure, capture simulation, and refund simulation. It returns Razorpay-style order and payment identifiers in mock mode. A production implementation would call Razorpay Test Mode from a Supabase Edge Function, verify payment signatures server-side, and keep all credentials in server-side secrets.

## Security controls

- No real payment processing in the MVP.
- No secret keys in frontend code.
- Deterministic policy checks before payment execution.
- Evidence payload SHA-256 hash and linked hash chain.
- Evidence integrity verification action.
- Audit records for decisions, violations, payment events, and timestamps.
- RLS enabled for every persistence table.
- Production note: replace demo shared policies with authenticated tenant ownership and server-enforced role/reviewer permissions.

## Demo scenarios

- **A — Legitimate purchase:** ₹64,999 laptop from an allowed merchant against a ₹70,000 authorization. Approved and simulated.
- **B — Out-of-scope amount:** ₹82,000 against a ₹70,000 maximum. Blocked with the exact failed policy check.
- **C — Suspicious merchant:** An in-limit request to a high-risk merchant outside the allowed category. Escalated for human review.

Use the prominent **Run agentic demo** button to run Scenario A end-to-end and open the evidence timeline. Use the simulator to run all scenarios or edit the proposed transaction.

## Future production architecture

Add Supabase Auth and tenant-scoped RLS, reviewer/admin role claims in immutable app metadata, server-side risk and payment mutations via Edge Functions, verified Razorpay webhooks, idempotency keys, rate limiting, immutable append-only audit storage, external key management, and a real reviewer workflow with approvals and SLA tracking.

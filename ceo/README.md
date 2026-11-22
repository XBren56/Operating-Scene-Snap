# Owner-only business area

This folder documents the CEO office section of the Workroom. The running UI route is `CEO office`; the business records it displays belong in the `business_records` database table, which is protected by the CEO database role.

**A folder in this repository is not private.** The GitHub repository is public, so this folder contains no confidential business documents, owner email, passwords, or API keys. In production, server-side authentication must verify the one configured owner email and the approved `ceo` role on every request. The private owner email belongs in a server secret, never in this repository or browser code.

The owner area is intended for the business plan, goals, policies, services and pricing, supplier agreements, licensing and insurance records, tax and bookkeeping records, season plans, approvals, staffing/access management, and business-wide reports.

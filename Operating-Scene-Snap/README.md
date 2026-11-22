# Scene Snap Workroom

Operations dashboard prototype for employees and the business owner. This repository is a separate app from the customer storefront so operational screens can be reviewed independently. Both apps should connect to the same secured database when authentication is configured.

## Prototype sections

- Events, quote stages, orders, customer follow-ups, and service timelines.
- Design templates and custom proof workflow.
- Supplier sourcing, costs, stock, order status, and returns.
- Staff shifts, setup/teardown windows, travel, assigned labor, and season preparation.
- Staff account roles and a CEO-only business office for finances, approvals, records, access, and audit history.

Open `index.html` directly to preview the sample screens. The account switcher is a visual demo only; it is not authentication.

## Access model

Users start as customers. An employee must verify an issued company email and have a matching, active `staff_members` record created or approved by the owner. The assigned role determines which rows and actions the employee can access. Merely using an email from a company domain does not grant access. The owner account must be configured privately on the server and protected with row-level security. Do not place the owner email, service keys, passwords, or payment secrets in this public repository.

## Go-live checklist

1. Create a Supabase project; apply `database/schema.sql` and enable row-level security.
2. Add the owner email as a private server secret and create the matching CEO identity. Use a verified staff invitation flow for employees.
3. Connect both repositories to Supabase Auth. Recheck authorization on the server/database for every read and write; front-end route hiding is not security.
4. Configure payment processing, tax settings, transactional email, storage, backups, and privacy/booking policies before accepting real orders.
5. Replace all sample events, staff, sales, addresses, and costs with real records only after access controls are verified.

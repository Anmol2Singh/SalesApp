# CRM App — Production Readiness Task List

## Role & Operating Instructions

You are working inside an existing CRM application codebase. Before writing any code:

1. **Explore the codebase first.** Identify the tech stack (frontend framework, backend framework, database/ORM, auth system), folder structure, existing models/schemas for Prospect, Lead, Customer, Inventory, Complaints, Quotation, and Users/Roles. Do not assume a stack — confirm from the repo.
2. **Map data relationships before touching logic.** Several tasks below depend on a single source-of-truth data model (Prospect → Lead → Customer). Trace how these entities currently relate (shared ID, duplicated records, foreign keys) before implementing fixes, so data isn't duplicated or lost.
3. **Work module by module.** Use the priority order below. After each module, run/build and verify no regressions before moving to the next.
4. **Do not stub or fake functionality.** Every item must be fully working end-to-end (UI + API + DB), not a visual mock.
5. **Reference images — STRUCTURE ONLY, NOT THEME.** Five reference images were provided (Inventory, Invoice/Quotation/Sales-Order/BOQ/PO document UI, Complaints, CRM Dashboard, Customer Products). They are **mockups from unrelated apps** used purely to communicate layout, information hierarchy, and interaction patterns (card structures, stat-tile groupings, list-item anatomy, form field grouping, chart placement, tab/filter placement). **Do not copy their colors, fonts, iconography, or branding.** Every rebuilt screen must use the CRM app's existing color palette, typography, spacing scale, and component library so it looks native to the app, not like a pasted-in mockup. Detailed per-screen breakdowns are under each relevant task below.
6. **Ask only when truly blocked.** If a requirement is ambiguous, choose the most sensible interpretation consistent with the rest of this spec and note the assumption in your output/PR description, rather than stopping work.
7. **Fully responsive, everywhere.** Every screen touched in this spec — existing or newly built — must work correctly on mobile phones, tablets, laptops, and large desktop monitors. This is not a single task to check off; treat it as a constraint applied to each module as you build it: fluid/grid layouts (no fixed pixel widths that break on small screens), touch-friendly tap targets on mobile, tables/lists that collapse to cards or scroll horizontally on narrow viewports, charts and dashboards that reflow rather than overflow, and the searchable dropdowns (3.1) and modals/forms usable with touch keyboards. Test each rebuilt screen at minimum at these breakpoints: ~375px (mobile), ~768px (tablet), ~1024px (small laptop), ~1440px+ (desktop).

---

## Priority 1 — Core Data Integrity & Permissions
*(These affect every other module, fix first)*

### 1.1 Unified Data Propagation (Prospect → Lead → Customer)
- Every field captured at Prospect creation (name, phone, address, notes, lead source, etc.) must persist unchanged as the record converts: Prospect → Lead → Customer.
- No field should be re-entered manually at a later stage if it was already captured earlier — carry it forward automatically, but allow authorized edits.
- Add a **Notes** text box at the bottom of the Prospect creation form; persist this note through Lead and Customer stages, visible in each record's detail view.
- Write a data audit: pick 5 sample fields (address, phone, lead source, product interest, notes) and verify they survive all stage conversions without loss or truncation.

### 1.2 Edit Permissions
- A record (Prospect/Lead/Customer) is editable in full **by its creator**.
- If a record is **assigned** to someone else, the assignee can edit everything **except** the customer's name and phone number.
- Admin users can always edit everything, regardless of creator/assignee.
- Implement this as a reusable permission-check (middleware/hook), not per-field ad hoc checks, so it applies consistently across the app and doesn't regress.

### 1.3 Customer Edit Bug
- Fix: editing a customer's name currently does not save. Debug the update path (form → API → DB) end to end.
- Ensure **all** customer field edits persist correctly, not just name.

### 1.4 Global Data Sync
- When a customer's details are updated anywhere in the app, that change must reflect everywhere the customer is referenced (deals, complaints, invoices, product/purchase records, dashboards) — no cached/duplicated stale copies.
- Prefer a single source of truth (normalized reference/foreign key) over copying customer data into other tables. If denormalized copies exist for performance, add a sync mechanism (event/trigger) to update them.

---

## Priority 2 — Lead & Quotation Logic

### 2.1 Estimated Deal Value
- During Lead conversion, make **Estimated Deal Value read-only** (display only, not an editable input).

### 2.2 Auto-Sync Deal Value from Quotation
- After a Lead is created and a Quotation is generated/updated, automatically pull the quotation's total amount and update the Lead's Estimated Deal Value field.

### 2.3 Expected Closing Date Validation
- Expected Closing Date must **not** equal the lead creation date and must **not** be a past date relative to today. Add both client-side and server-side validation with clear error messaging.

### 2.4 Lock Quotations on Win/Loss
- Once a Lead is marked **Won** or **Lost**, prevent creation of any further quotations for it.
- Automatically mark the most recent quotation as the **Final Quotation** at that point.

### 2.5 Auto-Create Deal on Won Lead
- When a Lead is marked **Won** and converts to a Customer:
  - Automatically create a Deal under that Customer using the **same product name(s)** as the Lead.
  - Skip the quotation step entirely for this deal — copy over all data (products, pricing, quantities, terms) from the Lead's final quotation as-is.

### 2.6 Reminders / Call Alerts
- Inside Leads, add an option to set a reminder/alert (e.g., "call customer on [date]").
- Sales person or CRM staff can set a date; the app must notify/remind the assigned user on that date (in-app notification at minimum; push/email if the app already supports those channels).

---

## Priority 3 — UI/UX Consistency

### 3.1 Searchable Dropdowns (App-wide)
- Convert **every** dropdown/select input in the app into a searchable dropdown:
  - Clicking the input opens a list with the cursor auto-focused in a search field.
  - Typing filters the list in real time.
- Implement as a single reusable component and replace all existing native `<select>`/basic dropdown instances with it, rather than patching each one individually.

### 3.2 Fix "Add" Button Overlap Bug (App-wide)
- Bug: floating "+Add Item" (and similar) buttons overlap the last item in scrollable lists, blocking edit/delete access (reported in Inventory, but audit and fix this pattern everywhere it occurs — e.g., Leads list, Complaints list, Product list).
- Fix approach: ensure the button is either sticky with proper bottom padding/margin reserved in the scroll container, or repositioned so it never overlaps the last list item, on all screen sizes.

### 3.3 Reassignment Dropdown Filtering
- When reassigning a Prospect/Lead/Customer, the "assign to" list should show **only Sales Person role users** — exclude Admin users (admins have full visibility already and don't need to be assignable targets in this flow).

### 3.4 Login Page Scroll Fix
- Make the login page scrollable/responsive so that on smaller screens, no button (e.g., "Login", "Forgot Password") is cut off or pushed outside the visible viewport.

---

## Priority 4 — Dashboard & Settings

### 4.1 CRM Dashboard Enhancement
Reference: `CRM_NewDashboard.png` — structure only, restyle with app theme.

Rebuild the dashboard with this layout:
- **Top stat-tile row(s):** a grid of compact KPI tiles (reference shows 8: Total Sales, Win Rate, Close Rate, Avg Days to Close, Pipeline Value, Open Deals, Weighted Value, Avg Open Deal Age). Map to this CRM's real equivalents — e.g., Total Prospects, Total Leads, Win Rate, Close Rate, Avg Days to Close, Pipeline/Deal Value, Open Deals, Avg Response Time — adjust the metric set to whatever this app already tracks; don't invent data that doesn't exist.
- **Two donut charts:** one for pipeline/stage distribution (e.g., % of leads in each stage: New, Contacted, Quotation Sent, Negotiation, Won, Lost), one for a loss-reason or lead-source breakdown.
- **Two trend line charts:** "Won Deals" over the last 12 months (value + count, dual-line) and a forward-looking "Deals Projection" for the next 12 months if the app has enough data to project; otherwise substitute a relevant trend (e.g., Leads Created vs Leads Won per month).
- **Right-side filter panel:** date-range picker, and dropdown filters (Deal Owner / Sales Person, Deal Stage, Pipeline, Label) — all filters must use the searchable-dropdown component from 3.1 and actually filter the dashboard data on change, not just be decorative.
- All charts/tiles must reflect **live data** from the CRM's actual database, not placeholder numbers.

### 4.2 CRM Settings Panel
Reference: `CRM_NewDashboard.png` top-right "Setup dashboard" button placement — structure only.

- Add a **Settings** icon/button at the top-right of the CRM Dashboard header (same position as the reference's top-right action button), styled with the app's own button/icon treatment.
- Clicking it opens a settings management screen that at minimum allows managing the **Lead Source** dropdown list (add/edit/remove/reorder options used during Prospect creation) — full CRUD.
- Design this settings screen to be extensible for future configurable lists (e.g., complaint categories, product categories, deal-loss reasons) without a rebuild — build it as a generic "manage list" component that takes a list type as a parameter.

### 4.3 Inventory Redesign
Reference: `Inventory_-_Redesign___Structure.jpeg` — this file is a **wireframe/structure diagram**, not a polished visual (the phone screens on top are just style/pattern inspiration for card-and-icon grouping and bottom tab navigation; the hand-drawn boxes below define the actual required information architecture). Follow the diagram's logic exactly:

- **Inventory** splits into two top-level sections: **Sell Products** and **Items**.
  - **Items** → shows the **Existing Item List** (flat list/grid of all inventory items).
  - **Sell Products** → shows the product catalog available for sale (e.g., "Heat Pump", "Boom Barrier", etc. — actual product names from this app's data), each with:
    - **Manage Capacity** — CRUD (add/edit/delete) on the list of capacity options for that product, shown to sales staff when converting a Prospect to a Lead (i.e., these become the selectable "capacity" dropdown values during Prospect→Lead conversion for that product). Give explicit **Edit** and **Delete** controls on each capacity entry.
    - **Edit Name** — rename the product.
    - **Delete** — remove the product (with confirmation, and a check for whether it's referenced by existing leads/deals before allowing hard delete).
    - **Sub-Systems** — a linked list of systems/accessories the customer may want to buy alongside this main product (e.g., installation kit, controller unit). This list must be selectable later during quotation/lead creation alongside the main product.
- Keep the app's existing visual theme (colors, cards, typography) — only borrow the *information structure* (Sell Products vs Items split, Manage Capacity sub-screen, Sub-Systems list) from this diagram.
- **Also apply the "Add" button overlap fix (3.2) specifically here** — this is the screen the bug was originally reported on.

**Secondary reference:** `Invoice-Quotation-SalesOrder-BOQ-PurchaseOrder-Factory_Form_UI.png` — use this only for the **document-creation pattern** needed when generating a Quotation/Sales Order/BOQ/Purchase Order from Inventory items (relevant to tasks 2.2 and 2.5): a searchable/filterable document list (All / Paid / Unpaid-style status tabs), a create-document form with recipient info, issued/due dates, a line-items section with an "Add Item" action, and a send/share action. Restyle entirely in the app's theme — do not use the yellow/purple mockup styling.

### 4.4 CRM Competitive / Leaderboard Tab
Add a new **"Leaderboard"** (or "Competitive") tab inside the **CRM Dashboard** — distinct navigation entry alongside Overview/Agents/Deals, not merged into an existing screen.

- Shows a ranked, **real-time** leaderboard of Sales Person users based on CRM-relevant metrics such as:
  - Number of Prospects created
  - Number of Leads converted to Customers ("how many customers bought")
  - Total deal value won
  - Win rate
- Support switching the ranking metric and a time-range filter (This Week / This Month / This Quarter / All Time) using the searchable-dropdown component (3.1).
- "Real-time" means the numbers reflect current DB state on load/refresh (and via live update — e.g., websocket/polling — if the app already has that infrastructure elsewhere; otherwise refresh-on-focus is acceptable, but note this as an assumption).
- Only Sales Person users appear as ranked entries (consistent with 3.3 — admins aren't part of the competitive ranking, though admins can view the tab).
- This is a **CRM-only** leaderboard — it must pull exclusively from Prospect/Lead/Customer/Deal data, never from Complaints data. See 5.4 for the separate Complaints leaderboard; the two must not share a screen, component instance, or data source, even though they may reuse the same underlying leaderboard UI component for consistency.

---

## Priority 5 — Complaints Module

### 5.1 Complaints Dashboard Update
Reference: `Complaints.png` — structure only, restyle with app theme.

Rebuild using this layout logic:
- **Overview screen:** a top KPI tile row (e.g., Total Complaints, Open, In Progress, Resolved, Avg Resolution Time) plus a trend chart and a breakdown chart (e.g., complaints by category or by technician), following the reference's stat-tile + line-chart + bar-chart grouping.
- **Complaint List screen** (reference's "Order List" pattern): each list item is a card showing:
  - Complaint ID (e.g., #CMP-1024)
  - Status badge (color-coded: e.g., Open / In Progress / Resolved / Approved — use the app's own status-color convention)
  - Customer name + avatar/initials
  - Complaint/product/category description
  - Location/address
  - Date raised ("2 days ago" / "Just now" style relative timestamps)
  - Assigned technician, if any
- **Complaint Detail screen** (reference's "User information" pattern): full complaint details, a Notes field, and action icons for status update / delete / duplicate-as-new, restyled to the app's components.
- This dashboard must clearly distinguish and let staff filter between the two complaint sources defined in 5.2 (staff-logged vs customer-submitted).

### 5.2 Two Complaint Intake Flows
- Separate and clearly manage two distinct complaint sources:
  1. Complaints logged by **internal staff users** on behalf of a customer.
  2. Complaints submitted directly by **customers via their login/portal**.
- Both should feed into the same underlying complaint records/queue but be distinguishable by source, with appropriate views/filters for staff.

### 5.3 Technician Assignment Bug
- Fix: complaints are not being assigned to technicians. Debug the assignment flow (UI action → API → DB write → technician's queue) end to end.
- Add validation/error handling so this cannot silently fail again (e.g., surface an error to the user if assignment fails, don't fail silently).

### 5.4 Complaints Competitive / Leaderboard Tab
Add a new **"Leaderboard"** (or "Competitive") tab inside the **Complaints Dashboard** — a separate navigation entry from the CRM one in 4.4.

- Shows a ranked, **real-time** leaderboard of staff/technicians based on Complaints-relevant metrics such as:
  - Number of complaints logged (by staff)
  - Number of complaints resolved (by technician)
  - Average resolution time
  - Customer satisfaction/rating if the app tracks it
- Support switching the ranking metric and a time-range filter, using the searchable-dropdown component (3.1).
- **Keep this fully separate from the CRM leaderboard (4.4):** different route/screen, different data query (pulls only from Complaints/Technician data, never Prospect/Lead/Customer/Deal data), and it must not be reachable from within the CRM Dashboard's tab set or vice versa. It's fine for both to reuse the same underlying leaderboard **UI component** for visual consistency, but the data and navigation must stay independent so the two modules don't get conflated.

---

## Priority 6 — Customer Portal

### 6.1 Purchased Products Visibility
- Fix: customers cannot see their purchased products in their portal/login. Debug the data fetch (likely a broken join/filter between Customer, Deal, and Product records) and restore visibility.

### 6.2 Customer Products UI
Reference: `Customer_Dashboard.jpg` — structure only; this is an e-commerce fashion-app mockup, so **ignore its yellow/black theme and clothing content entirely** and apply the CRM's existing theme.

Borrow only these structural patterns:
- **Grid/list of purchased products**, each item as a card with: product image (or icon if no product photo exists), product name, and key detail in place of "price" — e.g., purchase date, warranty/AMC status, or serial/unit number.
- **Filter/search bar** at the top of the product list (use the searchable-dropdown/search pattern from 3.1) to filter by product type, purchase date range, or status.
- **Product detail view** (like the reference's item-detail panel): full specs, purchase date, warranty info, linked invoice/quotation, and a "Raise Complaint" action that feeds into the complaint intake flow (5.2, customer-submitted path).
- Do not include cart/checkout/shopping concepts (size, brand filter, "add to bag") — those are irrelevant; only the card-grid + filter + detail-panel layout pattern applies.

### 6.3 Customer Payments Page
No direct reference image was provided for this screen — build it consistent with the app's theme and the list/detail card patterns established in 6.2 and the invoice list pattern in `Invoice-Quotation-SalesOrder-BOQ-PurchaseOrder-Factory_Form_UI.png` (4.3 secondary reference): status tabs (e.g., All / Paid / Due), a list of payment/invoice cards (amount, date, status badge, related product/deal), and a detail view per payment showing invoice/receipt breakdown. Confirm exact layout with the user if a dedicated reference becomes available before finalizing.

---

## Production Readiness Checklist (final pass, after all modules above)

- [ ] No console errors/warnings in browser or server logs during normal usage flows
- [ ] All forms validate on both client and server side
- [ ] All permission rules (1.2) verified with test accounts for each role (Admin, Sales Person, Technician, Customer)
- [ ] Full Prospect → Lead → Customer → Deal → Complaint lifecycle tested end-to-end with no data loss
- [ ] All searchable dropdowns tested for keyboard navigation and empty/no-results states
- [ ] Mobile/responsive check on Dashboard, Inventory, Complaints, Login, and Customer portal screens
- [ ] Every rebuilt/touched screen verified at all four breakpoints (mobile ~375px, tablet ~768px, laptop ~1024px, desktop ~1440px+) with no horizontal overflow, cut-off buttons, or unusable touch targets
- [ ] CRM Leaderboard (4.4) and Complaints Leaderboard (5.4) verified as fully independent screens with no shared data leakage between them
- [ ] Load test key list views (Inventory, Leads, Complaints) with realistic data volume to confirm the scroll/overlap fix holds
- [ ] Regression pass on existing working features to confirm nothing broke during this update
- [ ] Environment variables/secrets audited, no hardcoded credentials
- [ ] Error boundaries / fallback UI in place for failed API calls across the app

## Suggested Execution Order
1. Priority 1 (data + permissions foundation)
2. Priority 2 (lead/quotation logic, depends on 1.1)
3. Priority 3 (UI-wide consistency fixes)
4. Priority 4 (dashboard/settings/inventory — reference images provided, see per-task notes)
5. Priority 5 (complaints — reference image provided)
6. Priority 6 (customer portal — reference image provided for Products; Payments has no direct reference)
7. Final production readiness checklist
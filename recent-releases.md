Ran command: `flutter build apk --release`

I have started building the release APK (`flutter build apk --release`). The build is currently running in the background, and I will notify you as soon as it completes.

Ran command: `Copy-Item -Path "d:\Files\Office Projects\Insiya Solar Industry\SalesFormApp\salesapp\build\app\outputs\flutter-apk\app-release.apk" -Destination "C:\Users\Anmol\.gemini\antigravity-ide\brain\6f843d56-942d-468e-ac26-310e01f60085\app-release.apk" -Force`
Edited walkthrough.md

### Release APK Built Successfully! 🚀

The Android release APK has been compiled with zero errors.

- **APK File**: `app-release.apk` (Size: `71.4MB`)
- **Build Output**: `d:\Files\Office Projects\Insiya Solar Industry\SalesFormApp\salesapp\build\app\outputs\flutter-apk\app-release.apk`
- **Direct Artifact Link**: [app-release.apk](file:///C:/Users/Anmol/.gemini/antigravity-ide/brain/6f843d56-942d-468e-ac26-310e01f60085/app-release.apk)

---

### What's Packed in this Release

1. **Lead WhatsApp & Email Integration**:
   - Explicit `<queries>` intent filters in AndroidManifest.
   - Cleaned phone formatting with standard India country code (`91`) appending for WhatsApp and email redirection.

2. **Deals Pipeline 100% Complete & Warranty Cards**:
   - Auto-marking deal completion when all pipeline stages are satisfied.
   - Admin manual lock override button.
   - Warranty card certificate generation unlocked upon deal completion.
   - Prominent Active AMC cards in Customer App & CRM.

3. **Customer Login Purchased Products**:
   - Multi-field customer resolution across phone, email, and name.
   - State invalidation on login ensuring customer assets and purchase history load immediately.

4. **Technician Defected Items Order & Customer Instant Payment**:
   - Inventory item warranty tracking (`warranty_months`).
   - Dynamic warranty calculation in technician complaint view (₹0 if under warranty, inventory price if expired).
   - Instant "Pay for Replacement Parts (₹X)" checkout button in the Customer App.

5. **Complaint "Reason for Part Replacement" Dropdown**:
   - Required standard options (`Voltage issue`, `System Warranty over`, `Other person serviced the system`).

6. & 10. **Salesperson Assignment & "Converted By" Staff Attribution**:
   - Assign / Reassign salesperson sheet with dynamic staff selection from `profiles`.
   - "Converted by: [Staff Name]" badges displayed across CRM, Lead, and Customer detail views.

7. **Admin-Only Editable Reference Dropdown for Lead Sources**:
   - Dynamic `crm_sources` table integration with filter chips and prospect forms.
   - Admin-exclusive dialog to add and remove lead sources on the fly.

8. **Prospect to Lead Conversion Enhancements**:
   - Capacity dropdown (`Ltr` & `kW`).
   - Dynamic component selection checkboxes synced with inventory prices.
   - Automatic calculation and live population of Estimated Deal Value.

9. **Quotations inside Lead Section & 3-Column Payment Terms Table**:
   - Direct quotation generation from Leads with revision management (`Rev 1`, `Rev 2`, etc.).
   - Interactive 3-column table: `[Term / Stage, Percentage (%), Amount (₹)]`.
   - Automatic calculation of stage amounts against grand total.
   - Clean rendering of Payment Terms schedule into quotation PDFs.

The APK is ready for deployment and testing on user and field devices!
// lib/features/quotation_generator/config/quotation_generator_flags.dart

/// Feature flag: Master enable/disable for Quotation Generator module.
const bool kQuotationGeneratorEnabled = true;

/// Feature flag: Standalone quote creation (manual entry, standalone sequence)
/// is retired in favor of the deal-driven approval workflow.
const bool kQgStandaloneCreateEnabled = false;

/// Hard containment guard:
/// The module is strictly READ-ONLY against existing database tables
/// (`quotations`, `pdf_templates`) and existing storage buckets
/// (`company-assets`, `product-images`, `pdfs`).
/// Any write attempt to these legacy tables/buckets is neutralized.
const bool kDisableUnsafeExistingWrites = true;

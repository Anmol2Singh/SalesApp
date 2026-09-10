-- ============================================================
-- IZYHEAT Sales App — Migration 003: Seed Data
-- ============================================================

-- ============================================================
-- PRODUCTS: Boom Barrier & Heat Pump
-- ============================================================

INSERT INTO products (id, name, category, base_specs, is_active) VALUES
(
  uuid_generate_v4(),
  'Boom Barrier',
  'Access Control',
  '{
    "quotation_fields": [
      {"key": "model", "label": "Model / Series", "type": "text", "required": true},
      {"key": "boom_length", "label": "Boom Length (meters)", "type": "number", "required": true, "min": 1, "max": 12},
      {"key": "operation_speed", "label": "Operation Speed (seconds)", "type": "number", "required": false},
      {"key": "power_supply", "label": "Power Supply", "type": "select", "options": ["220V AC", "24V DC", "Solar"], "required": true},
      {"key": "color", "label": "Color / Finish", "type": "text", "required": false},
      {"key": "quantity", "label": "Quantity (units)", "type": "number", "required": true, "min": 1},
      {"key": "installation_type", "label": "Installation Type", "type": "select", "options": ["Indoor", "Outdoor", "Semi-Outdoor"], "required": true}
    ],
    "boq_required_fields": [
      {"key": "site_address", "label": "Installation Site Address", "type": "textarea", "required": true},
      {"key": "civil_work_required", "label": "Civil Work Required?", "type": "boolean", "required": true},
      {"key": "cable_length", "label": "Cable Length Required (meters)", "type": "number", "required": true},
      {"key": "controller_type", "label": "Controller Type", "type": "select", "options": ["Loop Detector", "RFID", "Face Recognition", "Manual Remote"], "required": true},
      {"key": "foundation_type", "label": "Foundation Type", "type": "text", "required": false}
    ]
  }',
  TRUE
),
(
  uuid_generate_v4(),
  'Heat Pump',
  'HVAC',
  '{
    "quotation_fields": [
      {"key": "model", "label": "Model / Series", "type": "text", "required": true},
      {"key": "capacity_kw", "label": "Capacity (kW)", "type": "number", "required": true, "min": 1},
      {"key": "cop", "label": "COP Rating", "type": "number", "required": false},
      {"key": "refrigerant", "label": "Refrigerant Type", "type": "select", "options": ["R410A", "R32", "R290", "R134a"], "required": true},
      {"key": "application", "label": "Application", "type": "select", "options": ["Water Heating", "Space Heating", "Pool Heating", "Industrial Process"], "required": true},
      {"key": "quantity", "label": "Quantity (units)", "type": "number", "required": true, "min": 1},
      {"key": "voltage", "label": "Voltage", "type": "select", "options": ["220V Single Phase", "415V Three Phase"], "required": true}
    ],
    "boq_required_fields": [
      {"key": "site_address", "label": "Installation Site Address", "type": "textarea", "required": true},
      {"key": "water_flow_rate", "label": "Water Flow Rate (LPH)", "type": "number", "required": true},
      {"key": "inlet_temp", "label": "Inlet Water Temperature (°C)", "type": "number", "required": true},
      {"key": "outlet_temp", "label": "Outlet Water Temperature (°C)", "type": "number", "required": true},
      {"key": "pipe_size", "label": "Pipe Connection Size (inches)", "type": "number", "required": false},
      {"key": "electrical_phase", "label": "Available Electrical Phase", "type": "select", "options": ["Single Phase", "Three Phase"], "required": true}
    ]
  }',
  TRUE
);

-- ============================================================
-- PDF TEMPLATES: Default configs for all 4 document types
-- ============================================================

INSERT INTO pdf_templates (document_type, template_config, is_active) VALUES
(
  'quotation',
  '{
    "company_name": "IZYHEAT",
    "company_tagline": "Premium Industrial Solutions",
    "company_address": "Your Company Address, City, State - PIN",
    "company_phone": "+91 XXXXXXXXXX",
    "company_email": "sales@izyheat.com",
    "company_gst": "GSTIN: XXXXXXXXXXX",
    "company_website": "www.izyheat.com",
    "logo_url": null,
    "primary_color": "#1E3A5F",
    "accent_color": "#E8A020",
    "header_text": "QUOTATION",
    "footer_text": "Thank you for your business. This quotation is valid for 30 days from the date of issue.",
    "terms_default": "1. Prices are exclusive of GST unless mentioned.\n2. Delivery: 4-6 weeks from order confirmation.\n3. Payment: 50% advance, 50% before dispatch.\n4. Warranty: As per manufacturer warranty terms.\n5. Installation charges billed separately.",
    "bank_details": {
      "bank_name": "Your Bank Name",
      "account_name": "IZYHEAT / Insiya Trading Corporation",
      "account_number": "XXXXXXXXXXXX",
      "ifsc": "XXXXXX0XXXXX",
      "branch": "Your Branch"
    }
  }',
  TRUE
),
(
  'boq',
  '{
    "company_name": "IZYHEAT",
    "company_tagline": "Premium Industrial Solutions",
    "company_address": "Your Company Address, City, State - PIN",
    "company_phone": "+91 XXXXXXXXXX",
    "company_email": "sales@izyheat.com",
    "company_gst": "GSTIN: XXXXXXXXXXX",
    "logo_url": null,
    "primary_color": "#1E3A5F",
    "accent_color": "#E8A020",
    "header_text": "BILL OF QUANTITIES",
    "footer_text": "This BOQ is prepared based on the confirmed quotation and site survey. Final quantities may vary."
  }',
  TRUE
),
(
  'factory_order',
  '{
    "company_name": "IZYHEAT",
    "company_tagline": "Premium Industrial Solutions",
    "company_address": "Your Company Address, City, State - PIN",
    "company_phone": "+91 XXXXXXXXXX",
    "company_email": "production@izyheat.com",
    "logo_url": null,
    "primary_color": "#1E3A5F",
    "accent_color": "#E8A020",
    "header_text": "FACTORY ORDER",
    "footer_text": "This factory order must be completed per the specifications. Contact sales team for any clarifications."
  }',
  TRUE
),
(
  'purchase_order',
  '{
    "company_name": "IZYHEAT",
    "company_tagline": "Premium Industrial Solutions",
    "company_address": "Your Company Address, City, State - PIN",
    "company_phone": "+91 XXXXXXXXXX",
    "company_email": "purchase@izyheat.com",
    "company_gst": "GSTIN: XXXXXXXXXXX",
    "logo_url": null,
    "primary_color": "#1E3A5F",
    "accent_color": "#E8A020",
    "header_text": "PURCHASE ORDER",
    "footer_text": "Please confirm receipt of this purchase order. All items must meet the specifications listed.",
    "terms_default": "1. Delivery as per agreed schedule.\n2. Quality inspection required before acceptance.\n3. Payment terms: Net 30 days from invoice date.\n4. All items must be accompanied by inspection certificates."
  }',
  TRUE
);

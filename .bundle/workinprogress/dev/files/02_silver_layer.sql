-- SILVER LAYER - Clean, Deduplicated Data with Technical Columns
-- Implements SCD Type 2 (Slowly Changing Dimensions) patterns
-- Unions ONLINE and POS source systems with proper lineage tracking

-- ==================== SILVER CLIENTS (SCD Type 2) ====================
-- Dimension table with full history of client changes
CREATE TABLE IF NOT EXISTS silver_clients (
    -- Surrogate Keys
    sk_client BIGINT AUTO_INCREMENT PRIMARY KEY,
    
    -- Natural Key (from source)
    client_id STRING NOT NULL,
    
    -- Business Columns (cleaned/standardized)
    client_name STRING,
    client_country_code STRING,  -- ONLINE-only, NULL for POS
    
    -- Technical Columns - SCD Type 2
    effective_from_date DATE,
    effective_to_date DATE,
    is_current BOOLEAN DEFAULT TRUE,
    
    -- Audit/Lineage Columns
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING,  -- ONLINE or POS
    source_record_id BIGINT,  -- Link to bronze load_id
    record_hash STRING,  -- MD5 of business columns
    change_reason STRING,
    
    -- Constraints
    CONSTRAINT unique_client_key UNIQUE (client_id, source_system, effective_from_date),
    CONSTRAINT valid_dates CHECK (effective_from_date <= effective_to_date OR effective_to_date IS NULL)
) USING DELTA;

-- ==================== SILVER PRODUCTS (SCD Type 2) ====================
-- Product dimension (both systems contribute different products)
CREATE TABLE IF NOT EXISTS silver_products (
    -- Surrogate Keys
    sk_product BIGINT AUTO_INCREMENT PRIMARY KEY,
    
    -- Natural Key (from source)
    product_id STRING NOT NULL,
    
    -- Business Columns (cleaned/standardized)
    product_name STRING,  -- POS-only, derived for ONLINE
    product_category STRING,  -- POS-only, NULL for ONLINE
    
    -- Technical Columns - SCD Type 2
    effective_from_date DATE,
    effective_to_date DATE,
    is_current BOOLEAN DEFAULT TRUE,
    
    -- Audit/Lineage Columns
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING,  -- ONLINE or POS
    source_record_id BIGINT,  -- Link to bronze load_id
    record_hash STRING,  -- MD5 of business columns
    change_reason STRING,
    
    -- Constraints
    CONSTRAINT unique_product_key UNIQUE (product_id, source_system, effective_from_date),
    CONSTRAINT valid_dates CHECK (effective_from_date <= effective_to_date OR effective_to_date IS NULL)
) USING DELTA;

-- ==================== SILVER INVOICES (FACT TABLE) ====================
-- Transaction fact table (can have multiple products per invoice in POS via line items)
CREATE TABLE IF NOT EXISTS silver_invoices (
    -- Surrogate Keys
    sk_invoice BIGINT AUTO_INCREMENT PRIMARY KEY,
    sk_client BIGINT,  -- Foreign key to silver_clients
    sk_product BIGINT,  -- Foreign key to silver_products
    
    -- Natural Keys (from source)
    invoice_date DATE,
    client_id STRING,
    product_id STRING,
    store_id STRING,  -- POS-only, NULL for ONLINE
    
    -- Business Columns
    quantity INT,
    unit_price DECIMAL(15, 2),  -- POS-only
    amount DECIMAL(15, 2),  -- ONLINE-only (pre-calculated total)
    discount_prc DECIMAL(5, 2),  -- POS-only, discount percentage
    
    -- Calculated
    invoice_amount DECIMAL(15, 2),  -- Final invoice amount (calculated for consistency)
    
    -- Audit/Lineage Columns
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING,  -- ONLINE or POS
    source_record_id BIGINT,  -- Link to bronze load_id
    record_hash STRING,  -- MD5 of business key columns
    
    -- Constraints
    CONSTRAINT unique_invoice UNIQUE (invoice_date, client_id, product_id, source_system),
    CONSTRAINT valid_amount CHECK (invoice_amount >= 0),
    CONSTRAINT valid_quantity CHECK (quantity > 0)
) USING DELTA;

-- ==================== SILVER COUNTRIES (REFERENCE) ====================
CREATE TABLE IF NOT EXISTS silver_countries (
    sk_country BIGINT AUTO_INCREMENT PRIMARY KEY,
    country_code STRING NOT NULL,
    country_name STRING,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_record_id BIGINT,
    record_hash STRING,
    CONSTRAINT unique_country UNIQUE (country_code)
) USING DELTA;

-- ==================== SILVER STORES (REFERENCE) ====================
CREATE TABLE IF NOT EXISTS silver_stores (
    sk_store BIGINT AUTO_INCREMENT PRIMARY KEY,
    store_id STRING NOT NULL,
    store_name STRING,
    store_country_code STRING,
    store_region STRING,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_record_id BIGINT,
    record_hash STRING,
    CONSTRAINT unique_store UNIQUE (store_id)
) USING DELTA;

-- ==================== LOAD PROCEDURES ====================

-- Procedure: Load Silver Clients (UNION ONLINE + POS)
CREATE OR REPLACE PROCEDURE load_silver_clients()
BEGIN
    INSERT INTO silver_clients (
        client_id, client_name, client_country_code,
        created_date, source_system, source_record_id, record_hash,
        effective_from_date, effective_to_date, is_current, change_reason
    )
    SELECT
        TRIM(combined.client_id) as client_id,
        TRIM(UPPER(combined.client_name)) as client_name,
        CASE WHEN combined.source_system = 'ONLINE' THEN TRIM(combined.client_country_code) ELSE NULL END as client_country_code,
        CURRENT_TIMESTAMP as created_date,
        combined.source_system,
        combined.load_id as source_record_id,
        combined.record_hash,
        CURRENT_DATE as effective_from_date,
        NULL as effective_to_date,
        TRUE as is_current,
        'Initial Load from ' || combined.source_system as change_reason
    FROM (
        -- ONLINE System Data
        SELECT * FROM bronze_clients_online
        UNION ALL
        -- POS System Data
        SELECT 
            load_id, record_hash, load_timestamp, source_system, source_file,
            client_id, client_name, NULL as client_country_code
        FROM bronze_clients_pos
    ) combined
    WHERE combined.record_hash NOT IN (
        SELECT DISTINCT record_hash 
        FROM silver_clients 
        WHERE source_system = combined.source_system
    )
    AND combined.client_id IS NOT NULL;
END;

-- Procedure: Load Silver Products (UNION ONLINE + POS)
CREATE OR REPLACE PROCEDURE load_silver_products()
BEGIN
    INSERT INTO silver_products (
        product_id, product_name, product_category,
        created_date, source_system, source_record_id, record_hash,
        effective_from_date, effective_to_date, is_current, change_reason
    )
    SELECT
        TRIM(combined.product_id) as product_id,
        CASE WHEN combined.source_system = 'POS' THEN TRIM(UPPER(combined.product_name)) ELSE NULL END as product_name,
        CASE WHEN combined.source_system = 'POS' THEN UPPER(TRIM(combined.product_category)) ELSE NULL END as product_category,
        CURRENT_TIMESTAMP as created_date,
        combined.source_system,
        combined.load_id as source_record_id,
        combined.record_hash,
        CURRENT_DATE as effective_from_date,
        NULL as effective_to_date,
        TRUE as is_current,
        'Initial Load from ' || combined.source_system as change_reason
    FROM (
        -- ONLINE System Data (product mapping only)
        SELECT 
            load_id, record_hash, load_timestamp, source_system, source_file,
            product_id, NULL as product_name, NULL as product_category
        FROM bronze_products_online
        UNION ALL
        -- POS System Data (full product info)
        SELECT * FROM bronze_products_pos
    ) combined
    WHERE combined.record_hash NOT IN (
        SELECT DISTINCT record_hash 
        FROM silver_products 
        WHERE source_system = combined.source_system
    )
    AND combined.product_id IS NOT NULL;
END;

-- Procedure: Load Silver Invoices (UNION ONLINE + POS with proper joins)
CREATE OR REPLACE PROCEDURE load_silver_invoices()
BEGIN
    INSERT INTO silver_invoices (
        sk_client, sk_product, invoice_date, client_id, product_id, store_id,
        quantity, unit_price, amount, discount_prc, invoice_amount,
        created_date, source_system, source_record_id, record_hash
    )
    SELECT
        sc.sk_client,
        sp.sk_product,
        TRY_CAST(TRIM(combined.date) AS DATE) as invoice_date,
        TRIM(combined.client_id) as client_id,
        TRIM(combined.product_id) as product_id,
        TRIM(combined.store_id) as store_id,
        TRY_CAST(TRIM(combined.quantity) AS INT) as quantity,
        TRY_CAST(TRIM(combined.unit_price) AS DECIMAL(15,2)) as unit_price,
        TRY_CAST(TRIM(combined.amount) AS DECIMAL(15,2)) as amount,
        TRY_CAST(TRIM(combined.discount_prc) AS DECIMAL(5,2)) as discount_prc,
        CASE 
            WHEN combined.source_system = 'ONLINE' THEN TRY_CAST(TRIM(combined.amount) AS DECIMAL(15,2))
            ELSE ROUND(TRY_CAST(TRIM(combined.quantity) AS INT) * TRY_CAST(TRIM(combined.unit_price) AS DECIMAL(15,2)) * (1 - TRY_CAST(TRIM(combined.discount_prc) AS DECIMAL(5,2)) / 100), 2)
        END as invoice_amount,
        CURRENT_TIMESTAMP as created_date,
        combined.source_system,
        combined.load_id as source_record_id,
        combined.record_hash
    FROM (
        -- ONLINE System Data
        SELECT 
            load_id, record_hash, load_timestamp, source_system, source_file,
            date, client_id, product_online_id as product_id, NULL as store_id,
            quantity, NULL as unit_price, amount, NULL as discount_prc
        FROM bronze_invoices_online
        UNION ALL
        -- POS System Data
        SELECT 
            load_id, record_hash, load_timestamp, source_system, source_file,
            date, client_id, product_id, store_id,
            quantity, unit_price, NULL as amount, discount_prc
        FROM bronze_invoices_pos
    ) combined
    LEFT JOIN silver_clients sc 
        ON TRIM(combined.client_id) = TRIM(sc.client_id) 
        AND combined.source_system = sc.source_system 
        AND sc.is_current = TRUE
    LEFT JOIN silver_products sp 
        ON TRIM(combined.product_id) = TRIM(sp.product_id) 
        AND combined.source_system = sp.source_system 
        AND sp.is_current = TRUE
    WHERE combined.record_hash NOT IN (
        SELECT DISTINCT record_hash 
        FROM silver_invoices 
        WHERE source_system = combined.source_system
    )
    AND combined.date IS NOT NULL
    AND combined.client_id IS NOT NULL
    AND combined.product_id IS NOT NULL;
END;

-- Procedure: Load Reference - Countries
CREATE OR REPLACE PROCEDURE load_silver_countries()
BEGIN
    INSERT INTO silver_countries (
        country_code, country_name, source_record_id, record_hash
    )
    SELECT
        TRIM(UPPER(country_code)) as country_code,
        TRIM(country_name) as country_name,
        load_id as source_record_id,
        record_hash
    FROM bronze_countries
    WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM silver_countries)
    AND country_code IS NOT NULL;
END;

-- Procedure: Load Reference - Stores
CREATE OR REPLACE PROCEDURE load_silver_stores()
BEGIN
    INSERT INTO silver_stores (
        store_id, store_name, store_country_code, store_region, source_record_id, record_hash
    )
    SELECT
        TRIM(store_id) as store_id,
        TRIM(store_name) as store_name,
        TRIM(UPPER(store_country_code)) as store_country_code,
        TRIM(store_region) as store_region,
        load_id as source_record_id,
        record_hash
    FROM bronze_stores
    WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM silver_stores)
    AND store_id IS NOT NULL;
END;

-- ==================== DATA QUALITY CHECKS ====================

-- Quality Check: Show unified data from both source systems
SELECT 
    'silver_clients' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT CASE WHEN source_system = 'ONLINE' THEN client_id END) as online_clients,
    COUNT(DISTINCT CASE WHEN source_system = 'POS' THEN client_id END) as pos_clients,
    COUNT(CASE WHEN is_current = TRUE THEN 1 END) as current_records,
    MIN(created_date) as first_load,
    MAX(modified_date) as last_update
FROM silver_clients
UNION ALL
SELECT 
    'silver_products' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT CASE WHEN source_system = 'ONLINE' THEN product_id END) as online_products,
    COUNT(DISTINCT CASE WHEN source_system = 'POS' THEN product_id END) as pos_products,
    COUNT(CASE WHEN is_current = TRUE THEN 1 END) as current_records,
    MIN(created_date) as first_load,
    MAX(modified_date) as last_update
FROM silver_products
UNION ALL
SELECT 
    'silver_invoices' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT CASE WHEN source_system = 'ONLINE' THEN invoice_date END) as online_invoice_dates,
    COUNT(DISTINCT CASE WHEN source_system = 'POS' THEN invoice_date END) as pos_invoice_dates,
    NULL as current_records,
    MIN(created_date) as first_load,
    MAX(modified_date) as last_update
FROM silver_invoices;

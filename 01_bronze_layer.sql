-- BRONZE LAYER - Raw Data Ingestion with Metadata
-- Load raw CSV data with technical columns for lineage and auditing
-- Separate tables for ONLINE and POS source systems

-- ==================== ONLINE SYSTEM ====================

-- Bronze Clients - ONLINE System
CREATE TABLE IF NOT EXISTS bronze_clients_online (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'ONLINE',
    source_file STRING DEFAULT 'clients_online.csv',
    
    -- Raw columns from source (CSV: client_id, client_name, client_country_code)
    client_id STRING,
    client_name STRING,
    client_country_code STRING,
    
    CONSTRAINT unique_record_online UNIQUE (record_hash)
) USING DELTA;

-- Bronze Invoices - ONLINE System
CREATE TABLE IF NOT EXISTS bronze_invoices_online (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'ONLINE',
    source_file STRING DEFAULT 'invoices_online.csv',
    
    -- Raw columns from source (CSV: date, client_id, product_online_id, amount, quantity)
    date STRING,
    client_id STRING,
    product_online_id STRING,
    amount STRING,
    quantity STRING,
    
    CONSTRAINT unique_record_online UNIQUE (record_hash)
) USING DELTA;

-- Bronze Products - ONLINE System
CREATE TABLE IF NOT EXISTS bronze_products_online (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'ONLINE',
    source_file STRING DEFAULT 'products_online.csv',
    
    -- Raw columns from source (CSV: product_online_id, product_id)
    product_online_id STRING,
    product_id STRING,
    
    CONSTRAINT unique_record_online UNIQUE (record_hash)
) USING DELTA;

-- ==================== POS SYSTEM ====================

-- Bronze Clients - POS System
CREATE TABLE IF NOT EXISTS bronze_clients_pos (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'POS',
    source_file STRING DEFAULT 'clients_pos.csv',
    
    -- Raw columns from source (CSV: client_id, client_name)
    client_id STRING,
    client_name STRING,
    
    CONSTRAINT unique_record_pos UNIQUE (record_hash)
) USING DELTA;

-- Bronze Invoices - POS System
CREATE TABLE IF NOT EXISTS bronze_invoices_pos (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'POS',
    source_file STRING DEFAULT 'invoices_pos.csv',
    
    -- Raw columns from source (CSV: date, client_id, store_id, product_id, quantity, unit_price, discount_prc)
    date STRING,
    client_id STRING,
    store_id STRING,
    product_id STRING,
    quantity STRING,
    unit_price STRING,
    discount_prc STRING,
    
    CONSTRAINT unique_record_pos UNIQUE (record_hash)
) USING DELTA;

-- Bronze Products - POS System
CREATE TABLE IF NOT EXISTS bronze_products_pos (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'POS',
    source_file STRING DEFAULT 'products_pos.csv',
    
    -- Raw columns from source (CSV: product_id, product_name, product_category)
    product_id STRING,
    product_name STRING,
    product_category STRING,
    
    CONSTRAINT unique_record_pos UNIQUE (record_hash)
) USING DELTA;

-- ==================== REFERENCE DATA (Shared) ====================

-- Bronze Reference Data - Countries
CREATE TABLE IF NOT EXISTS bronze_countries (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'REFERENCE',
    source_file STRING DEFAULT 'countries.csv',
    
    -- Raw columns from source (CSV: country_code, country_name)
    country_code STRING,
    country_name STRING,
    
    CONSTRAINT unique_record UNIQUE (record_hash)
) USING DELTA;

-- Bronze Reference Data - Stores
CREATE TABLE IF NOT EXISTS bronze_stores (
    load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_hash STRING,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system STRING DEFAULT 'REFERENCE',
    source_file STRING DEFAULT 'stores.csv',
    
    -- Raw columns from source (CSV: store_id, store_name, store_country_code, store_region)
    store_id STRING,
    store_name STRING,
    store_country_code STRING,
    store_region STRING,
    
    CONSTRAINT unique_record UNIQUE (record_hash)
) USING DELTA;

-- ==================== RECORD_HASH CALCULATION PROCEDURES ====================

-- Procedure: Populate record_hash for ONLINE Clients
CREATE OR REPLACE PROCEDURE calculate_record_hash_clients_online()
BEGIN
    UPDATE bronze_clients_online
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(client_id, ''), COALESCE(client_name, ''), COALESCE(client_country_code, '')))
    WHERE record_hash IS NULL;
END;

-- Procedure: Populate record_hash for ONLINE Invoices
CREATE OR REPLACE PROCEDURE calculate_record_hash_invoices_online()
BEGIN
    UPDATE bronze_invoices_online
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(date, ''), COALESCE(client_id, ''), COALESCE(product_online_id, ''), COALESCE(quantity, '')))
    WHERE record_hash IS NULL;
END;

-- Procedure: Populate record_hash for ONLINE Products
CREATE OR REPLACE PROCEDURE calculate_record_hash_products_online()
BEGIN
    UPDATE bronze_products_online
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(product_online_id, ''), COALESCE(product_id, '')))
    WHERE record_hash IS NULL;
END;

-- Procedure: Populate record_hash for POS Clients
CREATE OR REPLACE PROCEDURE calculate_record_hash_clients_pos()
BEGIN
    UPDATE bronze_clients_pos
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(client_id, ''), COALESCE(client_name, '')))
    WHERE record_hash IS NULL;
END;

-- Procedure: Populate record_hash for POS Invoices
CREATE OR REPLACE PROCEDURE calculate_record_hash_invoices_pos()
BEGIN
    UPDATE bronze_invoices_pos
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(date, ''), COALESCE(client_id, ''), COALESCE(store_id, ''), COALESCE(product_id, ''), COALESCE(quantity, '')))
    WHERE record_hash IS NULL;
END;

-- Procedure: Populate record_hash for POS Products
CREATE OR REPLACE PROCEDURE calculate_record_hash_products_pos()
BEGIN
    UPDATE bronze_products_pos
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(product_id, ''), COALESCE(product_name, ''), COALESCE(product_category, '')))
    WHERE record_hash IS NULL;
END;

-- Procedure: Populate record_hash for Countries
CREATE OR REPLACE PROCEDURE calculate_record_hash_countries()
BEGIN
    UPDATE bronze_countries
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(country_code, ''), COALESCE(country_name, '')))
    WHERE record_hash IS NULL;
END;

-- Procedure: Populate record_hash for Stores
CREATE OR REPLACE PROCEDURE calculate_record_hash_stores()
BEGIN
    UPDATE bronze_stores
    SET record_hash = MD5(CONCAT_WS('|', COALESCE(store_id, ''), COALESCE(store_name, ''), COALESCE(store_country_code, ''), COALESCE(store_region, '')))
    WHERE record_hash IS NULL;
END;

-- ==================== DATA QUALITY CHECKS ====================

-- Bronze Data Quality Summary by Source System
SELECT 
    'ONLINE - Clients' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records,
    COUNT(DISTINCT DATE(load_timestamp)) as load_dates,
    MAX(load_timestamp) as latest_load
FROM bronze_clients_online
UNION ALL
SELECT 
    'ONLINE - Invoices' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records,
    COUNT(DISTINCT DATE(load_timestamp)) as load_dates,
    MAX(load_timestamp) as latest_load
FROM bronze_invoices_online
UNION ALL
SELECT 
    'ONLINE - Products' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records,
    COUNT(DISTINCT DATE(load_timestamp)) as load_dates,
    MAX(load_timestamp) as latest_load
FROM bronze_products_online
UNION ALL
SELECT 
    'POS - Clients' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records,
    COUNT(DISTINCT DATE(load_timestamp)) as load_dates,
    MAX(load_timestamp) as latest_load
FROM bronze_clients_pos
UNION ALL
SELECT 
    'POS - Invoices' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records,
    COUNT(DISTINCT DATE(load_timestamp)) as load_dates,
    MAX(load_timestamp) as latest_load
FROM bronze_invoices_pos
UNION ALL
SELECT 
    'POS - Products' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records,
    COUNT(DISTINCT DATE(load_timestamp)) as load_dates,
    MAX(load_timestamp) as latest_load
FROM bronze_products_pos;

-- DATA LOADING LAYER - Load CSV files into Bronze tables with record_hash calculation
-- Execute this script to load raw data from 'data input/' folder in Databricks Repos
-- Note: Update USER_ID placeholder below with your actual Databricks user ID (70497244463236)
-- Note: Update REPO_NAME placeholder with your actual repository name

-- ==================== LOAD ONLINE CLIENTS ====================
INSERT INTO bronze_clients_online (record_hash, client_id, client_name, client_country_code)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(client_id, ''), COALESCE(client_name, ''), COALESCE(client_country_code, ''))) as record_hash,
    TRIM(client_id) as client_id,
    TRIM(client_name) as client_name,
    TRIM(client_country_code) as client_country_code
FROM read_files('/Repos/70497244463236/databricks_learning/data input/clients_online.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_clients_online WHERE record_hash IS NOT NULL);

-- ==================== LOAD POS CLIENTS ====================
INSERT INTO bronze_clients_pos (record_hash, client_id, client_name)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(client_id, ''), COALESCE(client_name, ''))) as record_hash,
    TRIM(client_id) as client_id,
    TRIM(client_name) as client_name
FROM read_files('/path/to/data input/clients_pos.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_clients_pos WHERE record_hash IS NOT NULL);

-- ==================== LOAD ONLINE INVOICES ====================
INSERT INTO bronze_invoices_online (record_hash, date, client_id, product_online_id, amount, quantity)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(date, ''), COALESCE(client_id, ''), COALESCE(product_online_id, ''), COALESCE(quantity, ''))) as record_hash,
    TRIM(date) as date,
    TRIM(client_id) as client_id,
    TRIM(product_online_id) as product_online_id,
    TRIM(amount) as amount,
    TRIM(quantity) as quantity
FROM read_files('/path/to/data input/invoices_online.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_invoices_online WHERE record_hash IS NOT NULL);

-- ==================== LOAD POS INVOICES ====================
INSERT INTO bronze_invoices_pos (record_hash, date, client_id, store_id, product_id, quantity, unit_price, discount_prc)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(date, ''), COALESCE(client_id, ''), COALESCE(store_id, ''), COALESCE(product_id, ''), COALESCE(quantity, ''))) as record_hash,
    TRIM(date) as date,
    TRIM(client_id) as client_id,
    TRIM(store_id) as store_id,
    TRIM(product_id) as product_id,
    TRIM(quantity) as quantity,
    TRIM(unit_price) as unit_price,
    TRIM(discount_prc) as discount_prc
FROM read_files('/path/to/data input/invoices_pos.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_invoices_pos WHERE record_hash IS NOT NULL);

-- ==================== LOAD ONLINE PRODUCTS ====================
INSERT INTO bronze_products_online (record_hash, product_online_id, product_id)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(product_online_id, ''), COALESCE(product_id, ''))) as record_hash,
    TRIM(product_online_id) as product_online_id,
    TRIM(product_id) as product_id
FROM read_files('/path/to/data input/products_online.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_products_online WHERE record_hash IS NOT NULL);

-- ==================== LOAD POS PRODUCTS ====================
INSERT INTO bronze_products_pos (record_hash, product_id, product_name, product_category)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(product_id, ''), COALESCE(product_name, ''), COALESCE(product_category, ''))) as record_hash,
    TRIM(product_id) as product_id,
    TRIM(product_name) as product_name,
    TRIM(product_category) as product_category
FROM read_files('/path/to/data input/products_pos.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_products_pos WHERE record_hash IS NOT NULL);

-- ==================== LOAD COUNTRIES (REFERENCE) ====================
INSERT INTO bronze_countries (record_hash, country_code, country_name)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(country_code, ''), COALESCE(country_name, ''))) as record_hash,
    TRIM(country_code) as country_code,
    TRIM(country_name) as country_name
FROM read_files('/path/to/data input/countries.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_countries WHERE record_hash IS NOT NULL);

-- ==================== LOAD STORES (REFERENCE) ====================
INSERT INTO bronze_stores (record_hash, store_id, store_name, store_country_code, store_region)
SELECT 
    MD5(CONCAT_WS('|', COALESCE(store_id, ''), COALESCE(store_name, ''), COALESCE(store_country_code, ''), COALESCE(store_region, ''))) as record_hash,
    TRIM(store_id) as store_id,
    TRIM(store_name) as store_name,
    TRIM(store_country_code) as store_country_code,
    TRIM(store_region) as store_region
FROM read_files('/path/to/data input/stores.csv', format => 'csv', header => true)
WHERE record_hash NOT IN (SELECT DISTINCT record_hash FROM bronze_stores WHERE record_hash IS NOT NULL);

-- ==================== LOAD SUMMARY ====================
-- After loading, run quality checks to verify data is loaded
SELECT 
    'ONLINE - Clients' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_clients_online
UNION ALL
SELECT 
    'POS - Clients' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_clients_pos
UNION ALL
SELECT 
    'ONLINE - Invoices' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_invoices_online
UNION ALL
SELECT 
    'POS - Invoices' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_invoices_pos
UNION ALL
SELECT 
    'ONLINE - Products' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_products_online
UNION ALL
SELECT 
    'POS - Products' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_products_pos
UNION ALL
SELECT 
    'Countries' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_countries
UNION ALL
SELECT 
    'Stores' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT record_hash) as unique_records
FROM bronze_stores;

-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TRANSFORM & LOAD (CRM CUSTOMER INFO)
-- DESCRIPTION: Cleans, standardizes, deduplicates, and loads customer records 
--              from the Bronze layer into the Silver layer.
-- =================================================================================

USE DataWarehouse;

-- 1. Clear existing data in the Silver table before reloading
TRUNCATE TABLE silver_crm_cust_info;

-- 2. Insert transformed and deduplicated data into Silver
INSERT INTO silver_crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
)
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    -- Standardize marital status codes, clean casing, and remove trailing spaces
    CASE 
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'n/a'
    END AS cst_marital_status,
    -- Standardize gender codes, clean casing, and remove trailing spaces
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    cst_create_date
FROM (
    SELECT
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gender AS cst_gndr, -- Maps Bronze column name to match Silver schema
        cst_create_date,
        ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze_crm_cust_info
    WHERE cst_id IS NOT NULL
) t
WHERE flag_last = 1;

-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TABLE DDL INITIALIZATION
-- DESCRIPTION:
--     Initializes the cleaned, conformed, and validated Silver layer tables.
--     Appends the `dwh_create_date` metadata column to track pipeline execution.
-- =================================================================================

USE DataWarehouse;

-- =========================================================
-- CRM SYSTEM - SILVER LAYER TABLES
-- =========================================================

-- 1. CRM Customer Information
DROP TABLE IF EXISTS silver_crm_cust_info;
CREATE TABLE silver_crm_cust_info (
    cst_id             INT,
    cst_key            VARCHAR(50),
    cst_firstname      VARCHAR(50),
    cst_lastname       VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr           VARCHAR(50), -- Standardized short name from video DDL
    cst_create_date    DATE,
    dwh_create_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. CRM Product Information
DROP TABLE IF EXISTS silver_crm_prd_info;
CREATE TABLE silver_crm_prd_info (
    prd_id           INT,
    prd_key          VARCHAR(50),
    prd_nm           VARCHAR(50),
    prd_cost         INT,
    prd_line         VARCHAR(50),
    prd_start_dt     DATETIME,
    prd_end_dt       DATETIME,
    dwh_create_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. CRM Sales Details (Brought forward from Bronze to keep pipeline complete)
DROP TABLE IF EXISTS silver_crm_sales_details;
CREATE TABLE silver_crm_sales_details (
    sls_ord_num      VARCHAR(50),
    sls_prd_key      VARCHAR(50),
    sls_cust_id      INT,
    sls_order_dt     DATE, -- Will be transformed from numeric INT key to proper DATE
    sls_ship_dt      DATE,
    sls_due_dt       DATE,
    sls_sales        INT,
    sls_quantity     INT,
    sls_price        INT,
    dwh_create_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =========================================================
-- ERP SYSTEM - SILVER LAYER TABLES
-- =========================================================

-- 4. ERP Location Data
DROP TABLE IF EXISTS silver_erp_loc_a101;
CREATE TABLE silver_erp_loc_a101 (
    cid              VARCHAR(50),
    cntry            VARCHAR(50),
    dwh_create_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. ERP Customer Data
DROP TABLE IF EXISTS silver_erp_cust_az12;
CREATE TABLE silver_erp_cust_az12 (
    cid              VARCHAR(50),
    bdate            DATE, -- Upgraded to actual DATE from Bronze VARCHAR string
    gen              VARCHAR(50),
    dwh_create_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. ERP Product Category Data
DROP TABLE IF EXISTS silver_erp_px_cat_g1v2;
CREATE TABLE silver_erp_px_cat_g1v2 (
    id               VARCHAR(50),
    cat              VARCHAR(50),
    subcat           VARCHAR(50),
    maintenance      VARCHAR(50),
    dwh_create_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

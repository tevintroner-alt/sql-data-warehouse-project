-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TRANSFORM & LOAD (CRM SALES DETAILS)
-- DESCRIPTION: Cleans transaction orders, standardizes numeric date keys into 
--              proper DATE formats, and resolves data quality anomalies between 
--              sales, quantity, and price.
-- =================================================================================

USE DataWarehouse;

-- 1. Initialize or reset the Silver Sales Details table DDL
DROP TABLE IF EXISTS silver_crm_sales_details;
CREATE TABLE silver_crm_sales_details (
    sls_ord_num    VARCHAR(50),
    sls_prd_key    VARCHAR(50),
    sls_cust_id    INT,
    sls_order_dt   DATE,
    sls_ship_dt    DATE,
    sls_due_dt     DATE,
    sls_sales      INT,
    sls_quantity   INT,
    sls_price      INT,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Clear existing data before reloading
TRUNCATE TABLE silver_crm_sales_details;

-- 3. Insert transformed and validated data into Silver
INSERT INTO silver_crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)
SELECT
    TRIM(sls_ord_num) AS sls_ord_num,
    TRIM(sls_prd_key) AS sls_prd_key,
    sls_cust_id,
    
    -- Transform order date integer (e.g., 20101229) to proper DATE format
    CASE 
        WHEN sls_order_dt = 0 OR CHAR_LENGTH(CAST(sls_order_dt AS CHAR)) != 8 THEN NULL
        ELSE STR_TO_DATE(CAST(sls_order_dt AS CHAR), '%Y%m%d')
    END AS sls_order_dt,
    
    -- Transform ship date integer to proper DATE format
    CASE 
        WHEN sls_ship_dt = 0 OR CHAR_LENGTH(CAST(sls_ship_dt AS CHAR)) != 8 THEN NULL
        ELSE STR_TO_DATE(CAST(sls_ship_dt AS CHAR), '%Y%m%d')
    END AS sls_ship_dt,
    
    -- Transform due date integer to proper DATE format
    CASE 
        WHEN sls_due_dt = 0 OR CHAR_LENGTH(CAST(sls_due_dt AS CHAR)) != 8 THEN NULL
        ELSE STR_TO_DATE(CAST(sls_due_dt AS CHAR), '%Y%m%d')
    END AS sls_due_dt,
    
    -- Data Quality Rule: If sales is missing, zero, negative, or miscalculated, derive it from quantity * price
    CASE 
        WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
            THEN sls_quantity * ABS(IFNULL(sls_price, 0))
        ELSE sls_sales
    END AS sls_sales,
    
    sls_quantity,
    
    -- Data Quality Rule: If price is missing or negative/zero, derive it from sales / quantity, or make absolute
    CASE 
        WHEN sls_price IS NULL OR sls_price <= 0 
            THEN CASE 
                    WHEN sls_quantity IS NULL OR sls_quantity = 0 THEN 0 
                    ELSE sls_sales / sls_quantity 
                 END
        ELSE sls_price
    END AS sls_price

FROM bronze_crm_sales_details;

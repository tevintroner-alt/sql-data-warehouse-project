-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - MASTER ORCHESTRATION STORED PROCEDURE
-- DESCRIPTION: Executes all Silver layer transformations sequentially inside 
--              a single ACID transaction with automated rollback error handling.
-- =================================================================================

USE DataWarehouse;

-- Drop procedure if it already exists so we can safely recreate it
DROP PROCEDURE IF EXISTS sp_load_silver_layer;

DELIMITER //

CREATE PROCEDURE sp_load_silver_layer()
begin
    -- Declare an exit handler to catch any SQL errors, rollback changes, and throw the error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Start the transactional boundary
    START TRANSACTION;

    -- -----------------------------------------------------
    -- 1. LOAD CRM CUSTOMER INFO
    -- -----------------------------------------------------
    TRUNCATE TABLE silver_crm_cust_info;
    
    INSERT INTO silver_crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname, 
        cst_marital_status, cst_gndr, cst_create_date
    )
    SELECT
        cst_id, cst_key, TRIM(cst_firstname), TRIM(cst_lastname),
        CASE 
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
        END,
        CASE 
            WHEN UPPER(TRIM(cst_gender)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gender)) = 'M' THEN 'Male'
            ELSE 'n/a'
        END,
        cst_create_date
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze_crm_cust_info
        WHERE cst_id IS NOT NULL AND cst_id > 0
    ) t 
    WHERE flag_last = 1;

    -- -----------------------------------------------------
    -- 2. LOAD CRM PRODUCT INFO
    -- -----------------------------------------------------
    TRUNCATE TABLE silver_crm_prd_info;
    
    INSERT INTO silver_crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'),
        SUBSTRING(prd_key, 7),
        prd_name,
        IFNULL(prd_cost, 0),
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END,
        CAST(prd_start_dt AS DATE),
        CAST(DATE_SUB(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt), INTERVAL 1 DAY) AS DATE)
    FROM bronze_crm_prd_info;

    -- -----------------------------------------------------
    -- 3. LOAD CRM SALES DETAILS
    -- -----------------------------------------------------
    TRUNCATE TABLE silver_crm_sales_details;
    
    INSERT INTO silver_crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, 
        sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price
    )
    SELECT
        TRIM(sls_ord_num), TRIM(sls_prd_key), sls_cust_id,
        CASE WHEN sls_order_dt = 0 OR CHAR_LENGTH(CAST(sls_order_dt AS CHAR)) != 8 THEN NULL ELSE STR_TO_DATE(CAST(sls_order_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_ship_dt = 0 OR CHAR_LENGTH(CAST(sls_ship_dt AS CHAR)) != 8 THEN NULL ELSE STR_TO_DATE(CAST(sls_ship_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_due_dt = 0 OR CHAR_LENGTH(CAST(sls_due_dt AS CHAR)) != 8 THEN NULL ELSE STR_TO_DATE(CAST(sls_due_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(IFNULL(sls_price, 0)) ELSE sls_sales END,
        sls_quantity,
        CASE WHEN sls_price IS NULL OR sls_price <= 0 THEN CASE WHEN sls_quantity IS NULL OR sls_quantity = 0 THEN 0 ELSE sls_sales / sls_quantity END ELSE sls_price END
    FROM bronze_crm_sales_details;

    -- -----------------------------------------------------
    -- 4. LOAD ERP CUSTOMER DATA
    -- -----------------------------------------------------
    TRUNCATE TABLE silver_erp_cust_az12;
    
    INSERT INTO silver_erp_cust_az12 (cid, bdate, gen)
    SELECT
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4) ELSE cid END,
        CASE WHEN bdate > CURDATE() THEN NULL ELSE CAST(bdate AS DATE) END,
        CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female' WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male' ELSE 'n/a' END
    FROM bronze_erp_cust_az12;

    -- -----------------------------------------------------
    -- 5. LOAD ERP LOCATION DATA
    -- -----------------------------------------------------
    TRUNCATE TABLE silver_erp_loc_a101;
    
    INSERT INTO silver_erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(REGEXP_REPLACE(cid, '[[:cntrl:]]', ''), '-', ''),
        CASE 
            WHEN UPPER(TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', ''))) = 'DE' THEN 'Germany'
            WHEN UPPER(TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', ''))) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', '')) = '' OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', ''))
        END
    FROM bronze_erp_loc_a101;

    -- -----------------------------------------------------
    -- 6. LOAD ERP PRODUCT CATEGORIES
    -- -----------------------------------------------------
    TRUNCATE TABLE silver_erp_px_cat_g1v2;
    
    INSERT INTO silver_erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT TRIM(id), TRIM(cat), TRIM(subcat), TRIM(maintenance)
    FROM bronze_erp_px_cat_g1v2;

    -- If everything succeeds, commit all changes permanently
    COMMIT;
    
    SELECT 'SUCCESS: Entire Silver Layer pipeline executed and committed successfully.' AS Pipeline_Status;

END //

DELIMITER ;

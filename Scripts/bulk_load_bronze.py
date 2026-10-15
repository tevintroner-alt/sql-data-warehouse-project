"""
PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
SECTION: BRONZE LAYER - AUTOMATED PYTHON INGESTION PIPELINE
DESCRIPTION: 
    Automated Python extraction-loading utility that maps raw CRM and ERP 
    system CSV datasets into localized MySQL Bronze landing tables. 

ORCHESTRATION STRATEGY:
    - Bypasses MySQL's structural stored procedure 'LOAD DATA LOCAL' compile-time 
      restrictions by processing dynamic execution calls at the client application layer.
    - Implements structural pre-flight evaluation checks to guarantee file existence 
      prior to initializing target table truncation routines.
    - Dynamically detects OS-dependent line-endings (\(\r\\)n vs \n) via byte-sampling.
    - Generates system logs ('bronze_load.log') to record processing outcomes.
"""

from pathlib import Path
from getpass import getpass
import logging
import mysql.connector

# Assumes this script is saved beside the datasets folder
DATA = Path(__file__).resolve().parent / "datasets"

logging.basicConfig(
    filename="bronze_load.log",
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

# Matrix containing target table schema destinations, relative file system positions, and column mapping logic
loads = [
    (
        "bronze_crm_cust_info",
        DATA / "source_crm" / "cust_info.csv",
        """(cst_id, cst_key, cst_firstname, cst_lastname,
        cst_marital_status, cst_gender, @raw_date)
        SET cst_create_date =
        STR_TO_DATE(NULLIF(@raw_date, ''), '%Y-%m-%d')"""
    ),
    (
        "bronze_crm_prd_info",
        DATA / "source_crm" / "prd_info.csv",
        """(prd_id, prd_key, prd_name, prd_cost,
        prd_line, prd_start_dt, prd_end_dt)"""
    ),
    (
        "bronze_crm_sales_details",
        DATA / "source_crm" / "sales_details.csv",
        """(sls_ord_num, sls_prd_key, sls_cust_id,
        sls_order_dt, sls_ship_dt, sls_due_dt,
        sls_sales, sls_quantity, sls_price)"""
    ),
    (
        "bronze_erp_cust_az12",
        DATA / "source_erp" / "CUST_AZ12.csv",
        "(CID, BDATE, GEN)"
    ),
    (
        "bronze_erp_loc_a101",
        DATA / "source_erp" / "LOC_A101.csv",
        "(CID, CNTRY)"
    ),
    (
        "bronze_erp_px_cat_g1v2",
        DATA / "source_erp" / "PX_CAT_G1V2.csv",
        "(ID, CAT, SUBCAT, MAINTENANCE)"
    )
]

def main():
    # Pre-flight evaluation check: Verify all raw files exist before database truncation routines begin
    missing = [
        str(path) for _, path, _ in loads if not path.is_file()
    ]
    if missing:
        raise FileNotFoundError(
            "CSV file(s) not found:\n" + "\n".join(missing)
        )

    password = getpass("Enter your MySQL password: ")

    # Initialize connection parameter bindings with local file loading options enabled
    connection = mysql.connector.connect(
        host="localhost",
        port=3306,
        user="root",
        password=password,
        database="DataWarehouse",
        allow_local_infile=True
    )

    try:
        cursor = connection.cursor()

        print("\nStarting Bronze-layer ingestion...")

        # Purge pre-existing landing metrics to ensure full history refresh constraints are preserved
        for table, _, _ in loads:
            cursor.execute(f"TRUNCATE TABLE `{table}`")
            print(f"Cleared {table}")

        # Stream file contents directly using local file mapping syntax rules
        for table, path, columns in loads:
            with path.open("rb") as file:
                sample = file.read(4096)

            # Evaluate system source file carriage returns dynamically
            line_ending = r"\(\r\\)n" if b"\(\r\\)n" in sample else r"\n"
            file_path = path.resolve().as_posix().replace("'", "''")

            sql = f"""
                LOAD DATA LOCAL INFILE '{file_path}'
                INTO TABLE `{table}`
                FIELDS TERMINATED BY ','
                OPTIONALLY ENCLOSED BY '"'
                LINES TERMINATED BY '{line_ending}'
                IGNORE 1 LINES
                {columns}
            """

            print(f"Loading {path.name}...")
            cursor.execute(sql)
            print(f"Loaded {cursor.rowcount:,} rows into {table}")

        # Post-ingestion verification checking: Print exact database catalog row metrics
        print("\nBRONZE TABLE ROW COUNTS")
        print("-" * 40)

        for table, _, _ in loads:
            cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
            count = cursor.fetchone()[0]
            print(f"{table}: {count:,}")

        logging.info("Bronze ingestion completed successfully")
        print("\nAll six CSV files processed successfully.")

    except Exception:
        logging.exception("Bronze ingestion failed")
        raise

    finally:
        if "cursor" in locals():
            cursor.close()
        connection.close()
        print("MySQL connection closed.")

if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"\nERROR: {error}")

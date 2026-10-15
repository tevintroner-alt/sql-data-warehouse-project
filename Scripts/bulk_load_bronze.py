# =================================================================================
# PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
# SECTION: BRONZE LAYER - PYTHON AUTOMATED INGESTION ORCHESTRATOR
# DESCRIPTION: 
#     Robust Python orchestration utility that performs pre-flight assertions,
#     database connectivity confirmation, metadata logging, and case-insensitive
#     bulk file streaming via the Local Infile data transfer mechanism.
# =================================================================================

from pathlib import Path
from getpass import getpass
import sys
import mysql.connector

# =========================================================
# 1. CONFIGURATION
# =========================================================

HOST = "localhost"
PORT = 3306
USER = "root"
DATABASE = "DataWarehouse"

# Assumes this script is in the same folder as "datasets"
DATA_FOLDER = Path(__file__).resolve().parent / "datasets"

TABLES = [
    "bronze_crm_cust_info",
    "bronze_crm_prd_info",
    "bronze_crm_sales_details",
    "bronze_erp_cust_az12",
    "bronze_erp_loc_a101",
    "bronze_erp_px_cat_g1v2",
]

# CSV files and their destination columns
LOADS = [
    (
        "bronze_crm_cust_info",
        "source_crm/cust_info.csv",
        """(cst_id, cst_key, cst_firstname, cst_lastname,
           cst_marital_status, cst_gender, @raw_date)
           SET cst_create_date =
           STR_TO_DATE(NULLIF(@raw_date, ''), '%Y-%m-%d')"""
    ),
    (
        "bronze_crm_prd_info",
        "source_crm/prd_info.csv",
        """(prd_id, prd_key, prd_name, prd_cost,
           prd_line, prd_start_dt, prd_end_dt)"""
    ),
    (
        "bronze_crm_sales_details",
        "source_crm/sales_details.csv",
        """(sls_ord_num, sls_prd_key, sls_cust_id,
           sls_order_dt, sls_ship_dt, sls_due_dt,
           sls_sales, sls_quantity, sls_price)"""
    ),
    (
        "bronze_erp_cust_az12",
        "source_erp/CUST_AZ12.csv",
        "(CID, BDATE, GEN)"
    ),
    (
        "bronze_erp_loc_a101",
        "source_erp/LOC_A101.csv",
        "(CID, CNTRY)"
    ),
    (
        "bronze_erp_px_cat_g1v2",
        "source_erp/PX_CAT_G1V2.csv",
        "(ID, CAT, SUBCAT, MAINTENANCE)"
    ),
]


# =========================================================
# 2. CHECK FILES BEFORE TOUCHING THE DATABASE
# =========================================================

def check_files():
    missing = []

    for _, relative_path, _ in LOADS:
        path = DATA_FOLDER / relative_path

        if not path.is_file():
            missing.append(str(path))

    if missing:
        raise FileNotFoundError(
            "These CSV files could not be found:\n"
            + "\n".join(missing)
        )


# =========================================================
# 3. CONNECT, LOAD, COMMIT AND VERIFY
# =========================================================

def main():
    check_files()

    password = getpass("Enter your MySQL password: ")

    connection = None
    cursor = None

    try:
        connection = mysql.connector.connect(
            host=HOST,
            port=PORT,
            user=USER,
            password=password,
            database=DATABASE,
            allow_local_infile=True
        )

        cursor = connection.cursor()

        # Print the identity of the actual MySQL server
        cursor.execute("""
            SELECT
                @@hostname,
                @@port,
                DATABASE(),
                @@datadir,
                @@server_uuid
        """)

        details = cursor.fetchone()

        print("\nCONNECTED TO MYSQL")
        print("-------------------")
        print("Host:", details[0])
        print("Port:", details[1])
        print("Database:", details[2])
        print("Data directory:", details[3])
        print("Server UUID:", details[4])

        # Enforce case-insensitive evaluation check to support Windows file system conventions
        if details[2].lower() != DATABASE.lower():
            raise RuntimeError(
                f"Wrong database: expected {DATABASE}, "
                f"connected to {details[2]}"
            )

        # Confirm all destination tables exist
        cursor.execute("SHOW TABLES")
        existing_tables = {row[0].lower() for row in cursor.fetchall()}

        missing_tables = [
            table for table in TABLES
            if table.lower() not in existing_tables
        ]

        if missing_tables:
            raise RuntimeError(
                "Missing destination tables: "
                + ", ".join(missing_tables)
            )

        # Clear old data before reloading
        print("\nCLEARING BRONZE TABLES")

        for table in TABLES:
            cursor.execute(f"TRUNCATE TABLE `{table}`")
            print(f"Cleared: {table}")

        # Load all six CSV files
        print("\nLOADING CSV FILES")

        for table, relative_path, columns in LOADS:
            file_path = (DATA_FOLDER / relative_path).resolve()

            # Detect Windows or Unix line endings
            with file_path.open("rb") as file:
                sample = file.read(4096)

            ending = r"\(\r\\)n" if b"\(\r\\)n" in sample else r"\n"

            # Escape single quotes in the absolute file path
            safe_path = file_path.as_posix().replace("'", "''")

            sql = f"""
                LOAD DATA LOCAL INFILE '{safe_path}'
                INTO TABLE `{table}`
                FIELDS TERMINATED BY ','
                OPTIONALLY ENCLOSED BY '"'
                LINES TERMINATED BY '{ending}'
                IGNORE 1 LINES
                {columns}
            """

            print(f"Loading {relative_path}...")
            cursor.execute(sql)
            
            # Consume result tokens to clear network interfaces safely
            while cursor.nextset():
                pass
                
            print("CSV processed.")

        # Persist changes before checking final counts
        connection.commit()

        # Verify the actual rows stored in MySQL
        print("\nFINAL DATABASE VERIFICATION")
        print("----------------------------")

        all_counts_valid = True

        for table in TABLES:
            cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
            count = cursor.fetchone()[0]

            print(f"{table}: {count:,} rows")

            if count == 0:
                all_counts_valid = False

        if not all_counts_valid:
            raise RuntimeError(
                "At least one table is empty. "
                "Check the table mapping and CSV contents."
            )

        print("\nSUCCESS: All six tables contain rows.")
        print("The data has been committed to MySQL.")
        print(
            "Keep the Server UUID above for comparison "
            "with MySQL Workbench."
        )

    except Exception as error:
        if connection is not None and connection.is_connected():
            try:
                connection.rollback()
            except mysql.connector.Error:
                pass

        print("\nPIPELINE FAILED")
        print("Error:", error)
        sys.exit(1)

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None and connection.is_connected():
            connection.close()

        print("\nMySQL connection closed.")


if __name__ == "__main__":
    main()

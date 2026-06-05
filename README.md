# 🏪 Urban Retail Co. — SQL Inventory Optimization

<div align="center">

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![SQL](https://img.shields.io/badge/SQL-Advanced-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![Status](https://img.shields.io/badge/Status-Complete-2ea44f?style=for-the-badge)

**An end-to-end SQL-driven inventory monitoring and optimization solution for a mid-sized retail chain**

*Designed, built, and documented by [Karan Kumar](https://github.com/karankumar02-12)*

</div>

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Business Problem](#-business-problem)
- [Dataset](#-dataset)
- [Database Design](#-database-design)
- [Project Architecture](#-project-architecture)
- [SQL Sections](#-sql-sections)
- [Key Findings](#-key-findings)
- [Power BI Dashboard](#-power-bi-dashboard)
- [SQL Concepts Used](#-sql-concepts-used)
- [Files in This Repository](#-files-in-this-repository)
- [How to Run This Project](#-how-to-run-this-project)
- [Skills Demonstrated](#-skills-demonstrated)
- [Author](#-author)

---

## 🎯 Project Overview

Urban Retail Co. is a rapidly expanding mid-sized retail chain operating **5 stores** across **4 regions**, selling **30 SKUs** across 5 product categories. The business was struggling with reactive, manual inventory decisions that resulted in frequent stockouts, chronic overstocking, and millions in lost revenue.

This project simulates the complete responsibilities of a **Data Scientist in a retail setting** — from raw data ingestion and database design, through advanced SQL analytics, to an interactive business intelligence dashboard.

> **The goal:** Transform 109,500 rows of raw inventory data into actionable business intelligence that prevents stockouts, reduces overstock, and drives smarter procurement decisions.

---

## 🚨 Business Problem

| Problem | Impact |
|---|---|
| Frequent stockouts of fast-moving products | Lost sales, poor customer experience |
| Overstocking of slow-moving items | Locked-up capital, high warehousing costs |
| No formalized reorder point system | Reactive ordering — always too late |
| Poor forecast accuracy (MAPE 12.8%) | Wrong quantities ordered every cycle |
| Zero visibility across stores and regions | No early warning system for shortages |

---

## 📊 Dataset

| Attribute | Value |
|---|---|
| **File** | `inventory_forecasting.csv` |
| **Rows** | 109,500 |
| **Columns** | 15 |
| **Period** | January 2022 — December 2023 |
| **Stores** | 5 (S001 — S005) |
| **Products** | 30 SKUs |
| **Categories** | Clothing, Electronics, Furniture, Groceries, Toys |
| **Regions** | East, West, North, South |

**Key columns:** Date, Store ID, Product ID, Category, Region, Inventory Level, Units Sold, Units Ordered, Demand Forecast, Price, Discount, Weather Condition, Holiday/Promotion, Competitor Pricing, Seasonality

---

## 🗄️ Database Design

### Normalization: Flat CSV → Star Schema (3NF)

The raw flat file was normalized into a **Star Schema** — a standard data warehouse design with one central fact table surrounded by dimension tables.

```
                    ┌─────────────┐
                    │  dim_date   │
                    │  730 rows   │
                    └──────┬──────┘
                           │
┌──────────────┐    ┌──────┴───────────┐    ┌───────────────┐
│  dim_store   │    │  fact_inventory  │    │  dim_product  │
│   5 rows     ├────┤  109,500 rows    ├────┤   30 rows     │
└──────────────┘    └─────────────────┘    └───────────────┘
```

| Table | Type | Rows | Primary Key | Description |
|---|---|---|---|---|
| `dim_store` | Dimension | 5 | store_id | Store ID and region |
| `dim_product` | Dimension | 30 | product_id | Product ID, category, price |
| `dim_date` | Dimension | 730 | date_key | Calendar attributes, season, holiday flag |
| `fact_inventory` | Fact | 109,500 | transaction_id | All daily inventory measurements |

### Why Star Schema?
- ✅ Eliminates data redundancy (region stored once, not 21,900 times)
- ✅ Enables fast analytical queries through optimized JOINs
- ✅ Enforces referential integrity through Foreign Key constraints
- ✅ Scales cleanly as new stores and products are added

---

## 🏗️ Project Architecture

```
RAW DATA (CSV)
     │
     ▼
STAGING TABLE (inventory_forecasting)
     │
     ▼ ETL Process (INSERT INTO ... SELECT)
     │
     ├──► dim_store      (5 rows)
     ├──► dim_product    (30 rows)
     ├──► dim_date       (730 rows)
     └──► fact_inventory (109,500 rows)
                │
                ▼
         6 Performance Indexes
                │
                ▼
    ┌───────────────────────┐
    │  10 SQL Analytical    │
    │  Sections             │
    └───────────┬───────────┘
                │
        ┌───────┴────────┐
        ▼                ▼
   Power BI          HTML Dashboard
   Dashboard         (Backup)
   (5 Pages)
        │
        ▼
  Executive Summary
  + PDF Documentation
```

---

## 📝 SQL Sections

The main SQL script is organized into **10 analytical sections**, each targeting a specific business question:

| Section | Title | Business Question |
|---|---|---|
| **0** | Schema Normalization | How do we structure the database correctly? |
| **1** | Indexing | How do we make queries fast at scale? |
| **2** | Stock Level Calculations | What is our current stock vs demand? |
| **3** | Low Inventory Detection | Which products need reordering RIGHT NOW? |
| **4** | Inventory Turnover Analysis | Which products are fast vs slow movers? |
| **5** | Overstock Detection | Where are we locking up capital in excess stock? |
| **6** | Demand Forecasting | How does demand shift by season and promotion? |
| **7** | Competitor Pricing | How does our pricing compare to competitors? |
| **8** | KPI Summary Dashboard | What are our headline business metrics? |
| **9** | Window Functions | How do we compute rolling trends and rankings? |
| **10** | Stock Adjustment Report | Exactly how much should we order per SKU? |

### Reorder Point Formula (Section 3)

The most business-critical calculation in the project:

```sql
-- ROP = (Avg Daily Sales × Lead Time) + Safety Stock
-- Safety Stock = Z-score × σ × √Lead Time
-- Lead Time = 7 days | Service Level = 95% | Z = 1.645

ROUND(
    avg_daily_sales * 7 
    + 1.645 * stddev_daily_sales * SQRT(7), 
0) AS reorder_point
```

---

## 🔍 Key Findings

<div align="center">

| KPI | Current | Target | Status |
|---|---|---|---|
| Stockout Rate | **5.06%** | < 3.0% | 🔴 Action Needed |
| Overstock Rate | **8.89%** | < 5.0% | 🟡 Monitor |
| Forecast MAPE | **12.8%** | < 8.0% | 🟡 Improve |
| SKUs with ROP | **0 of 30** | 30 of 30 | 🔴 Immediate |
| Holiday Demand Lift | **+19.2 units/day** | Predictable | 🟢 Leverage |

</div>

### 5 Key Business Insights

**1. Zero formalized reorder policies**
All 30 SKUs fall below their calculated safety-stock reorder point. Every procurement decision is reactive. This is the single highest-impact fix available.

**2. $8.5M estimated revenue lost to stockouts**
Furniture accounts for $4.3M despite having the fewest events — its $349 average unit price amplifies every missed sale. Frequency alone is a misleading metric.

**3. Electronics is the highest-risk category**
Lowest average inventory (137 units) combined with meaningful demand creates the highest per-unit revenue exposure from stockouts.

**4. Winter demand is 14% above baseline**
Average 105.2 units/day in Winter vs 91.8 in Autumn — a predictable, recurring spike that current inventory levels do not account for.

**5. Overstocking and stockouts coexist**
Electronics shows the highest overstock rate (~11%) AND the highest stockout risk simultaneously — meaning the wrong products are being overstocked while the right ones run out.

---

## 📈 Power BI Dashboard

A 5-page interactive dashboard connected **live to the MySQL database**:

| Page | Content |
|---|---|
| **1 — Executive Summary** | KPI cards (Stockout %, Overstock %, Records, Avg Sales) + Monthly trend 2022 vs 2023 |
| **2 — Stockout Analysis** | Stockout events by category + Revenue lost by category + Regional stockout rates |
| **3 — Inventory Health** | Inventory vs sales gap + Overstock rate + Seasonal inventory breakdown |
| **4 — Seasonal Demand** | Seasonal demand comparison + Category × season breakdown |
| **5 — Product Performance** | Category share donut + Inventory vs sales + Regional performance |

**DAX Measures built:**
- Stockout Rate %
- Overstock Rate %
- Total Records
- Avg Daily Sales
- Avg Inventory Level
- Total Units Sold
- Stockout Events
- Estimated Revenue Lost

---

## 💡 SQL Concepts Used

```
✅ Star Schema Design          ✅ CTEs (WITH clause)
✅ 3NF Normalization           ✅ CTE Chaining
✅ Foreign Key Constraints      ✅ Window Functions
✅ Composite Indexing           ✅ ROW_NUMBER() + PARTITION BY
✅ INSERT INTO ... SELECT       ✅ LAG() for MoM trends
✅ STR_TO_DATE()                ✅ RANK() for revenue ranking
✅ STDDEV() + SQRT()            ✅ ROWS BETWEEN (rolling avg)
✅ NULLIF() (zero protection)   ✅ CASE WHEN (multi-tier logic)
✅ GREATEST()                   ✅ Subqueries + Derived Tables
✅ NTILE() (quartile class.)    ✅ CORR() proxy analysis
✅ Aggregate Functions          ✅ Multi-column GROUP BY
✅ HAVING clause                ✅ UNION ALL
✅ Multi-table JOINs            ✅ Column + Table Aliasing
```

---

## 📁 Files in This Repository

```
urban-retail-inventory-sql/
│
├── README.md
│
├── sql/
│   └── urban_retail_scripts.sql     # Complete 10-section SQL script
│
├── data/
│   └── inventory_forecasting.csv    # Raw dataset (109,500 rows)
│
├── dashboard/
│   ├── Urban_Retail_Dashboard.pbix  # Power BI dashboard file
│   └── Urban_Retail_Dashboard.html  # Standalone HTML dashboard
│
└── docs/
    ├── Executive_Summary.md
    ├── Part1_Schema_and_Indexing.pdf
    ├── Part2_Stock_Level_Calculations.pdf
    ├── Part3_Low_Inventory_Detection.pdf
    ├── Part4_Inventory_Turnover_Analysis.pdf
    └── DataLoading_Guide.pdf
```

---

## 🚀 How to Run This Project

### Prerequisites
- MySQL 8.0 or higher
- MySQL Workbench (recommended)
- Power BI Desktop (for dashboard)

### Step 1 — Set Up the Database
```sql
CREATE DATABASE urban_retail_co;
USE urban_retail_co;
```

### Step 2 — Import Raw Data
```
1. Open MySQL Workbench
2. Use Table Data Import Wizard
3. Import inventory_forecasting.csv
   into table: inventory_forecasting
```

### Step 3 — Run the SQL Script
```
1. Open urban_retail_scripts.sql in MySQL Workbench
2. Run Section 0 (Schema) first
3. Run the INSERT scripts to populate tables
4. Run Section 1 (Indexes)
5. Run Sections 2-10 for all analytics
```

### Step 4 — Open the Dashboard
```
Power BI: Open Urban_Retail_Dashboard.pbix
          Connect to your local MySQL instance
          
HTML:     Open Urban_Retail_Dashboard.html
          in any browser — no setup needed
```

---

## 🛠️ Skills Demonstrated

| Category | Skills |
|---|---|
| **Database** | MySQL, Schema Design, Normalization, ETL, Indexing |
| **SQL** | Advanced Queries, Window Functions, CTEs, Aggregations |
| **Analytics** | KPI Development, Inventory Management, Forecasting |
| **Visualization** | Power BI, DAX Measures, Interactive Dashboards |
| **Business** | Retail Analytics, Supply Chain, Cost Analysis |
| **Documentation** | Technical Writing, Executive Summaries |

---

## 👨‍💻 Author

**Karan Kumar**

[![GitHub](https://img.shields.io/badge/GitHub-karankumar02--12-181717?style=for-the-badge&logo=github)](https://github.com/karankumar02-12)

---

<div align="center">

*Built as a complete end-to-end data science portfolio project*
*demonstrating SQL analytics, database design, and business intelligence*

⭐ **Star this repository if you found it useful!** ⭐

</div>

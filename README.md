# urban-retail-inventory-sql
SQL-based inventory optimization project     for Urban Retail Co. - stockout detection,     reorder point system, demand forecasting,     and Power BI dashboard using MySQL Star Schema
# Urban Retail Co. — SQL Inventory Optimization

## Project Overview
End-to-end SQL-driven inventory monitoring and 
optimization solution for a mid-sized retail chain 
operating 5 stores across 4 regions with 30 SKUs.

## Business Problem
Urban Retail Co. was experiencing:
- Frequent stockouts of fast-moving products
- Overstocking of slow-moving items  
- No formalized reorder point system
- Poor visibility across stores and categories

## Technical Stack
- MySQL — database and all analytical queries
- Power BI — interactive dashboard (5 pages)
- SQL — 10 analytical sections
- Star Schema — normalized database design

## Database Design
Normalized flat CSV (109,500 rows) into Star Schema:
- dim_store (5 rows)
- dim_product (30 rows)  
- dim_date (730 rows)
- fact_inventory (109,500 rows)

## Key Findings
| Metric | Value |
|--------|-------|
| Stockout Rate | 5.06% |
| Overstock Rate | 8.89% |
| Forecast MAPE | 12.8% |
| Revenue Lost to Stockouts | ~$8.5M |
| Holiday Demand Lift | +19.2 units/day |
| SKUs with Reorder Points | 0 of 30 |

## SQL Sections
1. Schema Normalization (3NF)
2. Indexing for Performance
3. Stock Level Calculations
4. Low Inventory Detection + ROP Formula
5. Inventory Turnover Analysis
6. Overstock Detection + Holding Cost
7. Demand Forecasting + Seasonal Analysis
8. Competitor Pricing Analysis
9. KPI Summary Dashboard Query
10. Window Functions + Stock Adjustment Report

## Key SQL Concepts Used
- CTEs (Common Table Expressions)
- Window Functions (ROW_NUMBER, LAG, RANK)
- Subqueries and Derived Tables
- Statistical Functions (STDDEV, SQRT)
- CASE WHEN for business logic
- NULLIF for division protection
- PERCENTILE via NTILE
- Star Schema JOINs
- Aggregate Functions

## Dashboard
Built in Power BI Desktop connected live to MySQL:
- Page 1: Executive Summary (KPI cards + trend)
- Page 2: Stockout Analysis
- Page 3: Inventory Health
- Page 4: Seasonal Demand
- Page 5: Product Performance

## Dataset
- Source: Synthetic retail dataset
- Records: 109,500 rows
- Period: January 2022 to December 2023
- Stores: 5 | Products: 30 | Categories: 5

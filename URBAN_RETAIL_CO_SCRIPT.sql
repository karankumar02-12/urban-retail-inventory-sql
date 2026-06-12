-- ----------------------------------------------------------------------------
-- URBAN RETAIL CO.: INVENTORY OPTIMIZATION 
-- SOLVIING INVENTORY INEFFICIENCIES 
-- ----------------------------------------------------------------------------

-- ---------- Create and use Database ----------
CREATE DATABASE urban_retail_co;
USE urban_retail_co;

-- ---------------------------------------------------
-- CREATE SCHEMA NORMALIZATION (3NF)
-- Raw flat file to relational tables
-- ---------------------------------------------------

-- ---------- dimension: store table ----------
CREATE TABLE dim_store (
  store_id VARCHAR(10) PRIMARY KEY,
  region   VARCHAR(20) NOT NULL
);

-- ---------- dimension: product table ----------
CREATE TABLE dim_product (
  product_id VARCHAR(10)   PRIMARY KEY,
  category   VARCHAR(30)   NOT NULL,
  base_price DECIMAL(10,2)
);

-- ---------- dimension: date table ----------
CREATE TABLE dim_date (
  date_key         DATE        PRIMARY KEY,
  year             SMALLINT    NOT NULL,
  month            TINYINT     NOT NULL,
  quarter          TINYINT     NOT NULL,
  season           VARCHAR(10) NOT NULL,   -- Winter / Spring / Summer / Autumn
  is_holiday_promo BOOLEAN     NOT NULL
);

-- ---------- fact: inventory table ----------
-- Central fact table: all measurable events live here
CREATE TABLE fact_inventory (
  transaction_id     BIGINT       AUTO_INCREMENT PRIMARY KEY,
  date_key           DATE         NOT NULL,
  store_id           VARCHAR(10)  NOT NULL,
  product_id         VARCHAR(10)  NOT NULL,
  inventory_level    INT          NOT NULL,
  units_sold         INT          NOT NULL,
  units_ordered      INT          NOT NULL,
  demand_forecast    DECIMAL(10,2),
  price              DECIMAL(10,2),
  discount_pct       TINYINT,                                 -- 0–100
  weather_condition  VARCHAR(15),
  competitor_pricing DECIMAL(10,2),
 
-- Foreign Keys
  FOREIGN KEY (date_key)   REFERENCES dim_date(date_key),
  FOREIGN KEY (store_id)   REFERENCES dim_store(store_id),
  FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
);


-- ---------------------------------------------------
-- INSERTING DATA INTO NEW TABLES  
-- ---------------------------------------------------

-- ---------- populate dim_store table ----------
-- dim_store - one region per store
INSERT INTO dim_store (store_id, region)
SELECT 
  `Store ID`,
  MAX(Region)                          -- picks one region per store
FROM inventory_forecasting
GROUP BY `Store ID`;

-- Fix regions to be meaningful and distinct
UPDATE dim_store SET region = 'East'  WHERE store_id = 'S001';
UPDATE dim_store SET region = 'West'  WHERE store_id = 'S002';
UPDATE dim_store SET region = 'North' WHERE store_id = 'S003';
UPDATE dim_store SET region = 'South' WHERE store_id = 'S004';
UPDATE dim_store SET region = 'East'  WHERE store_id = 'S005';

-- ---------- populate dim_product table ----------
INSERT INTO dim_product (product_id, category, base_price)
SELECT 
  `Product ID`,
  MAX(Category),
  ROUND(AVG(Price), 2)
FROM inventory_forecasting
GROUP BY `Product ID`;

-- ---------- populate dim_date table ----------
INSERT INTO dim_date (date_key, year, month, quarter, season, is_holiday_promo)
SELECT 
  STR_TO_DATE(`Date`, '%Y-%m-%d')               AS date_key,
  MAX(YEAR(STR_TO_DATE(`Date`, '%Y-%m-%d')))    AS year,
  MAX(MONTH(STR_TO_DATE(`Date`, '%Y-%m-%d')))   AS month,
  MAX(QUARTER(STR_TO_DATE(`Date`, '%Y-%m-%d'))) AS quarter,
  MAX(Seasonality)                              AS season,
  MAX(`Holiday/Promotion`)                      AS is_holiday_promo
FROM inventory_forecasting
GROUP BY STR_TO_DATE(`Date`, '%Y-%m-%d');

-- ---------- populate fact_inventory table ---------- 
INSERT INTO fact_inventory (
  date_key, store_id, product_id,
  inventory_level, units_sold, units_ordered,
  demand_forecast, price, discount_pct,
  weather_condition, competitor_pricing
)
SELECT
  STR_TO_DATE(`Date`, '%Y-%m-%d'),
  `Store ID`,
  `Product ID`,
  `Inventory Level`,
  `Units Sold`,
  `Units Ordered`,
  `Demand Forecast`,
  Price,
  Discount,
  `Weather Condition`,
  `Competitor Pricing`
FROM inventory_forecasting;

-- verification 
SELECT 'dim_store'      AS table_name, COUNT(*) AS row_count FROM dim_store
UNION ALL
SELECT 'dim_product'    AS table_name, COUNT(*) AS row_count FROM dim_product
UNION ALL
SELECT 'dim_date'       AS table_name, COUNT(*) AS row_count FROM dim_date
UNION ALL
SELECT 'fact_inventory' AS table_name, COUNT(*) AS row_count FROM fact_inventory;


-- ---------------------------------------------------------
-- INDEXING FOR QUERY PERFORMANCE
-- ---------------------------------------------------------

-- composite index for the most common filter pattern (store + date + product)
CREATE INDEX idx_fact_store_date   ON fact_inventory (store_id, date_key);
CREATE INDEX idx_fact_product_date ON fact_inventory (product_id, date_key);
CREATE INDEX idx_fact_category     ON dim_product (category);
CREATE INDEX idx_fact_region       ON dim_store (region);
CREATE INDEX idx_fact_season       ON dim_date (season);
CREATE INDEX idx_fact_holiday      ON dim_date (is_holiday_promo);


-- -----------------------------------------------------------------------------------------------
-- STOCK LEVEL CALCULATIONS 
-- Gives a real-time view of inventory across every store/product combination
-- -----------------------------------------------------------------------------------------------

-- ---------- inventory snapshot (latest date in dataset) ----------
SELECT
  s.store_id,
  s.region,
  p.product_id,
  p.category,
  f.inventory_level                     AS current_stock,
  f.units_sold                          AS last_day_sold,
  f.demand_forecast                     AS forecasted_demand,
  f.inventory_level - f.demand_forecast AS surplus_deficit
FROM fact_inventory f
JOIN dim_store      s ON f.store_id = s.store_id
JOIN dim_product    p ON f.product_id = p.product_id
JOIN dim_date       d ON f.date_key = d.date_key
WHERE d.date_key = (SELECT MAX(date_key) FROM dim_date)
ORDER BY surplus_deficit ASC;                                 -- most critical deficit first

-- ---------- Aggregated stock levels by store and category ----------
SELECT
  s.store_id,
  s.region,
  p.category,
  ROUND(AVG(f.inventory_level), 1) AS avg_inventory,
  ROUND(AVG(f.units_sold),      1) AS avg_daily_sales,
  SUM(f.units_sold)                AS total_units_sold,
  ROUND(AVG(f.demand_forecast), 1) AS avg_demand_forecast
FROM fact_inventory f
JOIN dim_store      s ON f.store_id = s.store_id
JOIN dim_product    p ON f.product_id = p.product_id
GROUP BY s.store_id, s.region, p.category
ORDER BY s.store_id, total_units_sold DESC;


-- -----------------------------------------------------------------------------
-- LOW INVENTORY DETECTION (REORDER ALERT SYSTEM)
-- Flags any store-product pair whose current stock falls below reorder point
-- -----------------------------------------------------------------------------

-- ---------- reorder point alert system ----------
-- Reorder point (ROP) estimation
-- ROP = (Avg Daily Sales*Lead Time) + Safety Stock
-- Assumptions: Lead Time = 7 days, Service Level = 95% (Z = 1.645)

WITH daily_stats AS (
  SELECT
    store_id,
	product_id,
	AVG(units_sold)    AS avg_daily_sales,
	STDDEV(units_sold) AS stddev_daily_sales,
	COUNT(*)           AS observation_days
  FROM fact_inventory
  GROUP BY store_id, product_id
),
reorder_calc AS (
  SELECT
	store_id,
	product_id,
	ROUND(avg_daily_sales, 2)                                            AS avg_daily_sales,
	ROUND(stddev_daily_sales, 2)                                         AS std_daily_sales,
	ROUND(avg_daily_sales * 7, 0)                                        AS demand_during_lead_time,
	ROUND(1.645 * stddev_daily_sales * SQRT(7), 0)                       AS safety_stock,
	ROUND(avg_daily_sales * 7 + 1.645 * stddev_daily_sales * SQRT(7), 0) AS reorder_point
  FROM daily_stats
)
  SELECT 
	rc.*,
	fi.inventory_level                              AS current_inventory,
	CASE WHEN fi.inventory_level < rc.reorder_point
	     THEN 'REORDER NOW' ELSE 'OK' END           AS alert_status,
	rc.reorder_point - fi.inventory_level           AS units_short
  FROM reorder_calc rc
  JOIN (
	SELECT store_id, product_id, inventory_level,
	  ROW_NUMBER() OVER (
		PARTITION BY store_id, product_id
		ORDER BY date_key DESC
	  ) AS rn
	FROM fact_inventory
) fi ON fi.store_id = rc.store_id
     AND fi.product_id = rc.product_id
     AND fi.rn = 1
ORDER BY units_short DESC;

-- ---------- Historical stockout events ----------
SELECT
  f.date_key,
  s.store_id,
  s.region,
  p.product_id,
  p.category,
  f.inventory_level,
  f.units_sold,
  f.demand_forecast,
  f.demand_forecast - f.units_sold AS stock_shortfall
FROM fact_inventory f
JOIN dim_store      s ON f.store_id = s.store_id
JOIN dim_product    p ON f.product_id = p.product_id
WHERE f.inventory_level < f.units_sold
ORDER BY stock_shortfall ASC;

-- ---------- Stockout frequency by category ----------
SELECT
  p.category,
  COUNT(*)                                                    AS stockout_events,
  SUM(f.units_sold - f.inventory_level)                       AS lost_units,
  ROUND(AVG(f.price), 2)                                      AS avg_price,
  ROUND(SUM((f.units_sold - f.inventory_level) * f.price), 2) AS estimated_revenue_lost
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
WHERE f.inventory_level < f.units_sold
GROUP BY p.category
ORDER BY estimated_revenue_lost DESC;


-- -----------------------------------------------------------------------------------------
-- INVENTORY TURNOVER ANALYSIS
-- Turnover = Units Sold / Average Inventory
-- Higher turnover: fast-moving / efficient; Lower turnover: slow-moving / overstock risk
-- -----------------------------------------------------------------------------------------

-- ---------- Annual turnover by category ----------
SELECT
  p.category,
  d.year,
  ROUND(AVG(f.inventory_level), 1)                                                AS avg_inventory,
  SUM(f.units_sold)                                                               AS total_units_sold,
  ROUND(SUM(f.units_sold) / NULLIF(AVG(f.inventory_level), 0), 2)                 AS inventory_turnover_ratio,
  ROUND(365.0 / NULLIF(SUM(f.units_sold) / NULLIF(AVG(f.inventory_level),0),0),1) AS days_inventory_outstanding
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
JOIN dim_date        d ON f.date_key   = d.date_key
GROUP BY p.category, d.year
ORDER BY d.year, inventory_turnover_ratio DESC;

-- ----------- Product-level turnover with fast/slow mover classification ----------
WITH product_turnover AS (
  SELECT
	p.product_id,
	p.category,
	ROUND(SUM(f.units_sold) / NULLIF(AVG(f.inventory_level), 0), 2) AS turnover_ratio,
	ROUND(AVG(f.inventory_level), 1)                                AS avg_inventory,
	SUM(f.units_sold)                                               AS total_sold
  FROM fact_inventory  f
  JOIN dim_product     p ON f.product_id = p.product_id
  GROUP BY p.product_id, p.category
),
ranked AS (
  SELECT *,
	NTILE(4) OVER (ORDER BY turnover_ratio ASC) AS quartile
  FROM product_turnover
)
SELECT
  product_id,
  category,
  turnover_ratio,
  avg_inventory,
  total_sold,
  CASE
	WHEN quartile = 4 THEN 'Fast Mover'
	WHEN quartile = 1 THEN 'Slow Mover'
	ELSE 'Normal'
  END AS mover_classification
FROM ranked
ORDER BY turnover_ratio DESC;


-- ------------------------------------------------------------------
-- OVERSTOCK DETECTION & HOLDING COST ANALYSIS
-- ------------------------------------------------------------------

-- ---------- Chronic overstock by product (inventory > 2*demand forecast) ----------
SELECT
  p.product_id,
  p.category,
  s.store_id,
  s.region,
  ROUND(AVG(f.inventory_level), 1)                                                    AS avg_inventory,
  ROUND(AVG(f.demand_forecast), 1)                                                    AS avg_forecast,
  ROUND(AVG(f.inventory_level) - AVG(f.demand_forecast), 1)                           AS avg_excess_units,
  COUNT(CASE WHEN f.inventory_level > 2 * f.demand_forecast THEN 1 END)               AS overstock_days,
  COUNT(*)                                                                            AS total_days,
  ROUND(100.0 * COUNT(CASE WHEN f.inventory_level > 2 * f.demand_forecast THEN 1 END)
        / COUNT(*), 1)                                                                AS overstock_pct
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
JOIN dim_store       s ON f.store_id   = s.store_id
GROUP BY p.product_id, p.category, s.store_id, s.region
HAVING overstock_pct > 10
ORDER BY overstock_pct DESC;

-- ---------- Holding cost estimate ----------
-- (assuming 25% annual carrying cost rate)
WITH excess_inventory AS (
  SELECT
	p.category,
	AVG(GREATEST(f.inventory_level - f.demand_forecast, 0)) AS avg_excess_units,
	AVG(f.price)                                            AS avg_price
  FROM fact_inventory  f
  JOIN dim_product     p ON f.product_id = p.product_id
  GROUP BY p.category
)
SELECT
  category,
  ROUND(avg_excess_units, 1)                          AS avg_excess_units,
  ROUND(avg_price, 2)                                 AS avg_unit_price,
  ROUND(avg_excess_units * avg_price * 0.25, 2)       AS annual_holding_cost_per_sku,
  ROUND(avg_excess_units * avg_price * 0.25 * 30, 2)  AS fleet_wide_holding_cost
FROM excess_inventory
ORDER BY fleet_wide_holding_cost DESC;


-- -------------------------------------------------------------------
-- DEMAND FORECASTING & SEASONAL TREND ANALYSIS
-- -------------------------------------------------------------------

-- ---------- Seasonal demand patterns by category ----------
SELECT
  p.category,
  d.season,
  ROUND(AVG(f.units_sold),      1) AS avg_units_sold,
  ROUND(AVG(f.demand_forecast), 1) AS avg_demand_forecast,
  ROUND(AVG(f.inventory_level), 1) AS avg_inventory_level,
  COUNT(*)                         AS observations
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
JOIN dim_date        d ON f.date_key   = d.date_key
GROUP BY p.category, d.season
ORDER BY p.category, avg_units_sold DESC;

-- ---------- Holiday/promotion impact on demand ----------
SELECT
  p.category,
  d.is_holiday_promo,
  ROUND(AVG(f.units_sold),      1) AS avg_units_sold,
  ROUND(AVG(f.inventory_level), 1) AS avg_inventory,
  ROUND(AVG(f.discount_pct),    1) AS avg_discount_pct
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
JOIN dim_date        d ON f.date_key   = d.date_key
GROUP BY p.category, d.is_holiday_promo
ORDER BY p.category, d.is_holiday_promo DESC;

-- ---------- Month-over-month demand trend ----------
SELECT
  p.category,
  d.year,
  d.month,
  ROUND(AVG(f.units_sold), 1) AS avg_units_sold,
  ROUND(AVG(f.units_sold) - LAG(AVG(f.units_sold), 1)
		OVER (PARTITION BY p.category ORDER BY d.year, d.month), 2) AS mom_change
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
JOIN dim_date        d ON f.date_key   = d.date_key
GROUP BY p.category, d.year, d.month
ORDER BY p.category, d.year, d.month;

-- ---------- Weather-driven demand variation ----------
SELECT
  f.weather_condition,
  p.category,
  ROUND(AVG(f.units_sold), 2)    AS avg_units_sold,
  ROUND(STDDEV(f.units_sold), 2) AS stddev_units_sold,
  COUNT(*)                       AS observations
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
GROUP BY f.weather_condition, p.category
ORDER BY p.category, avg_units_sold DESC;


-- ----------------------------------------------------------------
-- COMPETITOR PRICING ANALYSIS
-- ----------------------------------------------------------------

-- ---------- Price gap analysis ----------
-- Our price vs competitor price by category
SELECT
  p.category,
  ROUND(AVG(f.price), 2)                                   AS our_avg_price,
  ROUND(AVG(f.competitor_pricing), 2)                      AS competitor_avg_price,
  ROUND(AVG(f.price) - AVG(f.competitor_pricing), 2)       AS price_gap,
  ROUND(100.0 * (AVG(f.price) - AVG(f.competitor_pricing))
		/ NULLIF(AVG(f.competitor_pricing), 0), 1)         AS price_premium_pct
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY price_premium_pct DESC;

-- ---------- Price gap vs sales ----------
-- avg price gap alongside avg sales for visual comparison
SELECT
  p.category,
  ROUND(AVG(f.price - f.competitor_pricing), 2) AS avg_price_gap,
  ROUND(AVG(f.units_sold), 2)                   AS avg_units_sold,
  CASE
	WHEN AVG(f.price - f.competitor_pricing) > 5
		 AND AVG(f.units_sold) < 90  THEN 'High Premium — Low Sales (Elastic)'
	WHEN AVG(f.price - f.competitor_pricing) > 5
		 AND AVG(f.units_sold) >= 90 THEN 'High Premium — Strong Sales (Inelastic)'
	WHEN AVG(f.price - f.competitor_pricing) <= 5 THEN 'Competitive Pricing'
	ELSE 'Review Needed'
  END AS price_elasticity_signal
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY avg_price_gap DESC;


-- -----------------------------------------------------------
-- KPI SUMMARY DASHBOARD 
-- -----------------------------------------------------------
SELECT
  COUNT(*)                                                                                 AS total_records,
  ROUND(AVG(f.inventory_level), 1)                                                         AS avg_inventory,
  ROUND(AVG(f.units_sold), 1)                                                              AS avg_daily_sales,
  ROUND(100.0 * SUM(CASE WHEN f.inventory_level < f.units_sold THEN 1 ELSE 0 END)
		/ COUNT(*), 2)                                                                     AS stockout_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN f.inventory_level > 2 * f.demand_forecast THEN 1 ELSE 0 END)
		/ COUNT(*), 2)                                                                     AS overstock_rate_pct,
  ROUND(AVG(ABS(f.units_sold - f.demand_forecast)
		/ NULLIF(f.demand_forecast, 0)) * 100, 1)                                          AS avg_forecast_mape_pct,
  ROUND(AVG(f.price - f.competitor_pricing), 2)                                            AS avg_price_premium,
  ROUND(
	AVG(CASE WHEN d.is_holiday_promo = 1 THEN f.units_sold ELSE NULL END) -
	AVG(CASE WHEN d.is_holiday_promo = 0 THEN f.units_sold ELSE NULL END)
  , 1)                                                                                     AS holiday_demand_lift
FROM fact_inventory  f
JOIN dim_date        d ON f.date_key = d.date_key;


-- ----------------------------------------------------------
-- WINDOW FUNCTION ANALYTICS
-- Running totals, rankings, and cumulative metrics
-- ----------------------------------------------------------

-- ---------- Rank products by revenue within each category ----------
SELECT
    p.category,
    p.product_id,
    ROUND(SUM(f.units_sold * f.price), 2)                              AS total_revenue,
    RANK() OVER (PARTITION BY p.category
                 ORDER BY SUM(f.units_sold * f.price) DESC)            AS revenue_rank,
    ROUND(100.0 * SUM(f.units_sold * f.price)
          / SUM(SUM(f.units_sold * f.price)) OVER (PARTITION BY p.category), 1) AS pct_of_category_revenue
FROM fact_inventory  f
JOIN dim_product     p ON f.product_id = p.product_id
GROUP BY p.category, p.product_id
ORDER BY p.category, revenue_rank;

-- ---------- 7-day rolling average sales ----------
SELECT
    f.date_key,
    f.product_id,
    f.units_sold,
    ROUND(AVG(f.units_sold) OVER (
        PARTITION BY f.product_id
        ORDER BY f.date_key
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7d_avg_sales,
    ROUND(AVG(f.inventory_level) OVER (
        PARTITION BY f.product_id
        ORDER BY f.date_key
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7d_avg_inventory
FROM fact_inventory f
ORDER BY f.product_id, f.date_key;

-- ---------- Cumulative stockouts per store ----------
SELECT
    s.store_id,
    f.date_key,
    SUM(CASE WHEN f.inventory_level < f.units_sold THEN 1 ELSE 0 END)
        OVER (PARTITION BY s.store_id ORDER BY f.date_key) AS cumulative_stockouts,
    f.inventory_level,
    f.units_sold
FROM fact_inventory  f
JOIN dim_store       s ON f.store_id = s.store_id
ORDER BY s.store_id, f.date_key;


-- ----------------------------------------------------------------------
-- RECOMMENDED STOCK ADJUSTMENT REPORT
-- ----------------------------------------------------------------------

-- ---------- how much to order for each product-store pair ----------
WITH stats AS (
    SELECT
        f.store_id,
        f.product_id,
        AVG(f.units_sold)      AS avg_daily_sales,
        STDDEV(f.units_sold)   AS stddev_sales,
        MAX(f.inventory_level) AS max_inventory
    FROM fact_inventory f
    GROUP BY f.store_id, f.product_id
),
latest_inventory AS (
    SELECT store_id, product_id, inventory_level
    FROM (
        SELECT store_id, product_id, inventory_level,
               ROW_NUMBER() OVER (
                   PARTITION BY store_id, product_id
                   ORDER BY date_key DESC
               ) AS rn
        FROM fact_inventory
    ) ranked
    WHERE rn = 1
),
targets AS (
    SELECT
        s.store_id,
        s.product_id,
        ROUND(s.avg_daily_sales, 2)                                            AS avg_daily_sales,
        ROUND(s.avg_daily_sales * 7 + 1.645 * s.stddev_sales * SQRT(7), 0)   AS reorder_point,
        ROUND(s.avg_daily_sales * 30, 0)                                       AS target_stock_30d,
        li.inventory_level                                                     AS current_stock
    FROM stats s
    JOIN latest_inventory li
      ON s.store_id   = li.store_id
     AND s.product_id = li.product_id
)
SELECT
    t.store_id,
    t.product_id,
    p.category,
    t.current_stock,
    t.reorder_point,
    t.target_stock_30d                                         AS optimal_stock_30d,
    GREATEST(t.target_stock_30d - t.current_stock, 0)         AS recommended_order_qty,
    CASE
        WHEN t.current_stock < t.reorder_point              THEN 'URGENT — Order Immediately'
        WHEN t.current_stock < t.reorder_point * 1.25      THEN 'WARNING — Order Soon'
        WHEN t.current_stock > t.target_stock_30d * 2      THEN 'OVERSTOCK — Pause Orders'
        ELSE 'OPTIMAL'
    END AS action_flag
FROM targets       t
JOIN dim_product   p ON t.product_id = p.product_id
ORDER BY
    CASE action_flag
        WHEN 'URGENT — Order Immediately' THEN 1
        WHEN 'WARNING — Order Soon'       THEN 2
        WHEN 'OVERSTOCK — Pause Orders'   THEN 3
        ELSE 4
    END,
    t.store_id;
    
-- ------------------------------ END OF SCRIPT -----------------------------------------
  
      
      




 



  


  

-- RFM Analysis (Recency, Frequency, Monetary Value) / Identify high-value, one-time, and churn-risk customers
WITH transaction_summary AS (
Select Customer_ID,
MAX(Transaction_Date) AS last_purchase_date,
DATEDIFF(CURDATE(),MAX(Transaction_Date)) AS recency,
COUNT(*) AS frequent_purchases,
SUM(Price) AS monetary_value
FROM transactions_data1
GROUP BY Customer_ID)
Select *,
CASE 
When recency <= 30 AND frequent_purchases >= 5 AND monetary_value >= 7000 THEN 'High-Value'
When frequent_purchases = 1 THEN 'One-Time'
When recency >= 200 AND frequent_purchases <=2 THEN 'Churn-Risk'
ELSE 'Others'
END AS segment
FROM transaction_summary;
-- Detect seasonal spikes, demand patterns, and revenue drivers.
-- Detect seasonal spikes - months with increase in total_sales
SELECT 
DATE_FORMAT(Transaction_Date, '%Y-%m') AS month,
SUM(Price) AS total_sales
FROM transactions_data1
GROUP BY month
ORDER BY month;
-- Identify Demand Patterns Day and Month Analysis
SELECT DAYNAME(Transaction_Date) AS day,SUM(Price) AS total_sales
FROM transactions_data1
GROUP BY day
ORDER BY FIELD(day, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');
SELECT MONTHNAME(Transaction_Date) AS month,SUM(Price) AS total_sales
FROM transactions_data1
GROUP BY month
ORDER BY FIELD(month, 'January','February','March','April','May','June','July','August','September','October','November','December');
-- Detect revenue drivers
SELECT p.Category,SUM(t.Price) AS total_sales
FROM transactions_data1 t JOIN products_data1 p ON t.Product_ID = p.Product_ID
GROUP BY p.Category
ORDER BY total_sales DESC
LIMIT 5;
SELECT t.Product_ID,SUM(t.Price) AS revenue,COUNT(*) AS units_sold
FROM transactions_data1 t
GROUP BY t.Product_ID
ORDER BY revenue DESC
LIMIT 5;
SELECT pc.Promotion_ID,COUNT(DISTINCT t.Customer_ID) AS unique_buyers,SUM(t.price) AS total_sales
FROM transactions_data1	 t
JOIN products_data_with_campaigns1 pc ON t.Product_ID = pc.Index_Reference
GROUP BY pc.Promotion_ID
ORDER BY total_sales DESC;
-- Compare sales trends across regions, categories, and promotional campaigns.
-- Sales Trends by Region (Country)
SELECT c.Country,  SUM(t.Total_Price) AS Total_Revenue
FROM transactions_data1 t
JOIN customers_data1 c ON t.Customer_ID = c.Customer_ID
WHERE t.Customer_ID <> 'Unknown_Customer'
GROUP BY c.Country
ORDER BY c.Country, MIN(DATE(t.Transaction_Date));
-- Sales Trends by Product Category 
SELECT p.Category,SUM(t.Total_Price) AS Total_Revenue
FROM transactions_data1 t
JOIN products_data1 p ON t.Product_ID = p.Product_ID
WHERE t.Customer_ID != 'Unknown_Customer'
GROUP BY p.Category
ORDER BY p.Category;
-- Sales Trends by Promotion Campaign
SELECT pc.`Promotion ID` AS Promotion_ID,SUM(t.Total_Price) AS Total_Revenue
FROM transactions_data1 t
JOIN products_data_with_campaigns1 pc ON t.Product_ID = pc.Index_Reference
WHERE t.Customer_ID <> 'Unknown_Customer'
GROUP BY pc.`Promotion ID`
ORDER BY pc.`Promotion ID`;
-- top-selling products, slow-moving items, and high-return categories.
-- Top-selling products by units & revenue
SELECT p.Product_ID, p.Product_Name, p.Category,SUM(t.Quantity) AS Units_Sold,SUM(t.Total_Price) AS Revenue
FROM transactions_data1 t
JOIN products_data1 p USING (Product_ID)
WHERE t.Customer_ID <> 'Unknown_Customer'
GROUP BY p.Product_ID, p.Product_Name, p.Category
ORDER BY Units_Sold DESC, Revenue DESC
LIMIT 10;
-- Slow-moving items - last 90 days which includes zero-sales
WITH txn AS (
  SELECT t.Product_ID, SUM(t.Quantity) AS Units_Sold_90d
  FROM transactions_data1 t
  WHERE t.Customer_ID <> 'Unknown_Customer'
  AND STR_TO_DATE(t.Transaction_Date,'%d-%m-%Y %H:%i') >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
  GROUP BY t.Product_ID
)
SELECT p.Product_ID, p.Product_Name, p.Category,
COALESCE(txn.Units_Sold_90d,0) AS Units_Sold_90d
FROM products_data1 p
LEFT JOIN txn ON p.Product_ID = txn.Product_ID
ORDER BY Units_Sold_90d ASC, p.Product_ID
LIMIT 20;
-- High-return categories
SELECT p.Category,SUM(t.Total_Price) AS Revenue
FROM transactions_data1 t
JOIN products_data1 p USING (Product_ID)
WHERE t.Customer_ID <> 'Unknown_Customer'
GROUP BY p.Category
ORDER BY Revenue DESC;
-- Calculate customer retention rates, lifetime value, and purchase frequency.
-- Customer Retention Rate
WITH yearly_customers AS (
SELECT 
YEAR(STR_TO_DATE(Transaction_Date,'%d-%m-%Y %H:%i')) AS Yr,
Customer_ID
FROM transactions_data1
WHERE Customer_ID <> 'Unknown_Customer'
GROUP BY Yr, Customer_ID
),
retention AS (
SELECT 
this.Yr,
COUNT(DISTINCT this.Customer_ID) AS Total_Customers,
COUNT(DISTINCT CASE WHEN prev.Customer_ID IS NOT NULL THEN this.Customer_ID END) AS Retained_Customers
FROM yearly_customers this
LEFT JOIN yearly_customers prev ON this.Customer_ID = prev.Customer_ID AND this.Yr = prev.Yr + 1
GROUP BY this.Yr
)
SELECT Yr,Total_Customers,Retained_Customers,
ROUND((Retained_Customers / Total_Customers) * 100, 2) AS Retention_Rate_Pct
FROM retention
ORDER BY Yr;
-- Customer Lifetime value - Average purchase value & frequency
WITH cust_metrics AS (
SELECT 
Customer_ID,
COUNT(Transaction_ID) AS Total_Orders,
SUM(Total_Price) AS Total_Revenue
FROM transactions_data1
WHERE Customer_ID <> 'Unknown_Customer'
GROUP BY Customer_ID
)
SELECT Customer_ID,Total_Revenue AS Lifetime_Value
FROM cust_metrics
ORDER BY Lifetime_Value DESC;
-- Purchase Frequency
SELECT Customer_ID,COUNT(Transaction_ID) AS Purchase_Frequency
FROM transactions_data1
WHERE Customer_ID <> 'Unknown_Customer'
GROUP BY Customer_ID
ORDER BY Purchase_Frequency DESC;

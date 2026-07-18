/*
===============================================================================
NAME: Product Performance & Segmentation Report (gold.report_products)
===============================================================================
PURPOSE:
This script creates a robust analytical view ('gold.report_products') that 
consolidates product-level transactional data. It is designed to provide 
product managers and stakeholders with insights into sales velocity, product 
lifecycle, and profitability through comprehensive aggregation and segmentation.

GOAL:
1. PRODUCT PROFILING: Unify product attributes (Category, Subcategory, Cost) 
   with sales performance metrics.
2. PERFORMANCE SEGMENTATION: Classify products as 'High-Performer', 
   'Mid-range', or 'Low-Performer' based on revenue thresholds.
3. KPI CALCULATION: Derive critical operational KPIs, including:
   - Recency (months since last sale)
   - Average Order Revenue
   - Average Monthly Revenue
   - Transactional Aggregates (Orders, Customers, Sales, Quantity)

WARNING & BEST PRACTICES:
1. DATA INTEGRITY: The view utilizes 'LEFT JOIN' logic. Ensure that products 
   without sales history are handled or filtered as needed by your reporting 
   layer to avoid misleading NULL metrics.
2. DIVISION BY ZERO: Explicit 'CASE' statements are included to prevent 
   errors during the calculation of 'avg_order_revenue' and 'avg_monthly_revenue'.
3. THRESHOLD RIGIDITY: The 'product_segment' logic is currently hard-coded 
   (e.g., > 50,000 for High-Performer). Review these thresholds periodically 
   to ensure they remain aligned with evolving business targets.
4. PERFORMANCE: This view aggregates across the entire 'fact_sales' history. 
   If performance degrades as the dataset grows, consider implementing a 
   materialized view or periodic summary table to maintain dashboard responsiveness.
5. RECENCY METRIC: 'GETDATE()' is used for recency calculations. In environments 
   with high data latency, this may reflect the report execution time rather 
   than the true "freshness" of the warehouse data.
===============================================================================
*/
/* Product report
----------------------------------------------------------------------------------
purpose:
	- this report consolidates key product metrics and  behaviours.
purpose :
essentital fields product names, category,subcategory and cost
segment products by revenue to identify High performers,mid-range, or low performers
aggregates product level metrics
-total orders
-total sales
-total quantity sold
-total customers(unique)
-lifespan(in  months)
calculate valuable kpis:
recency
Avg order revenue
avg monthly revenue
*/

-- step 1 : create a base query
-- create view --
create view gold.report_products as
with base_query as(
select
f.customer_key,
p.product_key,
p.product_number,
p.product_name,
f.order_date,
f.order_number,
p.category,
p.subcategory,
p.cost,
f.price,
f.quantity,
f.sales_amount
from gold.fact_sales f
left join gold.dim_products p
on p.product_key = f.product_key
where order_date is not null) -- only consider sales date --


-- step 2 product aggregations: summarises as key metrics --
, product_agg as(
select 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	datediff(month,min(order_date),max(order_date)) as lifespan,
	MAX(order_date) as last_sale_date,
	COUNT(distinct order_number) as total_orders,
	COUNT(distinct customer_key) as total_customers,
	SUM(sales_amount) as total_sales,
	SUM(quantity) as total_quantity,
	round(avg(cast(sales_amount as float)/nullif(quantity,0)),1) as avg_selling_price
from base_query
group by
product_key,
product_name,
category,
subcategory,
cost
)

-- step 3 combines all prodcut results into one output --
select 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	datediff(month,last_sale_date, GETDATE()) as recency_in_months,
	case
		when total_sales > 50000 then 'High-Performer'
		when total_sales >= 10000 then 'Mid-range'
		else 'Low-Performer'
	end as product_segment,
	lifespan,
	last_sale_date,
	total_orders,
	total_customers,
	total_sales,
	total_quantity,
	avg_selling_price,

-- average order revenue --
case
	when total_orders = 0 then 0
	else total_sales/total_orders
end as avg_order_revenue,

-- avg monthly revenue --
case
	when lifespan = 0 then total_sales
	else total_sales / lifespan
end as avg_monthly_revenue
from product_agg

select * from gold.report_products




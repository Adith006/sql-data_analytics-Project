/*
===============================================================================
NAME: Customer Behavioral & Value Report (gold.report_customer)
===============================================================================
PURPOSE:
This script constructs a comprehensive analytical view ('gold.report_customer') 
that consolidates customer demographics, transactional behavior, and high-value 
KPIs. It transforms granular sales data into a customer-centric profile 
suitable for marketing segmentation, retention analysis, and identifying 
high-value cohorts.

GOAL:
1. CUSTOMER PROFILING: Normalize customer identity, age, and location.
2. BEHAVIORAL SEGMENTATION: Apply business logic to classify customers into 
   'VIP', 'Regular', and 'New' segments, alongside age-group bucketing.
3. KPI CALCULATION: Derive key business metrics including:
   - Recency (months since last purchase)
   - Average Order Value (AOV)
   - Average Monthly Spend
   - Transactional Aggregates (Orders, Sales, Quantity, Product Variety)

WARNING & BEST PRACTICES:
1. DATA QUALITY: The 'Recency' calculation uses 'GETDATE()'. If the data warehouse 
   contains historical data that is not current, this will result in artificially 
   high recency scores.
2. DIVISION BY ZERO: The script includes 'CASE' statements to handle division by 
   zero (e.g., when total_sales or total_orders are zero). Ensure these logic 
   branches match the desired reporting requirements.
3. SEGMENTATION OVERLAP: Review the 'age_segment' logic carefully. Currently, 
   the 30-39 group is labeled as '20-29' (potential typo); ensure this is 
   corrected to '30-39' before production use.
4. AGGREGATION SCOPE: This view performs heavy aggregation on 'fact_sales' and 
   'dim_customers'. For large-scale production environments, ensure these 
   underlying views are optimized or consider materializing this report for 
   performance stability.
===============================================================================
*/
/* customers report 
------------------------------------
purpose :
essentital fields names, ages and transaction details
segments customers into categories (vip,regular and new) and age groups
aggregates customer level metrics
-total orders
-total sales
-total quantity purchased
-total products
-lifespan(in  months)
calculate valuable kpis:
recency
Avg order value
avg monthly spend
*/
-- step 1 - Retrieve core columns from tables : base query :
--create view --
create view gold.report_customer as
with base_query as(
select 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
concat(c.first_name, ' ', c.last_name) as customer_name,
DATEDIFF(year,c.birthdate,GETDATE()) as age,
c.country
from gold.fact_sales f
left join gold.dim_customers c
on c.customer_key = f.customer_key
where order_date is not null
)
-- step 2 - calculate all necessary aggregations --
, customer_agg as(
select
customer_key,
customer_number,
customer_name,
age,
COUNT(distinct order_number) as total_orders,
SUM(sales_amount) as total_sales,
SUM(quantity) as total_quantity,
COUNT(distinct product_key) as total_products,
MAX(order_date) last_order_date,
datediff(month,min(order_date),max(order_date)) as lifespan
from base_query
group by
customer_key,
customer_number,
customer_name,
age
)
select
customer_key,
customer_number,
customer_name,
age,
case
	when age < 20 then 'Under 20'
	when age between 20 and 29 then '20-29'
	when age between 30 and 39 then '20-29'
	when age between 40 and 49 then '40-49'
	else '50 and above'
end age_segment,
case
		when Lifespan >= 12 and total_sales > 5000 then 'VIP'
		when Lifespan >= 12 and total_sales <= 5000 then 'regular'
		else 'New'
	end customer_segment,
	last_order_date,
DATEDIFF(month,last_order_date,GETDATE()) as recency,
total_orders,
total_sales,
total_quantity,
total_products,
lifespan,
-- compute average order value--
case
	when total_sales = 0 then 0
	else total_sales/total_orders
end as avg_order_value,
-- compute average monthly spend --
case
	when lifespan = 0 then total_sales
	else total_sales / lifespan
end as avg_monthly_spend
from customer_agg

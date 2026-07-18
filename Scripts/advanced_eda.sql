/*
===============================================================================
NAME: Advanced Time-Series, Segmentation & Performance Analysis
===============================================================================
PURPOSE:
This script performs advanced analytical operations on the 'gold' layer data. 
It focuses on temporal trends (Year-over-Year, Running Totals), comparative 
performance (Moving Averages, Lag-based variance), part-to-whole attribution 
(contribution percentages), and behavioral segmentation (Cost ranges & Customer 
Lifetime Value).

GOAL:
1. TREND ANALYSIS: Visualize revenue growth and cumulative performance over time.
2. COMPETITIVE BENCHMARKING: Compare yearly product performance against historical 
   averages and previous-year figures (YoY).
3. CONTRIBUTION MAPPING: Determine category-level weight within total organizational 
   revenue.
4. CUSTOMER BEHAVIOR MODELING: Segment customers into cohorts (VIP/Regular/New) to 
   drive targeted retention and sales strategies.

WARNING & BEST PRACTICES:
1. WINDOW FUNCTION OVERHEAD: Queries using 'OVER(PARTITION BY...)' or 'LAG()' 
   functionality can be memory-intensive on large datasets. Ensure appropriate 
   indexes exist on columns used for joining and partitioning (e.g., product_key, 
   customer_key).
2. DATE FORMATTING: The use of 'FORMAT(order_date, 'yyy-MMM')' is convenient 
   but can be slow on large tables; consider pre-calculating a date dimension 
   table for production BI environments.
3. LOGICAL ASSUMPTIONS: Ensure the business logic for 'Lifespan' and 'Segmentation' 
   aligns with current stakeholder requirements. For example, the 12-month 
   lifespan threshold is hard-coded; consider parameterizing this for flexibility.
4. DATA PRECISION: Use of 'CAST' to float/decimal is implemented for percentage 
   calculations to avoid integer truncation errors.
===============================================================================
*/
-- changes over time -- trend analysis --
-- sales performance over time --
select year(order_date) as order_year,sum(sales_amount)as total_sales,
count(distinct customer_key) as total_customers, sum(quantity) as total_quantities
from gold.fact_sales
where order_date is not null
group by year(order_date)
order by year(order_date)

--sales performance over month--
select month(order_date) as order_year,sum(sales_amount)as total_sales,
count(distinct customer_key) as total_customers, sum(quantity) as total_quantities
from gold.fact_sales
where order_date is not null
group by month(order_date)
order by month(order_date)

-- sales performance by year month --
select format(order_date,'yyy-MMM') as order_year,sum(sales_amount)as total_sales,
count(distinct customer_key) as total_customers, sum(quantity) as total_quantities
from gold.fact_sales
where order_date is not null
group by format(order_date,'yyy-MMM')
order by format(order_date,'yyy-MMM')

-- cumulative analysis--
-- total sales per month and running total sales over time --
select
Order_year,
total_sales,
avg_price,
--window function--
sum(total_sales) over (order by Order_year) as running_total_sales,
avg(avg_price) over (order by Order_year) as moving_average

from(
select
	year(order_date) as Order_year,
	sum(sales_amount) as total_sales,
	AVG(price) as avg_price
	from gold.fact_sales
	where order_date is not null
	group by year(order_date)
)t

-- performance analysis --
-- analyse the yearly performance of products by comparing their sales 
-- to both the average sales performance of the product and previous year sales ---
with yearly_product_sales as(
select
year(f.order_date) as order_year,
p.product_name,
sum(f.sales_amount) as current_sales
from gold.fact_sales f
left join gold.dim_products p
on f.product_key = p.product_key
where order_date is not null
group by year(f.order_date), p.product_name
)
select
order_year,
product_name,
current_sales,
AVG(current_sales) over(partition by product_name) avg_sales,
current_sales - AVG(current_sales) over(partition by product_name) as diff_avg,
case
	when current_sales - AVG(current_sales) over(partition by product_name) > 0 then 'Above Avg'
	when current_sales - AVG(current_sales) over(partition by product_name) < 0 then 'Below Avg'
	else 'Avg'
end avg_change,
--YOY Analysis --
LAG(current_sales) over(partition by product_name order by order_year) py_sales,
current_sales - LAG(current_sales) over(partition by product_name order by order_year) as diff_py_sales,
case
	when current_sales - LAG(current_sales) over(partition by product_name order by order_year) > 0 then 'Increasing'
	when current_sales - LAG(current_sales) over(partition by product_name order by order_year) < 0 then 'Decreasing'
	else 'No change'
end py_change
from yearly_product_sales
order by product_name,order_year
--- part to whole analysis ---

-- which categories contribute the most to overall sales ---
with category_sales as (
select category,sum(sales_amount) as totalsales from gold.fact_sales f
left join gold.dim_products p
on p.product_key = f.product_key
group by category
)
select category, totalsales,
sum(totalsales) over() overall_sales,
concat(round((cast(totalsales as float)/sum(totalsales) over())*100,2),'%') as pct_of_total
from category_sales
order by totalsales desc

--- data segmentation --
-- segment products into cost ranges and count how many products fall into each segment --
with product_segment as(
select
product_key,
product_name,
cost,
case
	when cost < 100 then 'below 100'
	when cost between 100 and 500 then '100-500'
	when cost between 500 and 1000 then '500-1000'
	else 'above 1000'
end cost_segment
from gold.dim_products
)

select
cost_segment,
count(product_key) as total_products
from product_segment
group by cost_segment
order by total_products desc

/*-- group cutomers into 3 segments based on their spending behaviour:--
- VIP = customers with atleast 12 months of history and spending more than 5,000
-regular = customers with atleast 12 months of history but spending 5,000 or less
-New = customer lifespan with less than 12 months.
and find the total number of customers by each group */

with customer_spending as(
select 
c.customer_key,
sum(f.sales_amount) as total_spending,
min(order_date) first_order,
max(order_date) last_order,
datediff(month,min(order_date),max(order_date)) as Lifespan
from gold.fact_sales f
left join gold.dim_customers c
on f.customer_key = c.customer_key
group by c.customer_key
)
select
customer_segment,
count(customer_key) as total_customers
from(
	select
	customer_key,
	case
		when Lifespan >= 12 and total_spending > 5000 then 'VIP'
		when Lifespan >= 12 and total_spending <= 5000 then 'regular'
		else 'New'
	end customer_segment
	from customer_spending
) t group by customer_segment
order by total_customers desc




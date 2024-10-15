use sales;
--select * from sale
/* Data Cleaning:
1) Remove Duplicates
2) Data Standardization
3) Check for null values
4) Remove Columns
*/
--create a new table to make changes.
select * 
into sales1
from sales;

--removing duplicates
with cte as(select *,ROW_NUMBER()over(partition by date,day,month,year,customer_age,age_group,customer_gender,country,state,product_category,sub_category,product,order_quantity,unit_cost,unit_price,profit,cost,revenue
order by date) as rn
from sales1)
delete from cte where rn>1;

select * from sales1

/*alternatively 
select distinct * into sales1 from sales*/


-- modifying age_group column for better understanding.
update sales1
set age_group = case 
                    when Age_Group = 'Young Adults (25-34)' then 'Adults (25-34)'
                    when Age_Group = 'Adults (35-64)' then 'Middle-Age (34-64)'
                end
where Age_Group in ('Young Adults (25-34)', 'Adults (35-64)');
select distinct age_group from sales1;

--modifying gender column
update sales1
set Customer_Gender= case 
						when Customer_Gender= 'F' then 'Female' else 'Male'
					 end
select distinct customer_gender from sales1;

-- Correcting Revenue calculations
update sales1
set revenue = Order_Quantity*Unit_Price
--updating profit column
update sales1
set profit=Revenue-cost;

/*update sales1 
set sales1.profit=sales.profit
from sales1
inner join sales on sales.date=sales1.date*/

-- Data has no nulls

--Data analysis

--Total Sales,toal sales revenue,total profit over the years
select year, sum(order_quantity) as order_quantity, sum(revenue) as revenue, sum(profit) as profit
from sales1
group by year
order by year

--YoY revenue growth
select year, sum(revenue) as revenue, format(100.0*coalesce(cast(sum(revenue)-(lag(sum(revenue))over(order by year))as decimal)/lag(sum(revenue))over(order by year),0),'N2') + '%' as YoY_growth
from sales1
group by year
order by year

--How do sales vary across quarter,QoQ growth for each year?
select year,datepart(quarter,date) as quarter, sum(revenue) as revenue,
format(100.0*coalesce(cast(sum(revenue)-(lag(sum(revenue))over(partition by year order by datepart(quarter,date)))as decimal)/lag(sum(revenue))over(partition by year order by datepart(quarter,date)),0),'N2') + '%' as QoQ_growth
from sales1
group by year,datepart(quarter,date)
order by year,quarter

--How do sales vary across month.
select month,sum(revenue) as revenue
from sales1
group by month
order by revenue desc

--How do sales vary across each month for all years?
select year,month,sum(revenue) as revenue
from sales1
group by year,month
order by year,revenue desc

--How do weekly sales trends differ throughout the year?
select datepart(week,date) as week, sum(revenue) as revenue
from sales1
group by datepart(week,date)
order by revenue desc

--What is the sales performance across different weekdays?
select datepart(dw,date)as weekday_no,sum(revenue) as revenue
from sales1
group by datepart(dw,date)
order by revenue desc --(sun(1),mon(2),tue(3),wed(4),thu(5),fri(6),sat(7))

--What is the total sales and profit across different countries?
select country, sum(revenue) as revenue,sum(profit) as profit
from sales1
group by country
order by revenue desc

--Which state within each country contributes the most to total sales and profit?
select country,state, sum(revenue) as revenue, sum(profit) as profit
from sales1
group by country,state
order by revenue desc

--How does the profit margin vary between different countries?
select country,100*(cast(sum(profit)as decimal)/sum(revenue)) as profit_margin
from sales1
group by country
order by profit_margin desc

--What is the total sales and profit by product category?
select product_category,sum(revenue) as revenue,sum(profit) as profit
from sales1
group by Product_Category
order by revenue desc

--Which sub-category has the highest and lowest sales and profit?
select sub_category, sum(revenue) as revenue,sum(profit) as profit
from sales1
group by Sub_Category
order by revenue desc, profit desc

--Which product categories have the highest profitability (profit margin)?
select product_category, cast(sum(profit) as decimal)*100/sum(revenue) as profit_margin
from sales1
group by product_category
order by profit_margin desc

--What is the total sales and profit by customer age group? What is the average order quantity of each age group?
select age_group,sum(revenue) as revenue,sum(profit) as profit, avg(order_quantity) as avg_order_quantity
from sales1
group by age_group 
order by revenue desc,profit desc

--Is there a significant difference in sales and profit between male and female customers?What is average order quantity of male and female?
select customer_gender, sum(revenue) as revenue, sum(profit) as profit, avg(order_quantity) as avg_order_quantity
from sales1
group by Customer_gender

--Which are the top 10 best-selling products in terms of order quantity?
select top 10 PRODUCT, sum(order_quantity) as total_orders
from sales1
group by product
order by total_orders desc

--Which are the least performing products in terms of revenue?
select top 10 product, sum(revenue) as revenue
from sales1
group by product
order by revenue asc

--What is the average profit per unit sold for each product category?
select Product_Category,avg(profit/order_quantity) as avg_profit_per_unit
from sales1
group by Product_Category

--Which products are most consistently purchased throughout the year?
with monthly_sales as(select product,month,sum(order_quantity) as orders
from sales1 
group by product,month)
select product,count(distinct month) as months_sold
from monthly_sales
group by product
having count(distinct month)>10
order by months_sold desc

--What is the total cost and profit by product category and sub-category?
select product_category, sub_category,
sum(cost) as total_cost,sum(profit) as profit
from sales1
group by Product_Category,Sub_Category
order by profit desc, total_cost desc

--Which products or categories have the highest cost per unit?
select product_category,product, sum(unit_cost) as total_cost
from sales1
group by product_category, product
order by total_cost desc

--Which products or sub-categories have declining profitability over time?
with profit_pr_yr as(select year, sub_category,product, sum(profit) as profit --lag(sum(profit),1,0)over(partition by product order by year asc) as prev_year_profit
from sales1
group by year, sub_category,product), prev_yr_profit as (
select year,sub_category,product,profit, lag(profit,1,0)over(partition by product order by year asc) as prev_year_profit
from profit_pr_yr)
select sub_category,product,(profit-prev_year_profit) as profit_change
from prev_yr_profit
where (profit-prev_year_profit)<0
order by profit_change asc

--What is the average order quantity by product category?
select product_category,sub_category, avg(order_quantity) as avg_order_quantity
from sales1
group by product_category,sub_category
order by avg_order_quantity desc

--How does the order quantity change over time (year, quarter)?
select year,datepart(quarter,date) as quarter,sum(order_quantity) as order_quantity
from sales1
group by year,datepart(quarter,date)
order by year,quarter

--What is the total profit margin by product category and sub-category?
select product_category,sub_category, cast(sum(profit)as decimal)/sum(revenue) *100 as profit_margin
from sales1
group by product_category,Sub_Category
order by profit_margin desc

-- What is the average profit per unit sold across different countries?
select country, avg(profit/order_quantity) as avg_prft_per_unit
from sales1
group by country
order by avg_prft_per_unit desc

--Which products have the highest and lowest profit per unit?
select product, sum(profit/Order_Quantity) as profit_per_unit
from sales1
group by product
order by profit_per_unit desc

--What is the average age of customers for each country?
select country,avg(customer_age) as average_age
from sales1
group by country

--What is the total number of customers by gender in each age group?
select age_group, sum(case when customer_gender='Male' then 1 else 0 end) as males,
sum(case when customer_gender!='Male' then 1 else 0 end) as females
from sales1
group by age_group

-- What is the total number of customers in each age group across different countries?
select country, age_group,count(age_group) as cnt_of_age_grp
from sales1
group by country,age_group
order by country, cnt_of_age_grp desc

--Write a query to check for gender specific products?
with orders as(select product,sum(case when customer_gender='Male' then Order_Quantity else 0 end) as male_orders,
sum(case when customer_gender!='Male' then Order_Quantity else 0 end) as female_orders
from sales1
group by product)
select product,male_orders,female_orders,
case 
when male_orders>female_orders then 'male_dominated' 
when female_orders>male_orders then 'female_dominated' 
else 'neutral'
end as gender_dominance
from orders
order by male_orders desc,female_orders desc

-- What are the peak sales months in terms of revenue for each product category?
with monthly_revenue as(select product_category, month, sum(revenue) as revenue
from sales1
group by Product_Category,Month), rank as(
select *, row_number()over(partition by product_category order by revenue desc) as rn
from monthly_revenue)
select Product_Category,Month,revenue
from rank
where rn=1
--What are the top products by profit margin?
select product, format(100.0* cast(sum(profit) as decimal)/sum(revenue),'N2') as profit_margin
from sales1
group by product
order by profit_margin desc
--What is the percentage change in order quantity of each product over the years.
with quantity as(select year,product,sum(Order_Quantity) as current_order_quantity, lag(sum(Order_Quantity))over(partition by product order by year)as prev_yr_order_quantity
from sales1
group by year,product)
select *,format((cast((current_order_quantity-prev_yr_order_quantity)as decimal)/prev_yr_order_quantity)*100.0,'N2')+'%' as quantity_change
from quantity
where prev_yr_order_quantity is not null
order by year


--Write a query to return products with most and least variation in demand
select product,avg(order_quantity)avg_order_quantity,STDEV(order_quantity) as variation
from sales1
group by product
order by variation desc





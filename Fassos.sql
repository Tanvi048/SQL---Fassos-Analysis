SET SQL_SAFE_UPDATES = 0;
#------------------------------------------------------------------------------------------
#A. Roll Metrics
#B. Driver and Customer Experience
#C. Ingridient Optimisation
#D. Pricing and Ratings
#------------------------------------------------------------------------------------------
#1. How many rolls were ordered?

select count(order_id) as 'tot_rolls' from customer_orders;
#------------------------------------------------------------------------------------------
#2. How many unique customer orders were made?

select count(distinct(customer_id)) as 'tot_cust' from customer_orders;
#------------------------------------------------------------------------------------------
# Data Cleaning

select * from driver_order;

update driver_order set pickup_time = REPLACE(pickup_time, 2020,2021);

drop view driver_order_cleaned;

create view driver_order_cleaned as
(
  select order_id, driver_id, pickup_time, 
  replace(distance,"km","") as distance,
  replace(replace(replace(duration,"minutes",""),"minute",""),"mins","") as duration,
  CASE WHEN cancellation IN ("cancellation","Customer Cancellation") THEN "Cancel" ELSE "No Cancellation" END as cancellation
  from driver_order
);
select * from driver_order_cleaned;


select * from customer_orders;
create view customer_orders_cleaned as
(
  select order_id, customer_id, roll_id, order_date,
  CASE WHEN not_include_items IS NULL OR not_include_items = "" THEN 0 ELSE not_include_items END AS not_include_items,
  CASE WHEN extra_items_included IS NULL OR extra_items_included = "" OR extra_items_included = "NaN" THEN 0 ELSE extra_items_included 
  END AS extra_items_included
  from customer_orders
);
select * from customer_orders_cleaned;

#------------------------------------------------------------------------------------------
#3. How many successful orders were delivered by each drivers?

select driver_id, count(distinct(c.order_id)) as tot_orders
from driver_order_cleaned d
join customer_orders c
on c.order_id = d.order_id
WHERE d.cancellation = "No Cancellation"
GROUP BY d.driver_id;

#------------------------------------------------------------------------------------------
#4. How many each type of roll was delivered?

SELECT r.roll_name, COUNT((c.roll_id)) AS Rolls_Sold
FROM customer_orders c
JOIN driver_order_cleaned d
ON c.order_id = d.order_id
JOIN rolls r
ON c.roll_id = r.roll_id
WHERE d.cancellation = "No Cancellation"
GROUP BY r.roll_name;

#------------------------------------------------------------------------------------------
#5. How many Veg and Non Veg Rolls were ordered by each customers?

SELECT c.customer_id, r.roll_name, Count(r.roll_id)
FROM customer_orders c
JOIN rolls r
ON c.roll_id = r.roll_id
GROUP BY c.customer_id, r.roll_name
ORDER BY r.roll_name;

#------------------------------------------------------------------------------------------
#6. What was the maximum number of rolls delivered in a single order?

SELECT c.order_id, COUNT(c.roll_id) AS tot_rolls
FROM customer_orders c
JOIN driver_order_cleaned d
ON c.order_id = d.order_id
WHERE cancellation = "No Cancellation"
GROUP BY c.order_id
order by tot_rolls desc;

#------------------------------------------------------------------------------------------
#7. For each customer, how many delivered rolls had atleast 1 change and how many had no change?

with CTE as
(
  SELECT customer_id, roll_id,not_include_items, extra_items_included, c.order_id, 
       CASE WHEN not_include_items = 0 AND extra_items_included = 0 THEN 'No Change' ELSE 'Change' END AS Change_Status
       FROM customer_orders_cleaned c
       JOIN driver_order_cleaned d
       ON c.order_id = d.order_id
       WHERE cancellation = "No Cancellation" 
)
select customer_id, Change_Status, Count(order_id) AS Atleast_1_Change
from CTE
GROUP BY customer_id, Change_Status
order by customer_id asc;

#------------------------------------------------------------------------------------------
#8. How many rolls were delivered that had both exclusions and extras?

with CTE as
(
  SELECT customer_id, roll_id,not_include_items, extra_items_included, c.order_id, 
       CASE WHEN not_include_items != 0 AND extra_items_included != 0 THEN 'Both Inc/Excl' ELSE 'Either Inc/Excl' END 
       AS Change_Status
       FROM customer_orders_cleaned c
       JOIN driver_order_cleaned d
       ON c.order_id = d.order_id
       WHERE cancellation = "No Cancellation" 
)
select Change_Status, Count(order_id) AS tot_rolls
from CTE
GROUP BY Change_Status
order by Change_Status asc;

#------------------------------------------------------------------------------------------
#9. What was the total number of rolls ordered for each hour of the day?

with CTE as 
(
	  SELECT *, CONCAT(HOUR(order_date) , "-" , HOUR(order_date) +1 ) AS Hrs_Slot
      FROM customer_orders_cleaned
)

SELECT Hrs_Slot, COUNT(roll_id) AS Rolls_Per_Hrs
FROM CTE
GROUP BY Hrs_Slot 
ORDER BY Hrs_Slot;

#------------------------------------------------------------------------------------------
#10. What was the number of orders for each day of the week?

with CTE as 
(
	  SELECT *, dayname(order_date) AS Day_of_week
      FROM customer_orders_cleaned
)

SELECT Day_of_week, COUNT(roll_id) AS Rolls_Per_day
FROM CTE
GROUP BY Day_of_week 
ORDER BY Rolls_Per_day desc;

#------------------------------------------------------------------------------------------
#11. What was the time in minutes it took for each driver to arrive at the Fasoo’s HQ to pickup the order?

select c.order_id, driver_id, roll_id, order_date, pickup_time, cancellation, timestampdiff(minute, order_date, pickup_time ) as time_diff
FROM customer_orders_cleaned c
JOIN driver_order_cleaned d
ON c.order_id = d.order_id
WHERE cancellation = "No Cancellation" ;

#------------------------------------------------------------------------------------------
#12. Is there any relationship between the number of rolls and how long the order takes to prepare?

with CTE as 
(
select c.order_id, driver_id, roll_id, order_date, pickup_time, cancellation, 
timestampdiff(minute, order_date, pickup_time ) as time_diff
FROM customer_orders_cleaned c
JOIN driver_order_cleaned d
ON c.order_id = d.order_id
WHERE cancellation = "No Cancellation")

select order_id, count(roll_id) as tot_rolls, round(sum(time_diff)/count(roll_id),2) AS Total_time
from CTE
group by order_id;

#------------------------------------------------------------------------------------------
#13. What was the average distance travelled for each customer?

select customer_id, round(avg(distance),2) as Average
FROM customer_orders_cleaned c
JOIN driver_order_cleaned d
ON c.order_id = d.order_id
WHERE cancellation = "No Cancellation"
group by customer_id;

#------------------------------------------------------------------------------------------
#14. What was the difference between the shortest and longest delivery times for all orders?

SELECT MAX(duration) AS Max, 
MIN(duration) AS Min, 
(MAX(duration) - MIN(duration)) AS Difference
FROM driver_order_cleaned;

#------------------------------------------------------------------------------------------
#15. What was the average speed for each driver for each delivery ?

select driver_id, order_id, distance, duration, round(distance/(duration/60),2) AS Average_Speed
FROM driver_order_cleaned
WHERE cancellation = "No Cancellation";

#------------------------------------------------------------------------------------------
#16. What was the successful delivery percentage for each driver?

with CTE as
(
  SELECT *,
       CASE WHEN cancellation IN ("cancel") THEN 0 ELSE 1 END as cancellation_cnt
       FROM driver_order_cleaned 
)
select driver_id, Count(driver_id) AS Total_Order, Sum(cancellation_cnt) as successful_del,
round((Sum(cancellation_cnt)/Count(driver_id)*100),0) AS Percentage
from CTE
GROUP BY driver_id;

#------------------------------------------------------------------------------------------
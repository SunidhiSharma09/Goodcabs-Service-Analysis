use targets_db
use trips_db

/* 1.Generate a report that displays the total trips, average fare per km, average fare per trip,and the percentage contribution of each
city's trips to the overall trips. This report will help in assessing trip volume, pricing efficiency, and each city's contribution to the 
overall trip count.*/

select city_name, count(trip_id) as total_trips, sum(fare_amount)/sum(distance_travelled_km) as avg_fare_per_km,avg(fare_amount)as avg_fare_per_trip,
       count(trip_id)*100/(select count(trip_id) from fact_trip) as percentage_contribution_to_total_trips
from fact_trip as ft
join dim_city as c
on ft.city_id = c.city_id
group by city_name
order by percentage_contribution_to_total_trips desc;


/*2.Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, compare the actual total
trips with the target trips and categorise the performance as follows:
- if actual trips are greater than target trips, mark it as "above target".
- if actual trips are less than or equal to target trips, mark it as "below target".
Additionally calculate the % difference between actual and target trips to quantify the performance gap.*/

with monthname as (
     select month(date) as Month, month_name
	 from trips_db.dbo.dim_date
	 group by  month(date), month_name
	 ),
actualtrip as  (
     select ft.city_id,city_name, month(ft.date) as month_num, mn.month_name, count(trip_id) as actual_trips 
	 from monthname as mn
	 join trips_db.dbo.dim_date as dt on dt.month_name=mn.month_name
	 join trips_db.dbo.fact_trip as ft on dt.date=ft.date
	 join trips_db.dbo.dim_city as c on ft.city_id=c.city_id
	 group by ft.city_id,city_name, month(ft.date), mn.month_name
	 ),
targettrip as (
           select city_id, month(month) as month_num, total_target_trips as target_trips
		   from targets_db.dbo.monthly_target_trips
	)
select city_name, at.month_name, actual_trips, target_trips, 
       case when actual_trips > target_trips then 'Above Target'
	        when actual_trips <= target_trips then 'Below Target'
	   end as performance_status,
	   cast((actual_trips-target_trips)*100/target_trips as decimal(10,2)) as percentage_difference
from actualtrip as at 
join targettrip as tt 
on tt.city_id=at.city_id and tt.month_num=at.month_num
group by at.city_id, city_name, at.month_name, actual_trips, target_trips
order by city_name;

	 
/* 3.Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. 
Calculate the percentage of repeat passengers who took 2-trips, 3-trips and so on upto 10-trips. */

with trip_data as (
    select city_name, trip_count, sum(repeat_passenger_count) as repeat_passenger_count
    from dim_repeat_trip_distribution as rtd
	join dim_city as c 
	on c.city_id=rtd.city_id
	group by  city_name,trip_count
),
city_totals as (
    select city_name, sum(repeat_passenger_count) as total_repeat_passengers
    from trip_data
    group by city_name
)
select td.city_name,
     cast(max(case when td.trip_count = '2-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "2-Trips",
     cast(max(case when td.trip_count = '3-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "3-Trips",
     cast(max(case when td.trip_count = '4-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "4-Trips",
     cast(max(case when td.trip_count = '5-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "5-Trips",
     cast(max(case when td.trip_count = '6-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "6-Trips",
     cast(max(case when td.trip_count = '7-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "7-Trips",
     cast(max(case when td.trip_count = '8-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "8-Trips",
     cast(max(case when td.trip_count = '9-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "9-Trips",
     cast(max(case when td.trip_count = '10-Trips' then td.repeat_passenger_count else 0 end) * 100.0 / ct.total_repeat_passengers as decimal(10,2)) as "10-Trips"
from trip_data as td
join city_totals as ct
on ct.city_name = td.city_name
group by td.city_name, ct.total_repeat_passengers
order by td.city_name;



/* 4. Generate a report that calculates the total new passengers for each city and ranks them based on this value. Identify the top 3
cities with the highest number of new passengers as well as the bottom 3 cities with the lowest number of new passengers, categorising them as
'Top 3 ' or 'Bottom 3 ' accordingly.*/

with cityrnk as (
     select city_name, count(trip_id) as total_new_passengers,
            DENSE_RANK() over(order by count(trip_id) desc) as rnk
     from fact_trip as ft
     join dim_city as c
     on ft.city_id=c.city_id
     where passenger_type = 'new'
     group by city_name
),
maxrnk as(
          select max(rnk) as max_rnk from cityrnk
		  )
select cr.city_name, cr.total_new_passengers,
       case when cr.rnk<=3 then 'Top 3'
	        when cr.rnk>= mr.max_rnk-2 then 'Bottom 3'
			else ' '
	   end as city_category
from cityrnk as cr 
cross join maxrnk as mr
order by cr.total_new_passengers desc;



/* 5. Generate a report that identifies the month with the highest revenue for each city. For each city, display the month_name, the revenue
amount for that month, and the percentage contribution of that month's revenue to the city's total revenue.*/

with city_revenue as (
    select city_name, month_name, sum(fare_amount) as revenue
    from dim_date as d
    join fact_trip as ft on ft.date = d.date
    join dim_city as c on c.city_id = ft.city_id
    group by city_name,month_name
),
city_total_revenue as (
    select city_name,sum(revenue) as total_revenue
    from city_revenue
    group by city_name
),
highest_revenue_month as (
    select cr.city_name,cr.month_name as highest_revenue_month,cr.revenue,ctr.total_revenue,
        (cr.revenue * 100.0) / ctr.total_revenue as percentage_contribution
    from city_revenue cr
    join city_total_revenue ctr on cr.city_name = ctr.city_name
    where cr.revenue = (select max(revenue) from city_revenue where city_name = cr.city_name
        )
)
select city_name,highest_revenue_month,revenue,cast(percentage_contribution as decimal(10,2)) AS percentage_contribution
from highest_revenue_month
order by city_name;



/* 6. Generates a report that calculate two metrics:
6.1. Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers
to the total passengers.
6.2. City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months*/

with repeatpassenger as (
     select ft.city_id, city_name , month_name, count(passenger_type) as repeat_passengers
	 from dim_date as d
	 join fact_trip as ft on ft.date=d.date
     join dim_city as c on c.city_id=ft.city_id
	 where passenger_type='repeated'
     group by ft.city_id, city_name,month_name
),
totalpassenger as ( 
     select ft.city_id, city_name , month_name, count(passenger_type) as total_passengers
	 from dim_date as d
	 join fact_trip as ft on ft.date=d.date
     join dim_city as c on c.city_id=ft.city_id
     group by ft.city_id, city_name,month_name
),
rp_city as(
    select city_name, count(passenger_type) as repeat_passengers_city
	from fact_trip as ft
	join dim_city as c on c.city_id=ft.city_id
	where passenger_type='repeated'
    group by city_name
),
tp_city as (
    select city_name, count(passenger_type) as total_passengers_city
	from fact_trip as ft
	join dim_city as c on c.city_id=ft.city_id
    group by city_name
)
select r.city_name, r.month_name as month, total_passengers, repeat_passengers, 
       cast((repeat_passengers*100)/total_passengers as decimal(10,2)) as monthly_repeat_passenger_rate,
	   cast((repeat_passengers_city*100)/total_passengers_city as decimal(10,2)) as city_repeat_passenger_rate
from repeatpassenger as r 
join totalpassenger as t 
on t.city_name=r.city_name and t.month_name =r.month_name
join rp_city as rpc on rpc.city_name = t.city_name
join tp_city as tpc on tpc.city_name =rpc.city_name
order by r.city_name,r.month_name ;
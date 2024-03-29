use mavenmovies;

-- Q1. Rank the customers based on the total amount they've spent on rentals.
SELECT 
    customer_id, 
    CONCAT(first_name, ' ', last_name) AS customer_name, 
    total_spent,
    RANK() OVER (order by total_spent desc) as spending_rank
    from
(select c.first_name, 
c.last_name, c.customer_id, 
sum(p.amount) as total_spent
from customer c join rental r on c.customer_id=r.customer_id
join payment p on p.rental_id= r.rental_id
group by c.first_name, c.last_name, c.customer_id) as subquery
order by total_spent desc;


-- Q2. Calculate the cumulative revenue generated by each film over time.
WITH film_revenue AS (
    SELECT
        f.film_id,
        f.title,
        p.amount,
        p.payment_date,
        SUM(p.amount) OVER (PARTITION BY f.film_id ORDER BY p.payment_date) AS cumulative_revenue
    FROM
        film f
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
)
SELECT
    film_id,
    title,
    amount,
    payment_date,
    cumulative_revenue
FROM
    film_revenue
ORDER BY
    film_id, payment_date;


-- Q3. Determine the average rental duration for each film, considering films with similar lengths.
SELECT 
    film_id, 
    title, 
    length,
    rental_duration,
    AVG(rental_duration) OVER (PARTITION BY length_category order by film_id) AS avg_rental_duration_for_length_category
FROM (
       SELECT 
        film_id,
        title,
        length,
        rental_duration,
CASE WHEN length <= 50 THEN '0-50 mins'
WHEN length > 60 AND length <= 120 THEN '61-120 mins'
ELSE 'Over 120 mins'
END AS length_category
FROM film ) AS subquery;


-- Q4. Identify the top 3 films in each category based on their rental counts.
SELECT 
    sub.category_id, 
    sub.film_id, 
    sub.title, 
    sub.count_rental, 
    sub.ranking
FROM (
    SELECT 
        fc.category_id, 
        f.film_id, 
        f.title,
        COUNT(r.rental_id) as count_rental, 
        ROW_NUMBER() OVER (PARTITION BY fc.category_id ORDER BY COUNT(r.rental_id) DESC) as ranking
    FROM film_category fc
    JOIN film f ON f.film_id = fc.film_id
    LEFT JOIN inventory i ON i.film_id = f.film_id
    LEFT JOIN rental r ON r.inventory_id = i.inventory_id
    GROUP BY fc.category_id, f.film_id, f.title
) as sub
WHERE sub.ranking <= 3
ORDER BY sub.category_id, sub.ranking;

-- Q5. Calculate the difference in rental counts between each customer's total rentals and the average rentals across all customers.
SELECT 
    customer_id,
    COUNT(rental_id) AS total_rental,
    AVG(COUNT(rental_id)) OVER () AS avg_rental,
    COUNT(rental_id) - AVG(COUNT(rental_id)) OVER () AS difference
FROM rental
GROUP BY customer_id;


-- Q6. Find the monthly revenue trend for the entire rental store over time.
SELECT 
    store_id,
    EXTRACT(YEAR FROM rental_date) AS year,
    EXTRACT(MONTH FROM rental_date) AS month,
    SUM(amount) AS monthly_revenue,
    SUM(SUM(amount)) OVER (PARTITION BY store_id ORDER BY EXTRACT(YEAR FROM rental_date), EXTRACT(MONTH FROM rental_date)) AS cumulative_revenue
FROM payment
JOIN rental ON payment.rental_id = rental.rental_id
JOIN inventory ON rental.inventory_id = inventory.inventory_id
GROUP BY 
store_id, EXTRACT(YEAR FROM rental_date), EXTRACT(MONTH FROM rental_date)
ORDER BY store_id, year, month;

-- Q7. Identify the customers whose total spending on rentals falls within the top 20% of all customers.
WITH CustomerSpending AS (
    SELECT 
        customer_id,
        SUM(amount) AS total_spending
    FROM payment
    GROUP BY customer_id),
    SpendingRanks 
    AS (SELECT 
        customer_id,
        total_spending,
        NTILE(5) OVER (ORDER BY total_spending DESC) AS spending_percentile
    FROM CustomerSpending
)
SELECT customer_id, total_spending
FROM SpendingRanks
WHERE spending_percentile = 1;

-- Q8. Calculate the running total of rentals per category, ordered by rental count.
WITH category_rentals AS (
    SELECT
        c.name AS category,
        COUNT(*) AS rental_count
    FROM
        category c
    JOIN
        film_category fc ON c.category_id = fc.category_id
    JOIN
        film f ON fc.film_id = f.film_id
    JOIN
        inventory i ON f.film_id = i.film_id
    JOIN
        rental r ON i.inventory_id = r.inventory_id
    GROUP BY
        c.name
    ORDER BY
        rental_count DESC
)
SELECT
    category,
    rental_count,
    SUM(rental_count) OVER (ORDER BY rental_count DESC) AS running_total
FROM
    category_rentals;



-- Q9. Find the films that have been rented less than the average rental count for their respective categories.
SELECT 
    sub.title, 
    sub.category_id, 
    sub.rental_count
FROM 
    (SELECT 
        f.title, 
        fc.category_id, 
        COUNT(r.rental_id) AS rental_count,
        AVG(COUNT(r.rental_id)) OVER (PARTITION BY fc.category_id) AS avg_rental_count_category
     FROM rental r
     JOIN inventory i ON r.inventory_id = i.inventory_id
     JOIN film f ON i.film_id = f.film_id
     JOIN film_category fc ON f.film_id = fc.film_id
     GROUP BY fc.category_id, f.film_id, f.title
    ) AS sub
WHERE sub.rental_count < sub.avg_rental_count_category;


-- Q10. Identify the top 5 months with the highest revenue and display the revenue generated in each month.
WITH MonthlyRevenue AS (
    SELECT 
        EXTRACT(YEAR FROM r.rental_date) AS year,
        EXTRACT(MONTH FROM r.rental_date) AS month,
        SUM(p.amount) AS revenue
    FROM rental r 
    JOIN payment p ON r.rental_id = p.rental_id 
    GROUP BY 1, 2

),
RankedRevenue AS (
    SELECT year,month,revenue,
	RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
    FROM MonthlyRevenue
) 
SELECt year, month, revenue
FROM RankedRevenue
WHERE revenue_rank <= 5;


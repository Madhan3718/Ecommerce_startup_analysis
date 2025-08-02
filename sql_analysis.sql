select * from orders;
select * from order_items;
select * from order_item_refunds;
select * from products;
select * from website_sessions;
select * from website_pageviews;


--  Analyzing Seasonality: Pull out sessions and orders by year, monthly and weekly for 2012? ----
SELECT 
    DATEPART(YEAR, ws.created_at) AS year,
    DATEPART(MONTH,ws.created_at) AS month,
    DATENAME(WEEKDAY, ws.created_at) AS weekday,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT order_id) AS total_orders
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
WHERE DATEPART(YEAR, ws.created_at) = 2012
GROUP BY DATEPART(YEAR, ws.created_at), DATEPART(MONTH, ws.created_at), DATENAME(WEEKDAY, ws.created_at)
ORDER BY year, month, weekday;

-----------------------------------------------------------------------------------------------------------------

-- Analyzing Business Patterns: What is the average website session volume , categorized by hour of the day 
-- and day of the week, between September 15th and November 15th ,2013, excluding holidays to assist in determining 
-- appropriate staffing levels for live chat support on the website?

SELECT 
    DATEPART(HOUR, created_at) AS hour_of_day,
    DATENAME(WEEKDAY, created_at) AS day_of_week,
    COUNT(website_session_id) / 
        (SELECT COUNT(DISTINCT CAST(created_at AS DATE))
         FROM website_sessions
         WHERE created_at BETWEEN '2013-09-15' AND '2013-11-15'
         AND CAST(created_at AS DATE) NOT IN (
             '2013-09-15', '2013-09-22', '2013-09-29', 
             '2013-10-06', '2013-10-13', '2013-10-20', 
             '2013-10-27', '2013-11-03', '2013-11-10'
         )) AS avg_sessions
FROM website_sessions
WHERE created_at BETWEEN '2013-09-15' AND '2013-11-15'
  AND CAST(created_at AS DATE) NOT IN (
      '2013-09-15', '2013-09-22', '2013-09-29', 
      '2013-10-06', '2013-10-13', '2013-10-20', 
      '2013-10-27', '2013-11-03', '2013-11-10'
  )
GROUP BY DATEPART(HOUR, created_at), DATENAME(WEEKDAY, created_at)
ORDER BY hour_of_day, day_of_week;

-------------------------------------------------------------------------------------------------------------------------------

-- Product Level Sales Analysis: What is monthly trends to date for number of sales , total revenue and total margin generated for business?

SELECT 
    DATEPART(YEAR, o.created_at) AS year,
    DATEPART(MONTH, o.created_at) AS month,
    COUNT(DISTINCT o.order_id) AS total_sales_count,
    ROUND(SUM(oi.price_usd - COALESCE(r.refund_amount_usd, 0)), 2) AS total_revenue,
    ROUND(SUM(oi.price_usd - oi.cogs_usd - COALESCE(r.refund_amount_usd, 0)), 2) AS total_margin
FROM 
    orders o
JOIN 
    order_items oi ON o.order_id = oi.order_id
LEFT JOIN 
    order_item_refunds r ON oi.order_item_id = r.order_item_id
GROUP BY 
    DATEPART(YEAR, o.created_at), DATEPART(MONTH, o.created_at)
ORDER BY 
    year, month;


----------------------------------------------------------------------------------------------------------------


-- Identifying Repeat Visitors: Please pull data on how many of our website visitors come back for another session?2014 to date is good

SELECT 
    COUNT(DISTINCT user_id) AS repeat_visitors_count
FROM 
    website_sessions
WHERE 
    created_at >= '2014-01-01'
AND user_id IN (
                SELECT 
                user_id 
                FROM 
                website_sessions
                WHERE created_at >= '2014-01-01'
                GROUP BY user_id
                HAVING COUNT(website_session_id) > 1
				);


	-------------------------------------------------------------------------------------------------------------------
-- Analyzing Repeat Behavior: What is the minimum , maximum and average time between the first and second session for 
-- customers who do come back?2014 to date is good.

                                      -- ANSWER ----

	                -- Time Between First and Second Sessions for Repeat Customers Based on Orders Table
	                -- Only considers sessions within the orders table, focusing purely on sessions where purchases were made.

WITH SessionRanks AS (
    SELECT 
        user_id,
        website_session_id,
        created_at,
        ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY created_at) AS session_rank
    FROM orders
    WHERE created_at >= '2014-01-01'
    GROUP BY user_id, website_session_id, created_at
)

SELECT 
    
    MIN(DATEDIFF(DAY, first_session.created_at, second_session.created_at)) AS min_time_between_sessions,
    MAX(DATEDIFF(DAY, first_session.created_at, second_session.created_at)) AS max_time_between_sessions,
    AVG(DATEDIFF(DAY, first_session.created_at, second_session.created_at)) AS avg_time_between_sessions
FROM 
    SessionRanks AS first_session
JOIN 
    SessionRanks AS second_session
ON 
    first_session.user_id = second_session.user_id
    AND first_session.session_rank = 1
    AND second_session.session_rank = 2;


	-----------------------------------------------------------------------------------------------------------
-- New Vs. Repeat Channel Patterns: Analyze the channels through which repeat customers return to our website, comparing them 
-- to new sessions? Specifically,  interested in understanding if repeat customers predominantly come through direct type-in or if 
-- there’s a significant portion that originates from paid search ads. This analysis should cover the period from the beginning of 2014 to the present date.

WITH CustomerOrders AS (
    SELECT 
        o.user_id,
        MIN(o.created_at) AS first_order_date,
        COUNT(DISTINCT o.website_session_id) AS session_count
    FROM 
        orders o
    WHERE 
        o.created_at >= '2014-01-01' -- Start date
    GROUP BY 
        o.user_id
),

CustomerType AS (
    SELECT 
        user_id,
        CASE 
            WHEN session_count = 1 THEN 'New Customer'
            WHEN session_count >= 2 THEN 'Repeat Customer'
        END AS customer_type
    FROM 
        CustomerOrders
),

CustomerChannels AS (
    SELECT 
        ct.customer_type,
        ws.utm_source AS channel,
        COUNT(ws.utm_source) AS channel_count
    FROM 
        CustomerType ct
    JOIN 
        orders o ON ct.user_id = o.user_id
    JOIN 
        website_sessions ws ON o.website_session_id = ws.website_session_id
    WHERE 
        o.created_at >= '2014-01-01'
    GROUP BY 
        ct.customer_type, ws.utm_source
)

-- Final query to get the channel distribution for new vs. repeat customers
SELECT 
    customer_type,
    channel,
    channel_count,
    ROUND(100.0 * channel_count / SUM(channel_count) OVER (PARTITION BY customer_type), 2) AS channel_percentage
FROM 
    CustomerChannels
ORDER BY 
    customer_type, channel_count DESC;



------------------------------------------------------------------------------------------------------------
-- New Vs. Repeat Performance: Provide analysis on comparison of conversion rates and revenue per session for repeat sessions vs new 
-- sessions?2014 to date is good.

WITH SessionData AS (
    SELECT 
        ws.website_session_id,
        ws.user_id,
        ws.is_repeat_session,
        ws.created_at AS session_start,
        COALESCE(SUM(o.price_usd - ISNULL(r.refund_amount_usd, 0)), 0) AS session_revenue,
        CASE WHEN SUM(o.price_usd - ISNULL(r.refund_amount_usd, 0)) > 0 THEN 1 ELSE 0 END AS session_conversion
    FROM 
        website_sessions ws
    LEFT JOIN 
        orders o ON ws.website_session_id = o.website_session_id
    LEFT JOIN 
        order_items oi ON o.order_id = oi.order_id
    LEFT JOIN 
        order_item_refunds r ON oi.order_item_id = r.order_item_id
    WHERE 
        ws.created_at >= '2014-01-01'
    GROUP BY 
        ws.website_session_id, ws.user_id, ws.is_repeat_session, ws.created_at
)

-- Calculate metrics for new vs. repeat sessions
SELECT 
    CASE 
        WHEN is_repeat_session = 1 THEN 'Repeat Session'
        ELSE 'New Session'
    END AS session_type,
    COUNT(website_session_id) AS total_sessions,
    SUM(session_conversion) AS conversions,
    ROUND((CAST(SUM(session_conversion) AS FLOAT) / COUNT(website_session_id)) * 100, 2) AS conversion_rate,
    ROUND(SUM(session_revenue), 2) AS total_revenue,
    ROUND(SUM(session_revenue) / COUNT(website_session_id), 2) AS revenue_per_session
FROM 
    SessionData
GROUP BY 
    is_repeat_session;







	

--look at the whole table
SELECT *
FROM Online_Retail

--check dataset if there are any returned products
SELECT *
FROM Online_Retail
WHERE Quantity < 0

WITH CTE AS-- duplicate check
(
	SELECT *, ROW_NUMBER() OVER(PARTITION BY InvoiceNo, StockCode, Quantity, InvoiceDate ORDER BY InvoiceDate ) AS dup_check
	FROM Online_Retail
),
	 CTE1 AS --data table without returned products, NULL customerID, and duplicate. Convert InvoiceDate into Date format
(
	SELECT 
			InvoiceNo,
			StockCode,
			Description,
			Quantity,
			CAST(InvoiceDate AS date) AS InvoiceDate,
			UnitPrice,
			CustomerID,
			Country
	FROM CTE
	WHERE Quantity > 0 AND CustomerID IS NOT NULL AND dup_check = 1
), 
--RFM ANALYSIS
	CTE2 AS --calculate the recency, frequency and monetary
(
	SELECT
			CustomerID, 
			MAX(InvoiceDate) AS last_active_date, 
			DATEDIFF(day, MAX(InvoiceDate), '2021-12-10') AS Recency,
			COUNT(DISTINCT(InvoiceNo)) AS Frequency,
			SUM(Quantity * UnitPrice) AS Monetary
	FROM CTE1
	GROUP BY CustomerID
),
	CTE3 AS --apply Quantile concepts to segment the customers
(
	SELECT 
			CustomerID,
			last_active_date,
			Recency,
			Frequency,
			Monetary,
			ROUND(PERCENT_RANK() OVER(ORDER BY Recency) * 100, 2) AS pctile_recency,
			ROUND(PERCENT_RANK() OVER(ORDER BY Frequency) * 100, 2) AS pctile_frequency,
			ROUND(PERCENT_RANK() OVER(ORDER BY Monetary) * 100, 2) AS pctile_monetary
	FROM CTE2
),
	CTE4 AS --label for the quantiles of recency, frequency and monetary by 1,2,3,4
(
	SELECT
			CustomerID,
			last_active_date,
			Recency,
			Frequency,
			Monetary,
			pctile_recency,
			pctile_frequency,
			pctile_monetary,
			CASE WHEN pctile_recency >= 0 AND pctile_recency <= 25 THEN 4
				 WHEN pctile_recency > 25 AND pctile_recency <= 50 THEN 3
				 WHEN pctile_recency > 50 AND pctile_recency <= 75 THEN 2
				 WHEN pctile_recency > 75 THEN 1
			END AS Recency_rank,
			CASE WHEN pctile_frequency >= 0 AND pctile_frequency <= 25 THEN 1
				 WHEN pctile_frequency > 25 AND pctile_frequency <= 50 THEN 2
				 WHEN pctile_frequency > 50 AND pctile_frequency <= 75 THEN 3
				 WHEN pctile_frequency > 75 THEN 4
			END AS Frequency_rank,
			CASE WHEN pctile_monetary >= 0 AND pctile_monetary <= 25 THEN 1
				 WHEN pctile_monetary > 25 AND pctile_monetary <= 50 THEN 2
				 WHEN pctile_monetary > 50 AND pctile_monetary <= 75 THEN 3
				 WHEN pctile_monetary > 75 THEN 4
			END AS Monetary_rank
	FROM CTE3
),
	CTE5 AS --calculate sum of Recency_rank, Frequency_rank and Monetary_rank then calculate the quantile of RFM to segment the customers
(
	SELECT 
			CustomerID,
			last_active_date,
			Recency,
			Frequency,
			Monetary,
			Recency_rank,
			Frequency_rank,
			Monetary_rank,
			Recency_rank + Frequency_rank + Monetary_rank AS RFM_score,
			ROUND(PERCENT_RANK() OVER(ORDER BY Recency_rank + Frequency_rank + Monetary_rank) * 100, 2) AS pctile_RFM
	FROM CTE4
)
	SELECT --label the level for each RFM rank
			CustomerID,
			last_active_date,
			Recency,
			Frequency,
			Monetary,
			Recency_rank,
			Frequency_rank,
			Monetary_rank,
			CASE WHEN pctile_RFM >= 0 AND pctile_RFM <= 25 THEN 'Extremely Low'
				 WHEN pctile_RFM > 25 AND pctile_RFM <= 50 THEN 'Low'
				 WHEN pctile_RFM > 50 AND pctile_RFM <= 75 THEN 'Normal'
				 WHEN pctile_RFM > 75 THEN 'VIP'
			END AS RFM_level
	FROM CTE5
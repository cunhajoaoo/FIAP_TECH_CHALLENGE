-- =====================================================================
-- 02 - Elasticidade da satisfacao ao atraso
-- =====================================================================

WITH rv AS (
    SELECT
        order_id
        , AVG(review_score) AS nota
    FROM FIAP.HOMOLOG_DATA.ORDER_REVIEWS
    GROUP BY 1
)

SELECT
    CASE
        WHEN d <= -7 THEN '1. 7+ dias adiantado'
        WHEN d <= 0 THEN '2. No prazo'
        WHEN d <= 3 THEN '3. Atraso 1-3d'
        WHEN d <= 7 THEN '4. Atraso 4-7d'
        ELSE '5. Atraso 8d+'
    END                                    AS faixa
    , COUNT(*)                             AS pedidos
    , ROUND(AVG(nota), 2)                  AS nota
    , ROUND(
        100 * AVG(
            IFF(
                nota <= 2
                , 1
                , 0
            )
        )
        , 1
    )                                      AS pct_detratores
FROM (
    SELECT
        o.order_id
        , DATEDIFF(
            'day'
            , o.order_estimated_delivery_date
            , o.order_delivered_customer_date
        )                                  AS d
    FROM FIAP.HOMOLOG_DATA.ORDERS o
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
) x
JOIN rv
    USING (order_id)
GROUP BY 1
ORDER BY 1;
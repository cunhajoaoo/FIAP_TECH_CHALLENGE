-- =====================================================================
-- 07 - Retencao (recompra)
-- Cliente = CUSTOMER_UNIQUE_ID; pedidos validos (exclui canceled/unavailable).
-- =====================================================================

-- 7a. Recompra por experiencia no 1o pedido, tempo ate a 2a compra e peso dos recorrentes


WITH rv AS (
    SELECT
        order_id
        , AVG(review_score)                                    AS nota
    FROM FIAP.HOMOLOG_DATA.ORDER_REVIEWS
    GROUP BY 1
)
, it AS (
    SELECT
        order_id
        , SUM(price)                                           AS gmv
    FROM FIAP.HOMOLOG_DATA.ORDER_ITEMS
    GROUP BY 1
)
, o AS (
    SELECT
        cu.customer_unique_id                                  AS cid
        , o.order_id
        , o.order_purchase_timestamp                           AS ts
        , rv.nota
        , it.gmv
        , IFF(
            o.order_delivered_customer_date > o.order_estimated_delivery_date
            , 1
            , 0
        )                                                      AS atrasou
        , ROW_NUMBER() OVER (
            PARTITION BY cu.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        )                                                      AS rn
        , COUNT(*) OVER (
            PARTITION BY cu.customer_unique_id
        )                                                      AS n
    FROM FIAP.HOMOLOG_DATA.ORDERS o
    JOIN FIAP.HOMOLOG_DATA.CUSTOMERS cu
        USING (customer_id)
    LEFT JOIN rv
        USING (order_id)
    LEFT JOIN it
        USING (order_id)
    WHERE o.order_status NOT IN (
        'canceled'
        , 'unavailable'
    )
)
, f AS (
    SELECT
        o1.*
        , DATEDIFF(
            'day'
            , o1.ts
            , o2.ts
        )                                                      AS dias2
    FROM o o1
    LEFT JOIN o o2
        ON o2.cid = o1.cid
        AND o2.rn = 2
    WHERE o1.rn = 1
)

SELECT
    'nota_1o_pedido'                                           AS dim
    , IFF(
        nota >= 4
        , 'satisfeito (4-5)'
        , IFF(
            nota <= 2
            , 'insatisfeito (1-2)'
            , 'neutro (3)'
        )
    )                                                          AS grupo
    , COUNT(*)                                                 AS clientes
    , ROUND(
        100 * AVG(IFF(n > 1, 1, 0))
        , 2
    )                                                          AS recompra_pct
    , NULL                                                     AS v
FROM f
WHERE nota IS NOT NULL
GROUP BY 2

UNION ALL

SELECT
    'atraso_1o_pedido'                                         AS dim
    , IFF(
        atrasou = 1
        , 'atrasou'
        , 'no prazo'
    )                                                          AS grupo
    , COUNT(*)                                                 AS clientes
    , ROUND(
        100 * AVG(IFF(n > 1, 1, 0))
        , 2
    )                                                          AS recompra_pct
    , NULL                                                     AS v
FROM f
GROUP BY 2

UNION ALL

SELECT
    'dias_ate_2a'                                              AS dim
    , 'mediana'                                                AS grupo
    , COUNT(dias2)                                             AS clientes
    , NULL                                                     AS recompra_pct
    , MEDIAN(dias2)                                            AS v
FROM f

UNION ALL

SELECT
    'dias_ate_2a'                                              AS dim
    , 'mesmo_dia_pct'                                          AS grupo
    , COUNT(dias2)                                             AS clientes
    , NULL                                                     AS recompra_pct
    , ROUND(
        100 * AVG(IFF(dias2 = 0, 1, 0))
        , 1
    )                                                          AS v
FROM f
WHERE dias2 IS NOT NULL

UNION ALL

SELECT
    'dias_ate_2a'                                              AS dim
    , 'ate_90d_pct'                                            AS grupo
    , COUNT(dias2)                                             AS clientes
    , NULL                                                     AS recompra_pct
    , ROUND(
        100 * AVG(IFF(dias2 <= 90, 1, 0))
        , 1
    )                                                          AS v
FROM f
WHERE dias2 IS NOT NULL

UNION ALL

SELECT
    'gmv_recorrentes_pct'                                      AS dim
    , 'todos'                                                  AS grupo
    , NULL                                                     AS clientes
    , NULL                                                     AS recompra_pct
    , ROUND(
        100 * SUM(IFF(n > 1, gmv, 0)) / SUM(gmv)
        , 1
    )                                                          AS v
FROM o

UNION ALL

SELECT
    'gmv_por_cliente'                                          AS dim
    , IFF(
        n > 1
        , 'recorrente'
        , 'unico'
    )                                                          AS grupo
    , COUNT(DISTINCT cid)                                      AS clientes
    , NULL                                                     AS recompra_pct
    , ROUND(
        SUM(gmv) / COUNT(DISTINCT cid)
        , 1
    )                                                          AS v
FROM o
GROUP BY 2

ORDER BY 1, 2;

-- 7b. Recompra real (segunda compra em outro dia) por trimestre da 1a compra
--   Janela fixa de 90 dias torna as coortes comparaveis (coortes recentes tem menos tempo observado).
--   Total: 2,17% sem mesmo dia | 1,19% em 90 dias | coortes 90d entre 1,14% e 1,55% (sem tendencia)

WITH o AS (
    SELECT
        cu.customer_unique_id                                  AS cid
        , o.order_purchase_timestamp                           AS ts
        , ROW_NUMBER() OVER (
            PARTITION BY cu.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        )                                                      AS rn
    FROM FIAP.HOMOLOG_DATA.ORDERS o
    JOIN FIAP.HOMOLOG_DATA.CUSTOMERS cu
        USING (customer_id)
    WHERE o.order_status NOT IN (
        'canceled'
        , 'unavailable'
    )
)
, f AS (
    SELECT
        a.cid
        , a.ts
        , MIN(
            IFF(
                DATEDIFF('day', a.ts, b.ts) BETWEEN 1 AND 90
                , 1
                , NULL
            )
        )                                                      AS volta90
        , MIN(
            IFF(
                DATEDIFF('day', a.ts, b.ts) >= 1
                , 1
                , NULL
            )
        )                                                      AS volta_total
    FROM o a
    LEFT JOIN o b
        ON b.cid = a.cid
        AND b.rn > 1
    WHERE a.rn = 1
    GROUP BY
        1
        , 2
)

SELECT
    TO_CHAR(
        DATE_TRUNC('quarter', ts)
        , 'YYYY-MM'
    )                                                          AS tri
    , COUNT(*)                                                 AS clientes
    , ROUND(
        100 * COUNT(volta90) / COUNT(*)
        , 2
    )                                                          AS recompra_90d
    , ROUND(
        100 * COUNT(volta_total) / COUNT(*)
        , 2
    )                                                          AS recompra_total_sem_mesmo_dia
FROM f
WHERE ts >= '2017-01-01'
    AND ts < '2018-06-01'
GROUP BY 1

UNION ALL

SELECT
    'TOTAL'                                                    AS tri
    , COUNT(*)                                                 AS clientes
    , ROUND(
        100 * COUNT(volta90) / COUNT(*)
        , 2
    )                                                          AS recompra_90d
    , ROUND(
        100 * COUNT(volta_total) / COUNT(*)
        , 2
    )                                                          AS recompra_total_sem_mesmo_dia
FROM f

ORDER BY 1;
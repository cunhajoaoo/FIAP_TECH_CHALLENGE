-- =====================================================================
-- 06 - Base da previsao de GMV (Set-Dez/2018)
-- Janela: 2017-01 a 2018-08 (meses completos). t = meses desde 2017-01.
-- Resultado:
--   longo  : slope 41.885/mes, intercepto 274.573, R2 0,81 -> tendencia de crescimento 2017
--   2018   : slope -9.875/mes, intercepto 1.070.693, R2 0,13 -> PLATO (sem tendencia)
--   media 2018: 917.630 / desvio 67.441
--   Conservador = reta 2018 (t=20..23)
--   Base        = media 2018 x indice sazonal 2017 (Nov = 1,57x media Set-Out/17; Dez = 1,12x)
--   Otimista    = reta longa (t=20..23)
-- =====================================================================

WITH m AS (
    SELECT
        DATE_TRUNC(
            'month'
            , o.order_purchase_timestamp
        )::DATE                                             AS mes
        , SUM(i.price)                                      AS gmv
    FROM FIAP.HOMOLOG_DATA.ORDERS o
    JOIN FIAP.HOMOLOG_DATA.ORDER_ITEMS i
        USING (order_id)
    WHERE o.order_status NOT IN (
        'canceled'
        , 'unavailable'
    )
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY 1
)
, x AS (
    SELECT
        mes
        , gmv
        , DATEDIFF(
            'month'
            , '2017-01-01'
            , mes
        )                                                   AS t
    FROM m
)

SELECT
    'longo'                                                 AS janela
    , REGR_SLOPE(gmv, t)                                    AS slope
    , REGR_INTERCEPT(gmv, t)                                AS icpt
    , REGR_R2(gmv, t)                                       AS r2
FROM x

UNION ALL

SELECT
    'recente_2018'                                          AS janela
    , REGR_SLOPE(gmv, t)                                    AS slope
    , REGR_INTERCEPT(gmv, t)                                AS icpt
    , REGR_R2(gmv, t)                                       AS r2
FROM x
WHERE mes >= '2018-01-01'

UNION ALL

SELECT
    'media_2018'                                            AS janela
    , AVG(gmv)                                              AS slope
    , STDDEV(gmv)                                           AS icpt
    , NULL                                                  AS r2
FROM x
WHERE mes >= '2018-01-01';
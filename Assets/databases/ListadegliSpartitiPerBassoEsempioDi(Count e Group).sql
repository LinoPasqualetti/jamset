
SELECT
    Strumento,volume,
    COUNT(*) AS strumento
FROM
    spartiti
    where strumento like "%BA%"

GROUP BY
    strumento,volume
    order by volume
UPDATE "travelers" SET "balance" = (
  SELECT
    "balance"
  FROM (
    SELECT
      ((COALESCE("dbts"."amount", 0) - COALESCE("cdts"."amount", 0)) - COALESCE("pmts"."amount", 0)) AS balance,
      "travelers"."id"
    FROM
      "travelers"
    LEFT JOIN
    (
      SELECT
        "traveler_debits"."traveler_id",
        SUM("traveler_debits"."amount") AS amount
      FROM
        "traveler_debits"
      GROUP BY
        "traveler_debits"."traveler_id"
    ) "dbts"
      ON "dbts"."traveler_id" = "travelers"."id"
    LEFT JOIN
    (
      SELECT
        "traveler_credits"."traveler_id",
        SUM("traveler_credits"."amount") AS amount
      FROM
        "traveler_credits"
      GROUP BY
        "traveler_credits"."traveler_id"
    ) "cdts"
      ON "cdts"."traveler_id" = "travelers"."id"
    LEFT JOIN
    (
      SELECT
        "payment_items"."traveler_id",
        SUM("payment_items"."amount") AS amount
      FROM
        "payment_items"
      WHERE
        "payment_items"."traveler_id" IS NOT NULL
      GROUP BY
        "payment_items"."traveler_id"
    ) "pmts"
      ON "pmts"."traveler_id" = "travelers"."id"
  ) "traveler_balance"
  WHERE
    "traveler_balance"."id" = "travelers"."id"
)

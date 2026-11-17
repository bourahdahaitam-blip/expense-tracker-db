-- Expense Tracker: example queries
-- Run schema.sql and seed.sql first. User 1 is Lena, user 2 is Jonas.

USE expense_tracker;

-- 1. What is on every account?
--    The balance comes from the view account_balances. Mia's accounts have no bookings
--    and still show up with 0, because the view uses a LEFT JOIN.
SELECT u.first_name,
       ab.account_name,
       ab.account_type,
       ab.balance
FROM account_balances ab
         JOIN users u ON u.user_id = ab.user_id
ORDER BY u.user_id, ab.account_id;

-- 2. Where did Lena's money go in October 2026?
--    The date range is written as "from ... until before ..." so that the index on
--    (account_id, booking_date) can be used. The last condition skips the receiving
--    half of a transfer, which would otherwise cancel out the sending half.
SELECT g.name         AS category_group,
       c.name         AS category,
       -SUM(b.amount) AS amount
FROM bookings b
         JOIN accounts a ON a.account_id = b.account_id
         JOIN categories c ON c.category_id = b.category_id
         JOIN category_groups g ON g.group_id = c.group_id
WHERE a.user_id = 1
  AND b.booking_date >= '2026-10-01'
  AND b.booking_date < '2026-11-01'
  AND g.name <> 'Income'
  AND NOT (b.linked_booking_id IS NOT NULL AND b.amount > 0)
GROUP BY g.group_id, g.name, c.category_id, c.name
ORDER BY g.group_id, amount DESC;

-- 3. Did Lena and Jonas keep to their 50/30/20 targets in October 2026?
--    Each group's total is divided by the income of the same user and month.
SELECT u.first_name,
       t.group_name,
       t.total                                              AS amount,
       ROUND(100 * t.total / i.total, 1)                    AS actual_percent,
       q.percent                                            AS target_percent,
       ROUND(100 * t.total / i.total - q.percent, 1)        AS difference
FROM monthly_group_totals t
         JOIN monthly_group_totals i
              ON i.user_id = t.user_id
                  AND i.booking_month = t.booking_month
                  AND i.group_name = 'Income'
         JOIN users u ON u.user_id = t.user_id
         LEFT JOIN target_quotas q
                   ON q.user_id = t.user_id
                       AND q.group_id = t.group_id
WHERE t.booking_month = '2026-10'
  AND t.group_name <> 'Income'
ORDER BY t.user_id, t.group_id;

-- 4. Everything Jonas tagged "Vacation 2026".
--    The tag cuts across categories: flights are "Travel", the backpack is "Shopping".
SELECT b.booking_date,
       c.name AS category,
       p.name AS payee,
       b.amount,
       b.description
FROM tags t
         JOIN booking_tags bt ON bt.tag_id = t.tag_id
         JOIN bookings b ON b.booking_id = bt.booking_id
         JOIN categories c ON c.category_id = b.category_id
         LEFT JOIN payees p ON p.payee_id = b.payee_id
WHERE t.user_id = 2
  AND t.name = 'Vacation 2026'
ORDER BY b.booking_date;

-- 5. Lena's transfers, one line each.
--    A transfer is stored as two bookings, so the table is joined with itself:
--    "sent" is the half that left an account, "received" the half that arrived.
SELECT sent.booking_date,
       from_account.name AS from_account,
       to_account.name   AS to_account,
       received.amount,
       c.name            AS category
FROM bookings sent
         JOIN bookings received ON received.booking_id = sent.linked_booking_id
         JOIN accounts from_account ON from_account.account_id = sent.account_id
         JOIN accounts to_account ON to_account.account_id = received.account_id
         JOIN categories c ON c.category_id = sent.category_id
WHERE sent.amount < 0
  AND from_account.user_id = 1
ORDER BY sent.booking_date, sent.booking_id;

-- 6. Lena's five biggest payees.
SELECT p.name         AS payee,
       COUNT(*)       AS bookings,
       -SUM(b.amount) AS total_paid
FROM bookings b
         JOIN payees p ON p.payee_id = b.payee_id
WHERE p.user_id = 1
  AND b.amount < 0
GROUP BY p.payee_id, p.name
ORDER BY total_paid DESC
LIMIT 5;

-- 7. Lena's running fixed costs and income, converted to one month.
--    Only payments that have started and have not ended yet.
SELECT c.name AS category,
       p.name AS payee,
       r.frequency,
       r.amount,
       ROUND(r.amount * CASE r.frequency
                            WHEN 'weekly' THEN 52 / 12
                            WHEN 'monthly' THEN 1
                            WHEN 'quarterly' THEN 1 / 3
                            WHEN 'yearly' THEN 1 / 12
           END, 2) AS per_month
FROM recurring_payments r
         JOIN accounts a ON a.account_id = r.account_id
         JOIN categories c ON c.category_id = r.category_id
         LEFT JOIN payees p ON p.payee_id = r.payee_id
WHERE a.user_id = 1
  AND r.start_date <= CURRENT_DATE
  AND (r.end_date IS NULL OR r.end_date >= CURRENT_DATE)
ORDER BY per_month;

-- 8. Which categories can Jonas choose from?
--    The default ones (user_id IS NULL) plus his own.
SELECT g.name AS category_group,
       c.name AS category,
       CASE WHEN c.user_id IS NULL THEN 'default' ELSE 'own' END AS origin
FROM categories c
         JOIN category_groups g ON g.group_id = c.group_id
WHERE c.user_id IS NULL
   OR c.user_id = 2
ORDER BY g.group_id, c.name;

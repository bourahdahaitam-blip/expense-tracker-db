-- Expense Tracker: checks that the rules of the schema really hold
-- Run schema.sql and seed.sql first, then this file with --force so that it
-- continues after an error:
--
--   mysql -u root --force --table -e "source tests/checks.sql"
--
-- Part 1: every statement must fail with the error given above it.
-- Part 2: every line of the output must say PASS.
-- The data is the same afterwards as before.

USE expense_tracker;

-- The checks for ENUM and NOT NULL need strict mode. It is MariaDB's default, but an
-- installation can switch it off in its configuration, so it is switched on for this session.
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

SET @users = (SELECT COUNT(*) FROM users);
SET @accounts = (SELECT COUNT(*) FROM accounts);
SET @bookings = (SELECT COUNT(*) FROM bookings);
SET @categories = (SELECT COUNT(*) FROM categories);
SET @groups = (SELECT COUNT(*) FROM category_groups);
SET @booking_tags = (SELECT COUNT(*) FROM booking_tags);
SET @quotas = (SELECT COUNT(*) FROM target_quotas);
SET @recurring = (SELECT COUNT(*) FROM recurring_payments);

-- ---------------------------------------------------------------------------
-- Part 1: statements the database must reject
-- ---------------------------------------------------------------------------

-- 1. A booking on an account that does not exist: foreign key error (1452)
INSERT INTO bookings (account_id, category_id, booking_date, amount)
VALUES (999, 4, '2026-11-15', -10.00);

-- 2. A booking with a category that does not exist: foreign key error (1452)
INSERT INTO bookings (account_id, category_id, booking_date, amount)
VALUES (1, 999, '2026-11-15', -10.00);

-- 3. A booking over 0.00: CHECK constraint ck_bookings_amount failed (4025)
INSERT INTO bookings (account_id, category_id, booking_date, amount)
VALUES (1, 4, '2026-11-15', 0.00);

-- 4. A booking without a date: field has no default value (1364)
INSERT INTO bookings (account_id, category_id, amount)
VALUES (1, 4, -10.00);

-- 5. A third booking pointing at booking 3, which already has its other half: duplicate entry (1062)
INSERT INTO bookings (account_id, category_id, linked_booking_id, booking_date, amount)
VALUES (2, 14, 3, '2026-11-15', 250.00);

-- 6. A second user with an e-mail address that is taken: duplicate entry (1062)
INSERT INTO users (first_name, last_name, email, password_hash)
VALUES ('Lena', 'Double', 'lena.becker@example.com', 'x');

-- 7. A second account called "Checking" for the same user: duplicate entry (1062)
INSERT INTO accounts (user_id, name, account_type)
VALUES (1, 'Checking', 'checking');

-- 8. An account type that is not in the list: data truncated (1265)
INSERT INTO accounts (user_id, name, account_type)
VALUES (1, 'Coins', 'bitcoin');

-- 9. The same tag on the same booking twice: duplicate entry (1062)
INSERT INTO booking_tags (booking_id, tag_id)
VALUES (20, 2);

-- 10. A target of 150 percent: CHECK constraint ck_target_quotas_percent failed (4025)
INSERT INTO target_quotas (user_id, group_id, percent)
VALUES (3, 2, 150.00);

-- 11. A recurring payment that ends before it starts: CHECK constraint ck_recurring_dates failed (4025)
INSERT INTO recurring_payments (account_id, category_id, amount, frequency, start_date, end_date)
VALUES (1, 3, -600.00, 'monthly', '2026-06-01', '2026-05-01');

-- 12. Deleting a category that bookings use: foreign key error (1451)
DELETE FROM categories WHERE category_id = 4;

-- 13. Deleting a group that categories use: foreign key error (1451)
DELETE FROM category_groups WHERE group_id = 2;

SELECT IF((SELECT COUNT(*) FROM users) = @users
              AND (SELECT COUNT(*) FROM accounts) = @accounts
              AND (SELECT COUNT(*) FROM bookings) = @bookings
              AND (SELECT COUNT(*) FROM categories) = @categories
              AND (SELECT COUNT(*) FROM category_groups) = @groups
              AND (SELECT COUNT(*) FROM booking_tags) = @booking_tags
              AND (SELECT COUNT(*) FROM target_quotas) = @quotas
              AND (SELECT COUNT(*) FROM recurring_payments) = @recurring,
          'PASS', 'FAIL') AS result,
       'none of the 13 invalid statements changed any data' AS checked;

-- ---------------------------------------------------------------------------
-- Part 2: what happens on delete. Everything runs in a transaction that is
-- rolled back at the end.
-- ---------------------------------------------------------------------------

START TRANSACTION;

-- Bookings 3 and 4 are the two halves of one transfer.
DELETE FROM bookings WHERE booking_id = 3;
SELECT IF(COUNT(*) = 0, 'PASS', 'FAIL') AS result,
       'deleting one half of a transfer deletes the other half' AS checked
FROM bookings
WHERE booking_id IN (3, 4);

-- Payee 3 is Lena's supermarket, used by six bookings.
DELETE FROM payees WHERE payee_id = 3;
SELECT IF(COUNT(*) = 6 AND COUNT(payee_id) = 0, 'PASS', 'FAIL') AS result,
       'deleting a payee keeps its bookings and empties their payee' AS checked
FROM bookings
WHERE booking_id IN (8, 13, 18, 21, 28, 31);

-- Tag 1 is on bookings 8, 13 and 20.
DELETE FROM tags WHERE tag_id = 1;
SELECT IF((SELECT COUNT(*) FROM booking_tags WHERE tag_id = 1) = 0
              AND (SELECT COUNT(*) FROM bookings WHERE booking_id IN (8, 13, 20)) = 3,
          'PASS', 'FAIL') AS result,
       'deleting a tag removes it from its bookings and keeps the bookings' AS checked;

-- User 2 is Jonas: accounts, bookings, payees, tags, targets, his own categories and recurring payments.
DELETE FROM users WHERE user_id = 2;
SELECT IF((SELECT COUNT(*) FROM accounts WHERE user_id = 2) = 0
              AND (SELECT COUNT(*) FROM bookings WHERE account_id IN (4, 5, 6)) = 0
              AND (SELECT COUNT(*) FROM recurring_payments WHERE account_id IN (4, 5, 6)) = 0
              AND (SELECT COUNT(*) FROM payees WHERE user_id = 2) = 0
              AND (SELECT COUNT(*) FROM tags WHERE user_id = 2) = 0
              AND (SELECT COUNT(*) FROM booking_tags WHERE tag_id IN (3, 4)) = 0
              AND (SELECT COUNT(*) FROM target_quotas WHERE user_id = 2) = 0
              AND (SELECT COUNT(*) FROM categories WHERE user_id = 2) = 0,
          'PASS', 'FAIL') AS result,
       'deleting a user deletes everything the user owns' AS checked;

SELECT IF((SELECT COUNT(*) FROM categories WHERE user_id IS NULL) = 15
              AND (SELECT COUNT(*) FROM accounts WHERE user_id IN (1, 3)) = 5,
          'PASS', 'FAIL') AS result,
       'default categories and other users are untouched' AS checked;

ROLLBACK;

SELECT IF((SELECT COUNT(*) FROM users) = @users
              AND (SELECT COUNT(*) FROM bookings) = @bookings
              AND (SELECT COUNT(*) FROM booking_tags) = @booking_tags
              AND (SELECT COUNT(*) FROM categories) = @categories,
          'PASS', 'FAIL') AS result,
       'after the rollback the data is the same as before' AS checked;

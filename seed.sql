-- Expense Tracker: example data
-- Run schema.sql first. All people, payees and amounts are invented.
--
-- Lena's October follows the 50/30/20 rule exactly: 2,000 income, 1,000 needs,
-- 600 wants, 400 savings. Jonas has the same targets but misses them.
-- Mia has accounts and nothing else, to show what "empty" looks like.

USE expense_tracker;

START TRANSACTION;

-- Every demo user has the password "demo-password".
-- The hashes were created with PHP: password_hash('demo-password', PASSWORD_BCRYPT)
INSERT INTO users (user_id, first_name, last_name, email, password_hash, phone, created_at)
VALUES (1, 'Lena', 'Becker', 'lena.becker@example.com',
        '$2y$10$oIkLaRZ.2wgbJ6ZbGnJg.egFtEVdl9hRdefkVGA/ne/T2l04wJ3bC', NULL, '2025-04-01 09:30:00'),
       (2, 'Jonas', 'Weber', 'jonas.weber@example.com',
        '$2y$10$eLQFS0klD...lQjiPWjQq.Uz0W7rJAupI5qEfDhoopceGrP6EiYOG', NULL, '2025-08-01 18:05:00'),
       (3, 'Mia', 'Schulz', 'mia.schulz@example.com',
        '$2y$10$tbSCf1Dbf9Tj.YbQuZplgeoU7/o72ooYm6QN4oYjBCLxdIbOuhaRq', NULL, '2026-11-10 12:00:00');

INSERT INTO accounts (account_id, user_id, name, account_type)
VALUES (1, 1, 'Checking', 'checking'),
       (2, 1, 'Rainy-day savings', 'savings'),
       (3, 1, 'Brokerage', 'investment'),
       (4, 2, 'Checking', 'checking'),
       (5, 2, 'Credit card', 'credit_card'),
       (6, 2, 'Savings', 'savings'),
       (7, 3, 'Checking', 'checking'),
       (8, 3, 'Wallet', 'cash');

-- Jonas's own categories, in addition to the 15 default ones from schema.sql
INSERT INTO categories (category_id, group_id, user_id, name)
VALUES (16, 1, 2, 'Side job'),
       (17, 3, 2, 'Climbing gym');

-- Both users have a payee called "Employer": names only have to be unique per user.
INSERT INTO payees (payee_id, user_id, name)
VALUES (1, 1, 'Employer'),
       (2, 1, 'Landlord'),
       (3, 1, 'Supermarket'),
       (4, 1, 'Transit authority'),
       (5, 1, 'Railway'),
       (6, 1, 'Italian restaurant'),
       (7, 1, 'Cafe'),
       (8, 1, 'Sports club'),
       (9, 1, 'Ticket shop'),
       (10, 1, 'Video streaming'),
       (11, 1, 'Music streaming'),
       (12, 1, 'Software subscription'),
       (13, 1, 'Cloud storage'),
       (14, 1, 'Electronics store'),
       (15, 2, 'Employer'),
       (16, 2, 'Landlord'),
       (17, 2, 'Supermarket'),
       (18, 2, 'Energy provider'),
       (19, 2, 'Insurance company'),
       (20, 2, 'Transit authority'),
       (21, 2, 'Airline'),
       (22, 2, 'Restaurant'),
       (23, 2, 'Climbing hall'),
       (24, 2, 'Outdoor shop'),
       (25, 2, 'Tutoring client');

INSERT INTO tags (tag_id, user_id, name)
VALUES (1, 1, 'Shared with flatmate'),
       (2, 1, 'Birthday'),
       (3, 2, 'Vacation 2026'),
       (4, 2, 'Tax-relevant');

-- Both aim for 50 % needs, 30 % wants, 20 % savings (groups 2, 3, 4).
INSERT INTO target_quotas (user_id, group_id, percent)
VALUES (1, 2, 50.00),
       (1, 3, 30.00),
       (1, 4, 20.00),
       (2, 2, 50.00),
       (2, 3, 30.00),
       (2, 4, 20.00);

-- ---------------------------------------------------------------------------
-- Bookings. A transfer is two rows: money out of one account, money into another.
-- The second row points to the first here; the first is pointed back further down.
-- ---------------------------------------------------------------------------

-- Lena, October 2026
INSERT INTO bookings (booking_id, account_id, category_id, payee_id, linked_booking_id, booking_date, amount, description)
VALUES (1, 1, 1, 1, NULL, '2026-10-01', 2000.00, 'Salary October'),
       (2, 1, 3, 2, NULL, '2026-10-02', -600.00, 'Rent October'),
       (3, 1, 14, NULL, NULL, '2026-10-03', -250.00, 'Monthly saving'),
       (4, 2, 14, NULL, 3, '2026-10-03', 250.00, 'Monthly saving'),
       (5, 1, 15, NULL, NULL, '2026-10-03', -150.00, 'ETF savings plan'),
       (6, 3, 15, NULL, 5, '2026-10-03', 150.00, 'ETF savings plan'),
       (7, 1, 5, 4, NULL, '2026-10-05', -49.00, 'Monthly ticket'),
       (8, 1, 4, 3, NULL, '2026-10-06', -62.40, 'Weekly shopping'),
       (9, 1, 11, 10, NULL, '2026-10-08', -13.99, 'Video streaming'),
       (10, 1, 11, 11, NULL, '2026-10-08', -10.99, 'Music streaming'),
       (11, 1, 9, 6, NULL, '2026-10-10', -38.50, 'Dinner with friends'),
       (12, 1, 10, 8, NULL, '2026-10-12', -45.00, 'Membership fee'),
       (13, 1, 4, 3, NULL, '2026-10-13', -58.75, 'Weekly shopping'),
       (14, 1, 11, 12, NULL, '2026-10-15', -45.00, 'Software subscription'),
       (15, 1, 9, 7, NULL, '2026-10-16', -27.50, 'Brunch'),
       (16, 1, 5, 5, NULL, '2026-10-17', -101.00, 'Train tickets'),
       (17, 1, 10, 9, NULL, '2026-10-18', -155.00, 'Concert tickets'),
       (18, 1, 4, 3, NULL, '2026-10-20', -71.35, 'Weekly shopping'),
       (19, 1, 11, 13, NULL, '2026-10-22', -80.02, 'Cloud storage, yearly plan'),
       (20, 1, 9, 6, NULL, '2026-10-24', -120.00, 'Birthday dinner'),
       (21, 1, 4, 3, NULL, '2026-10-27', -57.50, 'Weekly shopping'),
       (22, 1, 9, 7, NULL, '2026-10-30', -64.00, 'Lunch with colleagues');

-- Lena, November 2026 (month still running). Bookings 29 and 30 are a purchase and its refund.
INSERT INTO bookings (booking_id, account_id, category_id, payee_id, linked_booking_id, booking_date, amount, description)
VALUES (23, 1, 1, 1, NULL, '2026-11-02', 2000.00, 'Salary November'),
       (24, 1, 3, 2, NULL, '2026-11-03', -600.00, 'Rent November'),
       (25, 1, 14, NULL, NULL, '2026-11-03', -250.00, 'Monthly saving'),
       (26, 2, 14, NULL, 25, '2026-11-03', 250.00, 'Monthly saving'),
       (27, 1, 5, 4, NULL, '2026-11-05', -49.00, 'Monthly ticket'),
       (28, 1, 4, 3, NULL, '2026-11-06', -66.10, 'Weekly shopping'),
       (29, 1, 12, 14, NULL, '2026-11-09', -59.99, 'Headphones'),
       (30, 1, 12, 14, NULL, '2026-11-12', 59.99, 'Headphones returned'),
       (31, 1, 4, 3, NULL, '2026-11-13', -54.30, 'Weekly shopping');

-- Jonas, October 2026. Bookings 41 and 43 were paid by credit card (account 5).
INSERT INTO bookings (booking_id, account_id, category_id, payee_id, linked_booking_id, booking_date, amount, description)
VALUES (32, 4, 1, 15, NULL, '2026-10-01', 2600.00, 'Salary October'),
       (33, 4, 3, 16, NULL, '2026-10-02', -850.00, 'Rent October'),
       (34, 4, 14, NULL, NULL, '2026-10-03', -280.00, 'Monthly saving'),
       (35, 6, 14, NULL, 34, '2026-10-03', 280.00, 'Monthly saving'),
       (36, 4, 6, 18, NULL, '2026-10-05', -95.00, 'Electricity and gas'),
       (37, 4, 7, 19, NULL, '2026-10-06', -120.00, 'Liability and household insurance'),
       (38, 4, 5, 20, NULL, '2026-10-07', -49.00, 'Monthly ticket'),
       (39, 4, 5, NULL, NULL, '2026-10-08', -116.00, 'Car sharing, several trips'),
       (40, 4, 4, 17, NULL, '2026-10-09', -164.30, 'Groceries'),
       (41, 5, 13, 21, NULL, '2026-10-11', -520.00, 'Flights to Lisbon'),
       (42, 4, 17, 23, NULL, '2026-10-14', -65.00, 'Monthly pass'),
       (43, 5, 9, 22, NULL, '2026-10-18', -180.00, 'Dinner with visiting friends'),
       (44, 4, 12, 24, NULL, '2026-10-21', -215.00, 'Backpack and hiking shoes'),
       (45, 4, 4, 17, NULL, '2026-10-23', -145.70, 'Groceries'),
       (46, 4, 16, 25, NULL, '2026-10-28', 200.00, 'Maths tutoring, October');

-- Close the loop: the first half of every transfer now points to the second half.
-- This cannot be done in the INSERT, because the second half does not exist yet at that point.
UPDATE bookings SET linked_booking_id = 4 WHERE booking_id = 3;
UPDATE bookings SET linked_booking_id = 6 WHERE booking_id = 5;
UPDATE bookings SET linked_booking_id = 26 WHERE booking_id = 25;
UPDATE bookings SET linked_booking_id = 35 WHERE booking_id = 34;

-- Booking 20 has two tags; the tag "Vacation 2026" spans two categories (travel and shopping).
INSERT INTO booking_tags (booking_id, tag_id)
VALUES (8, 1),
       (13, 1),
       (17, 2),
       (20, 1),
       (20, 2),
       (41, 3),
       (44, 3),
       (46, 4);

INSERT INTO recurring_payments (recurring_payment_id, account_id, category_id, payee_id, amount, frequency, start_date, end_date)
VALUES (1, 1, 1, 1, 2000.00, 'monthly', '2026-01-01', NULL),
       (2, 1, 3, 2, -600.00, 'monthly', '2025-04-01', NULL),
       (3, 1, 5, 4, -49.00, 'monthly', '2025-04-05', NULL),
       (4, 1, 11, 10, -13.99, 'monthly', '2025-09-08', NULL),
       (5, 1, 11, 13, -80.02, 'yearly', '2025-10-22', NULL),
       (6, 1, 10, 8, -45.00, 'monthly', '2025-01-12', '2026-12-31'),   -- membership cancelled for the end of the year
       (7, 4, 1, 15, 2600.00, 'monthly', '2025-08-01', NULL),
       (8, 4, 3, 16, -850.00, 'monthly', '2025-08-02', NULL),
       (9, 4, 6, 18, -95.00, 'monthly', '2025-08-05', NULL),
       (10, 4, 7, 19, -120.00, 'quarterly', '2025-10-06', NULL),
       (11, 4, 17, 23, -65.00, 'monthly', '2026-03-14', NULL);

COMMIT;

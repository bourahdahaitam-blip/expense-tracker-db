-- Expense Tracker: database schema
-- Written for MariaDB, the database that ships with XAMPP. Tested on MariaDB 10.11.
-- Running this file again deletes the database and builds it from scratch.

DROP DATABASE IF EXISTS expense_tracker;
CREATE DATABASE expense_tracker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE expense_tracker;

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------

CREATE TABLE users (
    user_id        INT          NOT NULL AUTO_INCREMENT,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(255) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,   -- never the password itself, only its hash
    phone          VARCHAR(30)  NULL,       -- optional
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email UNIQUE (email)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
-- Accounts: a user has several accounts
-- ---------------------------------------------------------------------------

CREATE TABLE accounts (
    account_id    INT         NOT NULL AUTO_INCREMENT,
    user_id       INT         NOT NULL,
    name          VARCHAR(50) NOT NULL,
    account_type  ENUM ('checking', 'savings', 'cash', 'credit_card', 'investment') NOT NULL,
    -- No balance column: the balance is the sum of the bookings (see view account_balances).
    PRIMARY KEY (account_id),
    CONSTRAINT uq_accounts_user_name UNIQUE (user_id, name),
    CONSTRAINT fk_accounts_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
-- Category groups and categories
-- "GROUP" is a reserved word in SQL, hence the longer table name.
-- ---------------------------------------------------------------------------

CREATE TABLE category_groups (
    group_id  INT         NOT NULL AUTO_INCREMENT,
    name      VARCHAR(30) NOT NULL,
    PRIMARY KEY (group_id),
    CONSTRAINT uq_category_groups_name UNIQUE (name)
) ENGINE = InnoDB;

CREATE TABLE categories (
    category_id  INT         NOT NULL AUTO_INCREMENT,
    group_id     INT         NOT NULL,
    user_id      INT         NULL,      -- NULL = default category that every user can use
    name         VARCHAR(50) NOT NULL,
    PRIMARY KEY (category_id),
    -- Stops a user from having two categories with the same name. It does not cover the
    -- default categories, because UNIQUE treats every NULL as a different value.
    CONSTRAINT uq_categories_user_name UNIQUE (user_id, name),
    CONSTRAINT fk_categories_group FOREIGN KEY (group_id)
        REFERENCES category_groups (group_id),
    CONSTRAINT fk_categories_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
-- Payees (who money goes to or comes from) and tags, both private to a user
-- ---------------------------------------------------------------------------

CREATE TABLE payees (
    payee_id  INT          NOT NULL AUTO_INCREMENT,
    user_id   INT          NOT NULL,
    name      VARCHAR(100) NOT NULL,
    PRIMARY KEY (payee_id),
    CONSTRAINT uq_payees_user_name UNIQUE (user_id, name),
    CONSTRAINT fk_payees_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE tags (
    tag_id   INT         NOT NULL AUTO_INCREMENT,
    user_id  INT         NOT NULL,
    name     VARCHAR(50) NOT NULL,
    PRIMARY KEY (tag_id),
    CONSTRAINT uq_tags_user_name UNIQUE (user_id, name),
    CONSTRAINT fk_tags_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
-- Bookings: every movement of money on an account
-- ---------------------------------------------------------------------------

CREATE TABLE bookings (
    booking_id         INT            NOT NULL AUTO_INCREMENT,
    account_id         INT            NOT NULL,
    category_id        INT            NOT NULL,
    payee_id           INT            NULL,       -- a transfer between own accounts has no payee
    linked_booking_id  INT            NULL,       -- the other half of a transfer, otherwise NULL
    booking_date       DATE           NOT NULL,
    amount             DECIMAL(12, 2) NOT NULL,   -- negative = money out, positive = money in
    description        VARCHAR(255)   NULL,
    -- There is no user_id here: the owner of a booking is the owner of its account.
    PRIMARY KEY (booking_id),
    -- A booking can be the other half of at most one booking (1:1).
    CONSTRAINT uq_bookings_linked UNIQUE (linked_booking_id),
    CONSTRAINT ck_bookings_amount CHECK (amount <> 0),
    CONSTRAINT fk_bookings_account FOREIGN KEY (account_id)
        REFERENCES accounts (account_id) ON DELETE CASCADE,
    -- A category that is in use cannot be deleted (the default behaviour, RESTRICT).
    CONSTRAINT fk_bookings_category FOREIGN KEY (category_id)
        REFERENCES categories (category_id),
    -- Deleting a payee keeps the bookings and only empties the reference.
    CONSTRAINT fk_bookings_payee FOREIGN KEY (payee_id)
        REFERENCES payees (payee_id) ON DELETE SET NULL,
    -- Deleting one half of a transfer deletes the other half too.
    CONSTRAINT fk_bookings_linked FOREIGN KEY (linked_booking_id)
        REFERENCES bookings (booking_id) ON DELETE CASCADE,
    -- Most questions are "what happened on this account in this period".
    INDEX ix_bookings_account_date (account_id, booking_date)
) ENGINE = InnoDB;

-- n:m between bookings and tags
CREATE TABLE booking_tags (
    booking_id  INT NOT NULL,
    tag_id      INT NOT NULL,
    PRIMARY KEY (booking_id, tag_id),   -- the same tag cannot be put on a booking twice
    CONSTRAINT fk_booking_tags_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (booking_id) ON DELETE CASCADE,
    CONSTRAINT fk_booking_tags_tag FOREIGN KEY (tag_id)
        REFERENCES tags (tag_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
-- Target quotas: n:m between users and category groups, with the percentage
-- as an attribute of the relationship (for example 50 / 30 / 20)
-- ---------------------------------------------------------------------------

CREATE TABLE target_quotas (
    user_id   INT           NOT NULL,
    group_id  INT           NOT NULL,
    percent   DECIMAL(5, 2) NOT NULL,
    PRIMARY KEY (user_id, group_id),    -- one quota per user and group
    CONSTRAINT ck_target_quotas_percent CHECK (percent BETWEEN 0 AND 100),
    CONSTRAINT fk_target_quotas_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_target_quotas_group FOREIGN KEY (group_id)
        REFERENCES category_groups (group_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
-- Recurring payments: rent, subscriptions, salary
-- "INTERVAL" is a reserved word, so the column is called frequency.
-- ---------------------------------------------------------------------------

CREATE TABLE recurring_payments (
    recurring_payment_id  INT            NOT NULL AUTO_INCREMENT,
    account_id            INT            NOT NULL,
    category_id           INT            NOT NULL,
    payee_id              INT            NULL,
    amount                DECIMAL(12, 2) NOT NULL,   -- negative = money out, positive = money in
    frequency             ENUM ('weekly', 'monthly', 'quarterly', 'yearly') NOT NULL,
    start_date            DATE           NOT NULL,
    end_date              DATE           NULL,       -- NULL = runs until cancelled
    PRIMARY KEY (recurring_payment_id),
    CONSTRAINT ck_recurring_amount CHECK (amount <> 0),
    CONSTRAINT ck_recurring_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT fk_recurring_account FOREIGN KEY (account_id)
        REFERENCES accounts (account_id) ON DELETE CASCADE,
    CONSTRAINT fk_recurring_category FOREIGN KEY (category_id)
        REFERENCES categories (category_id),
    CONSTRAINT fk_recurring_payee FOREIGN KEY (payee_id)
        REFERENCES payees (payee_id) ON DELETE SET NULL
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
-- Deleting a user
-- ---------------------------------------------------------------------------

-- ON DELETE CASCADE removes everything a user owns. One case needs help: a user's own
-- category cannot be deleted while bookings still use it, and the database does not
-- promise in which order it works through the cascades. This trigger deletes the
-- accounts (and with them the bookings and recurring payments) first, so the order
-- no longer matters.
CREATE TRIGGER users_before_delete
    BEFORE DELETE
    ON users
    FOR EACH ROW
    DELETE FROM accounts WHERE user_id = OLD.user_id;

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------

-- The balance of an account is calculated, not stored, so it can never be out of date.
CREATE VIEW account_balances AS
SELECT a.account_id,
       a.user_id,
       a.name                       AS account_name,
       a.account_type,
       COALESCE(SUM(b.amount), 0)   AS balance
FROM accounts a
         LEFT JOIN bookings b ON b.account_id = a.account_id
GROUP BY a.account_id, a.user_id, a.name, a.account_type;

-- Money per user, month and category group.
-- Income counts as received. In the other groups, money leaving an account counts as
-- positive, so a refund lowers the total again. Saving is a transfer to a savings or
-- investment account: its outgoing half counts, its incoming half is skipped, otherwise
-- the two halves would cancel each other out.
CREATE VIEW monthly_group_totals AS
SELECT a.user_id,
       DATE_FORMAT(b.booking_date, '%Y-%m')                                AS booking_month,
       g.group_id,
       g.name                                                              AS group_name,
       SUM(CASE WHEN g.name = 'Income' THEN b.amount ELSE -b.amount END)   AS total
FROM bookings b
         JOIN accounts a ON a.account_id = b.account_id
         JOIN categories c ON c.category_id = b.category_id
         JOIN category_groups g ON g.group_id = c.group_id
WHERE NOT (b.linked_booking_id IS NOT NULL AND b.amount > 0)
GROUP BY a.user_id, DATE_FORMAT(b.booking_date, '%Y-%m'), g.group_id, g.name;

-- ---------------------------------------------------------------------------
-- Reference data: the four groups and the default categories
-- ---------------------------------------------------------------------------

INSERT INTO category_groups (group_id, name)
VALUES (1, 'Income'),
       (2, 'Needs'),
       (3, 'Wants'),
       (4, 'Savings');

INSERT INTO categories (category_id, group_id, user_id, name)
VALUES (1, 1, NULL, 'Salary'),
       (2, 1, NULL, 'Other income'),
       (3, 2, NULL, 'Rent'),
       (4, 2, NULL, 'Groceries'),
       (5, 2, NULL, 'Transport'),
       (6, 2, NULL, 'Utilities'),
       (7, 2, NULL, 'Insurance'),
       (8, 2, NULL, 'Health'),
       (9, 3, NULL, 'Eating out'),
       (10, 3, NULL, 'Hobbies'),
       (11, 3, NULL, 'Subscriptions'),
       (12, 3, NULL, 'Shopping'),
       (13, 3, NULL, 'Travel'),
       (14, 4, NULL, 'Emergency fund'),
       (15, 4, NULL, 'Investing');

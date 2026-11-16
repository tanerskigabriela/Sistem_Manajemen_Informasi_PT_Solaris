USE solaris_db;
GO

INSERT INTO product_types (type_code, type_name) VALUES
 ('CL', N'Celana'), ('KM', N'Kemeja'), ('KS', N'Kaos'), ('PL', N'Kaos Polo'),
 ('DR', N'Dress'), ('JK', N'Jaket Ringan'), ('SR', N'Seragam');
GO

DECLARE @marketing UNIQUEIDENTIFIER = (SELECT id FROM users WHERE username = 'marketing');
DECLARE @pimpinan  UNIQUEIDENTIFIER = (SELECT id FROM users WHERE username = 'pimpinan');

DECLARE @lsb UNIQUEIDENTIFIER = NEWID(), @brt UNIQUEIDENTIFIER = NEWID(), @smj UNIQUEIDENTIFIER = NEWID();
INSERT INTO buyers (id, buyer_name, buyer_code, contact) VALUES
 (@lsb, N'CV Lestari Busana',       'LSB', N'Bu Rina, 0812-0000-1111'),
 (@brt, N'PT Bintang Rapi Tekstil', 'BRT', N'Pak Dodi, 0813-0000-2222'),
 (@smj, N'UD Sinar Maju Jaya',      'SMJ', N'Mbak Tari, 0857-0000-3333');

DECLARE @it1 UNIQUEIDENTIFIER = NEWID(), @it2 UNIQUEIDENTIFIER = NEWID(), @it3 UNIQUEIDENTIFIER = NEWID();
INSERT INTO items (id, item_code, buyer_id, type_code, buyer_style_name) VALUES
 (@it1, 'LSB-DR-0001', @lsb, 'DR', N'Dress Lily'),
 (@it2, 'LSB-KM-0002', @lsb, 'KM', N'Kemeja Linen'),
 (@it3, 'BRT-KS-0001', @brt, 'KS', N'Kaos Basic Crew');

-- Order 1: sudah DISETUJUI (dipakai C untuk mencoba SPK)
DECLARE @o1 UNIQUEIDENTIFIER = NEWID();
INSERT INTO orders (id, order_code, buyer_id, order_date, deadline, scheme, reject_limit_pct, late_penalty, status, created_by)
VALUES (@o1, 'ORD-2611-001', @lsb, '2026-11-02', '2026-12-20', 'CMT', 3.00,
        N'Potongan 2% dari nilai order per minggu keterlambatan', 'DISETUJUI', @marketing);
INSERT INTO order_status_history (order_id, status, changed_by, reason, changed_at) VALUES
 (@o1, 'MENUNGGU_PERSETUJUAN', @marketing, NULL, '2026-11-02 09:00'),
 (@o1, 'DISETUJUI',            @pimpinan,  NULL, '2026-11-03 10:00');
DECLARE @s1 UNIQUEIDENTIFIER = NEWID(), @s2 UNIQUEIDENTIFIER = NEWID();
INSERT INTO order_styles (id, order_id, item_id, color, price_per_pcs) VALUES
 (@s1, @o1, @it1, N'Navy',  85000),
 (@s2, @o1, @it2, N'Putih', 95000);
INSERT INTO order_style_sizes (style_id, size, qty) VALUES
 (@s1, 'S', 100), (@s1, 'M', 150), (@s1, 'L', 100),
 (@s2, 'M', 120), (@s2, 'L', 120), (@s2, 'XL', 60);

-- Order 2: masih MENUNGGU_PERSETUJUAN (untuk menguji tombol setujui/tolak)
DECLARE @o2 UNIQUEIDENTIFIER = NEWID(), @s3 UNIQUEIDENTIFIER = NEWID();
INSERT INTO orders (id, order_code, buyer_id, order_date, deadline, scheme, reject_limit_pct, late_penalty, created_by)
VALUES (@o2, 'ORD-2611-002', @brt, '2026-11-10', '2027-01-15', 'FOB', 2.50,
        N'Potongan 1% per hari keterlambatan, maksimal 10%', @marketing);
INSERT INTO order_status_history (order_id, status, changed_by, changed_at) VALUES
 (@o2, 'MENUNGGU_PERSETUJUAN', @marketing, '2026-11-10 13:30');
INSERT INTO order_styles (id, order_id, item_id, color, price_per_pcs) VALUES
 (@s3, @o2, @it3, N'Hitam', 42000);
INSERT INTO order_style_sizes (style_id, size, qty) VALUES
 (@s3, 'M', 300), (@s3, 'L', 300), (@s3, 'XL', 200);
GO
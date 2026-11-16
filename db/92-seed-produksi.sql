/* =============================================================================
   92-seed-produksi.sql — Data awal modul Produksi (pemilik: C)
   Project Solaris · Kelompok 1 · RSI Kelas A

   Isi    : 2 supplier, lalu bahan baku untuk setiap style pada order seed
            berstatus DISETUJUI milik B (91-seed-order.sql).
   Urutan : dijalankan SETELAH 90-seed-core.sql (akun ppic) dan 91-seed-order.sql.
   Catatan:
   - Tanpa variabel (@...), supaya bisa dijalankan di DBeaver, SSMS, maupun VS Code.
   - Aman dijalankan ulang: setiap INSERT dijaga NOT EXISTS.
   - Sengaja TIDAK membuat SPK, supaya alur "ajukan SPK" bisa diuji dari awal.
   ============================================================================= */

USE solaris_db;
GO

-- ---------------------------------------------------------------- prasyarat
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = 'ppic')
    RAISERROR('Akun ppic belum ada. Jalankan 90-seed-core.sql dulu.', 16, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.orders WHERE status = 'DISETUJUI')
    RAISERROR('Belum ada order DISETUJUI. Jalankan 91-seed-order.sql dulu (R-05).', 16, 1);

-- ------------------------------------------------------------------ suppliers
IF NOT EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_name = N'CV Sinar Tekstil')
    INSERT INTO dbo.suppliers (supplier_name, contact, payment_term)
    VALUES (N'CV Sinar Tekstil', N'Bpk. Hendra · 0812-3456-7801', 'DP');

IF NOT EXISTS (SELECT 1 FROM dbo.suppliers WHERE supplier_name = N'UD Benang Jaya')
    INSERT INTO dbo.suppliers (supplier_name, contact, payment_term)
    VALUES (N'UD Benang Jaya', N'Ibu Ratna · 0813-2222-9034', 'LUNAS_AWAL');

-- -------------------------------------------- bahan untuk order seed milik B
-- Setiap style mendapat 3 bahan: kain (supplier), benang (supplier), label (buyer).
-- Jumlah bahan dihitung kasar dari total pcs per style.
WITH seed_order AS (
    SELECT TOP 1 id FROM dbo.orders WHERE status = 'DISETUJUI' ORDER BY created_at
),
style_qty AS (
    SELECT os.id AS style_id, SUM(sz.qty) AS total_pcs
    FROM dbo.order_styles os
    JOIN dbo.order_style_sizes sz ON sz.style_id = os.id
    WHERE os.order_id = (SELECT id FROM seed_order)
    GROUP BY os.id
),
bahan AS (
    SELECT style_id, N'Kain Cotton Combed 30s' AS material_name,
           CAST(total_pcs * 0.30 AS DECIMAL(12,2)) AS qty, N'kg' AS unit, 'SUPPLIER' AS source,
           (SELECT id FROM dbo.suppliers WHERE supplier_name = N'CV Sinar Tekstil') AS supplier_id,
           CAST(98000 AS DECIMAL(14,2)) AS material_price
    FROM style_qty
    UNION ALL
    SELECT style_id, N'Benang Jahit Polyester',
           CAST(CEILING(total_pcs / 50.0) AS DECIMAL(12,2)), N'cone', 'SUPPLIER',
           (SELECT id FROM dbo.suppliers WHERE supplier_name = N'UD Benang Jaya'),
           CAST(18500 AS DECIMAL(14,2))
    FROM style_qty
    UNION ALL
    SELECT style_id, N'Label Merek Buyer',
           CAST(total_pcs AS DECIMAL(12,2)), N'pcs', 'BUYER',
           NULL, NULL
    FROM style_qty
)
INSERT INTO dbo.materials
    (style_id, material_name, qty, unit, source, supplier_id, material_price, received_date, checked_by)
SELECT b.style_id, b.material_name, b.qty, b.unit, b.source, b.supplier_id, b.material_price,
       CAST(SYSDATETIME() AS DATE),
       (SELECT id FROM dbo.users WHERE username = 'ppic')
FROM bahan b
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.materials m
    WHERE m.style_id = b.style_id AND m.material_name = b.material_name
);

-- ------------------------------------------------------------------- ringkasan
SELECT
    (SELECT COUNT(*) FROM dbo.suppliers) AS jumlah_supplier,
    (SELECT COUNT(*) FROM dbo.materials) AS jumlah_bahan;
GO
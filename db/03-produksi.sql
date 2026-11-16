/* =============================================================================
   03-produksi.sql — Tabel modul Produksi (pemilik: C)
   Project Solaris · Kelompok 1 · RSI Kelas A

   Sumber : KONTRAK.md Bagian 4.3 dan 5, TSD Tabel 14–19 dan 4.4 (index)
   Urutan : dijalankan SETELAH 01-core.sql (users) dan 02-order.sql
            (order_styles, shipments), karena ada FK ke tabel-tabel itu.
   Catatan:
   - Tidak ada ON DELETE CASCADE: data transaksi tidak pernah dihapus.
   - Aturan yang butuh hitungan kumulatif (RB-37, RB-38, RB-42) tidak bisa
     ditulis sebagai CHECK; aturan itu dijaga di SP/service (05-objects-produksi.sql).
   - updated_at diisi ulang oleh aplikasi/SP setiap kali baris diubah.
   ============================================================================= */

USE solaris_db;
GO

-- ------------------------------------------------------------------ suppliers
IF OBJECT_ID('dbo.suppliers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.suppliers (
        id            UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_suppliers_id DEFAULT NEWSEQUENTIALID(),
        supplier_name NVARCHAR(100)    NOT NULL,
        contact       NVARCHAR(100)    NOT NULL,
        payment_term  VARCHAR(10)      NOT NULL
            CONSTRAINT CK_suppliers_payment_term CHECK (payment_term IN ('LUNAS_AWAL', 'DP', 'KREDIT')),
        created_at    DATETIME2(0)     NOT NULL CONSTRAINT DF_suppliers_created_at DEFAULT SYSDATETIME(),
        CONSTRAINT PK_suppliers PRIMARY KEY (id)
    );
END
GO

-- ------------------------------------------------------------------ materials
IF OBJECT_ID('dbo.materials', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.materials (
        id             UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_materials_id DEFAULT NEWSEQUENTIALID(),
        style_id       UNIQUEIDENTIFIER NOT NULL,
        material_name  NVARCHAR(100)    NOT NULL,
        qty            DECIMAL(12,2)    NOT NULL CONSTRAINT CK_materials_qty CHECK (qty > 0),
        unit           NVARCHAR(20)     NOT NULL,
        source         VARCHAR(8)       NOT NULL
            CONSTRAINT CK_materials_source CHECK (source IN ('BUYER', 'SUPPLIER')),
        supplier_id    UNIQUEIDENTIFIER NULL,
        material_price DECIMAL(14,2)    NULL
            CONSTRAINT CK_materials_price CHECK (material_price IS NULL OR material_price > 0),
        received_date  DATE             NOT NULL,
        checked_by     UNIQUEIDENTIFIER NOT NULL,
        checked_at     DATETIME2(0)     NOT NULL CONSTRAINT DF_materials_checked_at DEFAULT SYSDATETIME(),
        updated_at     DATETIME2(0)     NOT NULL CONSTRAINT DF_materials_updated_at DEFAULT SYSDATETIME(),
        CONSTRAINT PK_materials PRIMARY KEY (id),
        CONSTRAINT FK_materials_order_styles FOREIGN KEY (style_id)    REFERENCES dbo.order_styles (id),
        CONSTRAINT FK_materials_suppliers    FOREIGN KEY (supplier_id) REFERENCES dbo.suppliers (id),
        CONSTRAINT FK_materials_users        FOREIGN KEY (checked_by)  REFERENCES dbo.users (id),
        -- RB-26: supplier dan harga bahan wajib bila bahan berasal dari supplier
        CONSTRAINT CK_materials_supplier_required CHECK (
            source <> 'SUPPLIER' OR (supplier_id IS NOT NULL AND material_price IS NOT NULL)
        )
    );

    CREATE INDEX IX_materials_style_id    ON dbo.materials (style_id);
    CREATE INDEX IX_materials_supplier_id ON dbo.materials (supplier_id);
END
GO

-- ------------------------------------------------------------------------ spk
IF OBJECT_ID('dbo.spk', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.spk (
        id                    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_spk_id DEFAULT NEWSEQUENTIALID(),
        spk_no                CHAR(12)         NOT NULL,
        style_id              UNIQUEIDENTIFIER NOT NULL,
        target_date           DATE             NOT NULL,
        status                VARCHAR(20)      NOT NULL CONSTRAINT DF_spk_status DEFAULT 'MENUNGGU_PERSETUJUAN'
            CONSTRAINT CK_spk_status CHECK (status IN ('MENUNGGU_PERSETUJUAN', 'DISETUJUI', 'DITOLAK')),
        materials_complete_by UNIQUEIDENTIFIER NOT NULL,
        decided_by            UNIQUEIDENTIFIER NULL,
        approved_at           DATETIME2(0)     NULL,
        reject_reason         NVARCHAR(500)    NULL,
        created_at            DATETIME2(0)     NOT NULL CONSTRAINT DF_spk_created_at DEFAULT SYSDATETIME(),
        CONSTRAINT PK_spk PRIMARY KEY (id),
        CONSTRAINT UQ_spk_spk_no UNIQUE (spk_no),
        CONSTRAINT FK_spk_order_styles   FOREIGN KEY (style_id)              REFERENCES dbo.order_styles (id),
        CONSTRAINT FK_spk_users_complete FOREIGN KEY (materials_complete_by) REFERENCES dbo.users (id),
        CONSTRAINT FK_spk_users_decided  FOREIGN KEY (decided_by)            REFERENCES dbo.users (id),
        -- Format nomor SPK-TTBB-NNN
        CONSTRAINT CK_spk_spk_no_format CHECK (spk_no LIKE 'SPK-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]'),
        -- Alasan wajib diisi bila SPK ditolak (RB-33)
        CONSTRAINT CK_spk_reject_reason CHECK (
            status <> 'DITOLAK' OR (reject_reason IS NOT NULL AND LEN(LTRIM(RTRIM(reject_reason))) > 0)
        ),
        -- SPK yang sudah disetujui harus punya waktu persetujuan (dasar RB-45)
        CONSTRAINT CK_spk_approved_at CHECK (status <> 'DISETUJUI' OR approved_at IS NOT NULL)
    );

    -- RB-31: satu SPK berlaku per style; SPK yang DITOLAK tidak dihitung
    CREATE UNIQUE INDEX UX_spk_style_active ON dbo.spk (style_id)
        WHERE status IN ('MENUNGGU_PERSETUJUAN', 'DISETUJUI');
    CREATE INDEX IX_spk_status ON dbo.spk (status);
END
GO

-- ------------------------------------------------------------------ spk_sizes
IF OBJECT_ID('dbo.spk_sizes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.spk_sizes (
        spk_id UNIQUEIDENTIFIER NOT NULL,
        size   VARCHAR(10)      NOT NULL,
        qty    INT              NOT NULL CONSTRAINT CK_spk_sizes_qty CHECK (qty > 0),
        CONSTRAINT PK_spk_sizes PRIMARY KEY (spk_id, size),
        CONSTRAINT FK_spk_sizes_spk FOREIGN KEY (spk_id) REFERENCES dbo.spk (id)
    );
END
GO

-- -------------------------------------------------------- production_progress
IF OBJECT_ID('dbo.production_progress', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.production_progress (
        id            UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_production_progress_id DEFAULT NEWSEQUENTIALID(),
        spk_id        UNIQUEIDENTIFIER NOT NULL,
        stage         VARCHAR(10)      NOT NULL
            CONSTRAINT CK_production_progress_stage
            CHECK (stage IN ('CUTTING', 'SEWING', 'TRIMMING', 'FINISHING', 'IRONING', 'PACKING')),
        work_date     DATE             NOT NULL,
        qty_done      INT              NOT NULL CONSTRAINT CK_production_progress_qty CHECK (qty_done >= 0),
        variance_note NVARCHAR(300)    NULL,      -- wajib bila kumulatif Cutting ≠ jumlah SPK (RB-38, dicek di SP)
        recorded_by   UNIQUEIDENTIFIER NOT NULL,
        created_at    DATETIME2(0)     NOT NULL CONSTRAINT DF_production_progress_created_at DEFAULT SYSDATETIME(),
        updated_at    DATETIME2(0)     NOT NULL CONSTRAINT DF_production_progress_updated_at DEFAULT SYSDATETIME(),
        CONSTRAINT PK_production_progress PRIMARY KEY (id),
        CONSTRAINT FK_production_progress_spk   FOREIGN KEY (spk_id)      REFERENCES dbo.spk (id),
        CONSTRAINT FK_production_progress_users FOREIGN KEY (recorded_by) REFERENCES dbo.users (id),
        -- RB-36: satu data progres per SPK, tahap, dan tanggal
        CONSTRAINT UQ_production_progress_spk_stage_date UNIQUE (spk_id, stage, work_date)
    );

    CREATE INDEX IX_production_progress_work_date ON dbo.production_progress (work_date);
END
GO

-- ----------------------------------------------------------------- qc_results
IF OBJECT_ID('dbo.qc_results', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.qc_results (
        id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_qc_results_id DEFAULT NEWSEQUENTIALID(),
        spk_id      UNIQUEIDENTIFIER NOT NULL,
        stage       VARCHAR(10)      NOT NULL
            CONSTRAINT CK_qc_results_stage                      -- RB-41: tanpa PACKING
            CHECK (stage IN ('CUTTING', 'SEWING', 'TRIMMING', 'FINISHING', 'IRONING')),
        check_date  DATE             NOT NULL,
        qty_passed  INT              NOT NULL CONSTRAINT CK_qc_results_qty CHECK (qty_passed >= 0),
        recorded_by UNIQUEIDENTIFIER NOT NULL,
        created_at  DATETIME2(0)     NOT NULL CONSTRAINT DF_qc_results_created_at DEFAULT SYSDATETIME(),
        CONSTRAINT PK_qc_results PRIMARY KEY (id),
        CONSTRAINT FK_qc_results_spk   FOREIGN KEY (spk_id)      REFERENCES dbo.spk (id),
        CONSTRAINT FK_qc_results_users FOREIGN KEY (recorded_by) REFERENCES dbo.users (id)
    );

    CREATE INDEX IX_qc_results_spk_stage ON dbo.qc_results (spk_id, stage);
END
GO

-- ----------------------------------------------------------- signed_documents
-- Prioritas Terakhir. Tabel tetap dibuat sejak Hari 1 supaya skema lengkap;
-- larangan UPDATE/DELETE dipasang lewat trg_signed_documents_append_only (file 05).
IF OBJECT_ID('dbo.signed_documents', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.signed_documents (
        id            UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_signed_documents_id DEFAULT NEWSEQUENTIALID(),
        doc_type      VARCHAR(12)      NOT NULL
            CONSTRAINT CK_signed_documents_doc_type CHECK (doc_type IN ('SPK', 'SURAT_JALAN')),
        spk_id        UNIQUEIDENTIFIER NULL,
        shipment_id   UNIQUEIDENTIFIER NULL,
        version       INT              NOT NULL CONSTRAINT CK_signed_documents_version CHECK (version >= 1),
        original_name NVARCHAR(200)    NOT NULL,
        stored_name   VARCHAR(45)      NOT NULL,
        mime_type     VARCHAR(30)      NOT NULL
            CONSTRAINT CK_signed_documents_mime CHECK (mime_type IN ('image/jpeg', 'image/png', 'application/pdf')),
        size_bytes    INT              NOT NULL
            CONSTRAINT CK_signed_documents_size CHECK (size_bytes BETWEEN 1 AND 5242880),
        sha256        CHAR(64)         NOT NULL,
        uploaded_by   UNIQUEIDENTIFIER NOT NULL,
        uploaded_at   DATETIME2(0)     NOT NULL CONSTRAINT DF_signed_documents_uploaded_at DEFAULT SYSDATETIME(),
        CONSTRAINT PK_signed_documents PRIMARY KEY (id),
        CONSTRAINT UQ_signed_documents_stored_name UNIQUE (stored_name),
        CONSTRAINT FK_signed_documents_spk       FOREIGN KEY (spk_id)      REFERENCES dbo.spk (id),
        CONSTRAINT FK_signed_documents_shipments FOREIGN KEY (shipment_id) REFERENCES dbo.shipments (id),
        CONSTRAINT FK_signed_documents_users     FOREIGN KEY (uploaded_by) REFERENCES dbo.users (id),
        -- Tepat satu dari spk_id dan shipment_id terisi, sesuai doc_type
        CONSTRAINT CK_signed_documents_target CHECK (
               (doc_type = 'SPK'         AND spk_id IS NOT NULL AND shipment_id IS NULL)
            OR (doc_type = 'SURAT_JALAN' AND shipment_id IS NOT NULL AND spk_id IS NULL)
        )
    );

    -- Nomor versi unik per dokumen (SPK atau surat jalan yang sama)
    CREATE UNIQUE INDEX UX_signed_documents_version
        ON dbo.signed_documents (doc_type, spk_id, shipment_id, version);
END
GO
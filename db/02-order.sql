USE solaris_db;
GO

CREATE TABLE buyers (
    id          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    buyer_name  NVARCHAR(100)    NOT NULL,
    buyer_code  CHAR(3)          NOT NULL,
    contact     NVARCHAR(100)    NOT NULL,
    created_at  DATETIME2(0)     NOT NULL DEFAULT SYSDATETIME(),
    updated_at  DATETIME2(0)     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_buyers PRIMARY KEY (id),
    CONSTRAINT uq_buyers_code UNIQUE (buyer_code),
    -- COLLATE ..._BIN supaya huruf kecil (brt) ikut ditolak
    CONSTRAINT ck_buyers_code CHECK (buyer_code COLLATE Latin1_General_BIN LIKE '[A-Z][A-Z][A-Z]')
);
GO

CREATE TABLE product_types (
    type_code  CHAR(2)      NOT NULL,
    type_name  NVARCHAR(30) NOT NULL,
    CONSTRAINT pk_product_types PRIMARY KEY (type_code)
);
GO

CREATE TABLE items (
    id                UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    item_code         VARCHAR(12)      NOT NULL,
    buyer_id          UNIQUEIDENTIFIER NOT NULL,
    type_code         CHAR(2)          NOT NULL,
    buyer_style_name  NVARCHAR(100)    NOT NULL,
    created_at        DATETIME2(0)     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_items PRIMARY KEY (id),
    CONSTRAINT uq_items_code UNIQUE (item_code),
    CONSTRAINT fk_items_buyer FOREIGN KEY (buyer_id) REFERENCES buyers(id),
    CONSTRAINT fk_items_type  FOREIGN KEY (type_code) REFERENCES product_types(type_code)
);
GO

CREATE TABLE orders (
    id                UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    order_code        CHAR(12)         NOT NULL,
    buyer_id          UNIQUEIDENTIFIER NOT NULL,
    order_date        DATE             NOT NULL DEFAULT CAST(SYSDATETIME() AS DATE),
    deadline          DATE             NOT NULL,
    scheme            VARCHAR(3)       NOT NULL,
    reject_limit_pct  DECIMAL(5,2)     NOT NULL,
    late_penalty      NVARCHAR(500)    NOT NULL,
    status            VARCHAR(20)      NOT NULL DEFAULT 'MENUNGGU_PERSETUJUAN',
    is_at_risk        BIT              NOT NULL DEFAULT 0,
    is_over_reject    BIT              NOT NULL DEFAULT 0,
    created_by        UNIQUEIDENTIFIER NOT NULL,
    created_at        DATETIME2(0)     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_orders PRIMARY KEY (id),
    CONSTRAINT uq_orders_code UNIQUE (order_code),
    CONSTRAINT fk_orders_buyer FOREIGN KEY (buyer_id) REFERENCES buyers(id),
    CONSTRAINT fk_orders_user  FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT ck_orders_deadline CHECK (deadline >= order_date),
    CONSTRAINT ck_orders_scheme   CHECK (scheme IN ('CMT', 'FOB')),
    CONSTRAINT ck_orders_reject   CHECK (reject_limit_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_orders_status   CHECK (status IN ('MENUNGGU_PERSETUJUAN', 'DISETUJUI', 'DITOLAK',
                                     'DITARIK', 'DALAM_PRODUKSI', 'SELESAI', 'DIBATALKAN'))
);
GO

CREATE TABLE order_status_history (
    id          BIGINT IDENTITY(1,1) NOT NULL,
    order_id    UNIQUEIDENTIFIER     NOT NULL,
    status      VARCHAR(20)          NOT NULL,
    changed_by  UNIQUEIDENTIFIER     NOT NULL,
    reason      NVARCHAR(500)        NULL,
    changed_at  DATETIME2(0)         NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_order_status_history PRIMARY KEY (id),
    CONSTRAINT fk_osh_order FOREIGN KEY (order_id) REFERENCES orders(id),
    CONSTRAINT fk_osh_user  FOREIGN KEY (changed_by) REFERENCES users(id),
    CONSTRAINT ck_osh_reason CHECK (status NOT IN ('DITOLAK', 'DITARIK', 'DIBATALKAN')
                                    OR LEN(ISNULL(reason, '')) > 0)
);
GO

CREATE TABLE order_styles (
    id              UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    order_id        UNIQUEIDENTIFIER NOT NULL,
    item_id         UNIQUEIDENTIFIER NOT NULL,
    color           NVARCHAR(50)     NOT NULL,
    price_per_pcs   DECIMAL(14,2)    NOT NULL,
    is_at_risk      BIT              NOT NULL DEFAULT 0,
    is_over_reject  BIT              NOT NULL DEFAULT 0,
    CONSTRAINT pk_order_styles PRIMARY KEY (id),
    CONSTRAINT fk_os_order FOREIGN KEY (order_id) REFERENCES orders(id),
    CONSTRAINT fk_os_item  FOREIGN KEY (item_id) REFERENCES items(id),
    CONSTRAINT ck_os_price CHECK (price_per_pcs > 0)
);
GO

CREATE TABLE order_style_sizes (
    style_id  UNIQUEIDENTIFIER NOT NULL,
    size      VARCHAR(10)      NOT NULL,
    qty       INT              NOT NULL,
    CONSTRAINT pk_order_style_sizes PRIMARY KEY (style_id, size),
    CONSTRAINT fk_oss_style FOREIGN KEY (style_id) REFERENCES order_styles(id),
    CONSTRAINT ck_oss_qty CHECK (qty > 0)
);
GO

CREATE TABLE shipments (
    id                UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    delivery_note_no  CHAR(11)         NOT NULL,
    order_id          UNIQUEIDENTIFIER NOT NULL,
    ship_date         DATE             NOT NULL,
    expedition        NVARCHAR(100)    NOT NULL,
    recorded_by       UNIQUEIDENTIFIER NOT NULL,
    created_at        DATETIME2(0)     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_shipments PRIMARY KEY (id),
    CONSTRAINT uq_shipments_no UNIQUE (delivery_note_no),
    CONSTRAINT fk_ship_order FOREIGN KEY (order_id) REFERENCES orders(id),
    CONSTRAINT fk_ship_user  FOREIGN KEY (recorded_by) REFERENCES users(id)
);
GO

CREATE TABLE shipment_items (
    id           UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    shipment_id  UNIQUEIDENTIFIER NOT NULL,
    style_id     UNIQUEIDENTIFIER NOT NULL,
    size         VARCHAR(10)      NOT NULL,
    qty          INT              NOT NULL,
    CONSTRAINT pk_shipment_items PRIMARY KEY (id),
    CONSTRAINT uq_si UNIQUE (shipment_id, style_id, size),
    CONSTRAINT fk_si_shipment FOREIGN KEY (shipment_id) REFERENCES shipments(id),
    CONSTRAINT fk_si_style    FOREIGN KEY (style_id) REFERENCES order_styles(id),
    CONSTRAINT ck_si_qty CHECK (qty > 0)
);
GO

-- Index (TSD 4.4). UNIQUE di atas sudah otomatis membuat index untuk kode.
CREATE INDEX ix_items_buyer          ON items (buyer_id);
CREATE INDEX ix_orders_status        ON orders (status, deadline);
CREATE INDEX ix_orders_buyer         ON orders (buyer_id, order_date);
CREATE INDEX ix_osh_order            ON order_status_history (order_id, changed_at);
CREATE INDEX ix_os_order             ON order_styles (order_id);
CREATE INDEX ix_os_item              ON order_styles (item_id);
CREATE INDEX ix_shipments_order      ON shipments (order_id, ship_date);
CREATE INDEX ix_shipment_items_style ON shipment_items (style_id);
GO
-- Retail schema
-- Ticket: RIP-1-043

CREATE TABLE IF NOT EXISTS retail.stores (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES identity.tenants (id) ON DELETE CASCADE,
    external_id TEXT,
    name        TEXT NOT NULL,
    timezone    TEXT NOT NULL DEFAULT 'UTC',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, external_id)
);

CREATE TABLE IF NOT EXISTS retail.inventory (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id    UUID NOT NULL REFERENCES retail.stores (id) ON DELETE CASCADE,
    sku         TEXT NOT NULL,
    product_name TEXT NOT NULL,
    quantity    INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, sku)
);

CREATE INDEX IF NOT EXISTS idx_inventory_store_sku ON retail.inventory (store_id, sku);

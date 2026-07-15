-- Twin version snapshots for time-travel
-- Ticket: RIP-3-006

CREATE TABLE IF NOT EXISTS twin.versions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id    UUID NOT NULL REFERENCES retail.stores (id) ON DELETE CASCADE,
    version     INTEGER NOT NULL,
    snapshot    JSONB NOT NULL DEFAULT '{}',
    valid_from  TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to    TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, version)
);

CREATE INDEX IF NOT EXISTS idx_twin_versions_store_active
    ON twin.versions (store_id, valid_from DESC)
    WHERE valid_to IS NULL;

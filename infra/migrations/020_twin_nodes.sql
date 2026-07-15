# Phase 3 twin schema extensions
# Ticket: RIP-3-002..006

CREATE TABLE IF NOT EXISTS twin.nodes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id    UUID NOT NULL REFERENCES retail.stores (id) ON DELETE CASCADE,
    parent_id   UUID REFERENCES twin.nodes (id) ON DELETE SET NULL,
    node_type   TEXT NOT NULL,
    label       TEXT,
    transform   JSONB NOT NULL DEFAULT '{}',
    metadata    JSONB NOT NULL DEFAULT '{}',
    valid_from  TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to    TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_twin_nodes_store ON twin.nodes (store_id);
CREATE INDEX IF NOT EXISTS idx_twin_nodes_parent ON twin.nodes (parent_id);
CREATE INDEX IF NOT EXISTS idx_twin_nodes_metadata ON twin.nodes USING gin (metadata);

-- Navigation graph edges between waypoint nodes
-- Ticket: RIP-3-003

CREATE TABLE IF NOT EXISTS twin.edges (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id    UUID NOT NULL REFERENCES retail.stores (id) ON DELETE CASCADE,
    from_node   UUID NOT NULL REFERENCES twin.nodes (id) ON DELETE CASCADE,
    to_node     UUID NOT NULL REFERENCES twin.nodes (id) ON DELETE CASCADE,
    cost_m      DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    metadata    JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, from_node, to_node)
);

CREATE INDEX IF NOT EXISTS idx_twin_edges_store ON twin.edges (store_id);

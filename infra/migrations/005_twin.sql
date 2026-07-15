-- Digital twin schema (PostGIS)
-- Ticket: RIP-1-044

CREATE TABLE IF NOT EXISTS twin.store_layouts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id    UUID NOT NULL REFERENCES retail.stores (id) ON DELETE CASCADE,
    version     INTEGER NOT NULL DEFAULT 1,
    snapshot    JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, version)
);

CREATE TABLE IF NOT EXISTS twin.spatial_objects (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id        UUID NOT NULL REFERENCES retail.stores (id) ON DELETE CASCADE,
    layout_id       UUID REFERENCES twin.store_layouts (id) ON DELETE SET NULL,
    object_type     TEXT NOT NULL,
    label           TEXT,
    geom            geometry(Geometry, 4326) NOT NULL,
    properties      JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN twin.spatial_objects.geom IS 'WGS84 geometry for store floor objects (shelves, cameras, zones)';

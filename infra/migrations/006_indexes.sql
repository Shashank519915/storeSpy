-- Performance indexes
-- Ticket: RIP-1-045

CREATE INDEX IF NOT EXISTS idx_spatial_objects_geom
    ON twin.spatial_objects USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_store_layouts_snapshot
    ON twin.store_layouts USING GIN (snapshot);

CREATE INDEX IF NOT EXISTS idx_spatial_objects_store_type
    ON twin.spatial_objects (store_id, object_type);

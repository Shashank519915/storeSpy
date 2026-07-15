-- GiST indexes on twin spatial objects (complements 005_twin.sql)
-- Ticket: RIP-3-007

CREATE INDEX IF NOT EXISTS idx_twin_spatial_objects_geom
    ON twin.spatial_objects USING gist (geom);

CREATE INDEX IF NOT EXISTS idx_twin_spatial_objects_store_type
    ON twin.spatial_objects (store_id, object_type);

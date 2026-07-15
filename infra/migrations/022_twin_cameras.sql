-- Camera mounts and homography
-- Ticket: RIP-3-005

CREATE TABLE IF NOT EXISTS twin.cameras (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id            UUID NOT NULL REFERENCES retail.stores (id) ON DELETE CASCADE,
    external_id         TEXT NOT NULL,
    mount_point         geometry(PointZ, 4326),
    pan_degrees         DOUBLE PRECISION NOT NULL DEFAULT 0,
    tilt_degrees        DOUBLE PRECISION NOT NULL DEFAULT 0,
    fov_degrees         DOUBLE PRECISION NOT NULL DEFAULT 90,
    homography_matrix   DOUBLE PRECISION[9],
    layout_version      INTEGER NOT NULL DEFAULT 1,
    metadata            JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, external_id)
);

CREATE INDEX IF NOT EXISTS idx_twin_cameras_store ON twin.cameras (store_id);
CREATE INDEX IF NOT EXISTS idx_twin_cameras_mount ON twin.cameras USING gist (mount_point);

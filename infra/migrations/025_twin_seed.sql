-- Dev lab store seed for twin-api and spatial-query tests
-- Ticket: RIP-3-008

INSERT INTO identity.tenants (id, name, slug)
VALUES ('11111111-1111-1111-1111-111111111111', 'RIP Dev Tenant', 'rip-dev')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO retail.stores (id, tenant_id, external_id, name, timezone)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'store-dev-01',
    'RIP Dev Lab Store',
    'UTC'
)
ON CONFLICT (tenant_id, external_id) DO NOTHING;

INSERT INTO twin.versions (store_id, version, snapshot, valid_from)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    1,
    '{"zones":["aisle-a"],"shelves":["shelf-a1"]}',
    now()
)
ON CONFLICT (store_id, version) DO NOTHING;

INSERT INTO twin.cameras (store_id, external_id, pan_degrees, tilt_degrees, fov_degrees, homography_matrix, layout_version)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    'cam-virtual-01',
    0, 15, 90,
    ARRAY[1,0,0, 0,1,0, 0,0,1]::double precision[],
    1
)
ON CONFLICT (store_id, external_id) DO NOTHING;

INSERT INTO twin.spatial_objects (store_id, object_type, label, geom, properties)
SELECT
    '22222222-2222-2222-2222-222222222222',
    'Shelf',
    'shelf-a1',
    ST_SetSRID(ST_GeomFromText('POLYGON((1 3, 3 3, 3 5, 1 5, 1 3))'), 4326),
    '{"sku_zone":"grocery"}'
WHERE NOT EXISTS (
    SELECT 1 FROM twin.spatial_objects
    WHERE store_id = '22222222-2222-2222-2222-222222222222' AND label = 'shelf-a1'
);

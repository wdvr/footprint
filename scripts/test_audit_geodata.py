import json
import shutil

import pytest

import audit_geodata
from audit_geodata import GEO_DIR, SWIFT_FILE, audit


@pytest.fixture
def geo_dir(tmp_path):
    path = tmp_path / "GeoData"
    shutil.copytree(GEO_DIR, path)
    return path


def edit_geojson(path, edit):
    data = json.loads(path.read_text())
    edit(data)
    path.write_text(json.dumps(data))


def test_bundled_data_passes():
    errors, _ = audit()
    assert errors == []


def test_feature_code_missing_from_swift_fails(geo_dir):
    def rename(data):
        data["features"][0]["properties"]["state_code"] = "GB-ZZZ"

    edit_geojson(geo_dir / "GB_states.geojson", rename)

    errors, _ = audit(SWIFT_FILE, geo_dir)

    assert "GB: in GB_states.geojson but not GeographicData: ['ZZZ']" in errors
    assert any(
        e.startswith("GB: in GeographicData but not GB_states.geojson") for e in errors
    )


def test_swift_code_missing_fails(tmp_path):
    swift = tmp_path / "GeographicData.swift"
    swift.write_text(
        SWIFT_FILE.read_text().replace(
            'StateProvince("WRL", "Wirral", country: "GB"),\n', ""
        )
    )

    errors, _ = audit(swift, GEO_DIR)

    assert "GB: in GB_states.geojson but not GeographicData: ['WRL']" in errors


def test_commented_out_swift_code_fails(tmp_path):
    swift = tmp_path / "GeographicData.swift"
    swift.write_text(
        SWIFT_FILE.read_text().replace('StateProvince("WRL"', '// StateProvince("WRL"')
    )

    errors, _ = audit(swift, GEO_DIR)

    assert "GB: in GB_states.geojson but not GeographicData: ['WRL']" in errors


def test_multiline_constructors_pass(tmp_path):
    swift = tmp_path / "GeographicData.swift"
    swift.write_text(
        SWIFT_FILE.read_text()
        .replace(
            'StateProvince("WRL", ', 'StateProvince(\n            "WRL",\n            '
        )
        .replace('Country("GB", ', 'Country(\n            "GB",\n            ')
    )

    errors, _ = audit(swift, GEO_DIR)

    assert errors == []


def test_unclosed_ring_fails(geo_dir):
    def open_ring(data):
        geometry = data["features"][0]["geometry"]
        ring = (
            geometry["coordinates"][0]
            if geometry["type"] == "Polygon"
            else geometry["coordinates"][0][0]
        )
        ring.pop()

    edit_geojson(geo_dir / "NL_states.geojson", open_ring)

    errors, _ = audit(SWIFT_FILE, geo_dir)

    assert any("NL_states.geojson" in e and "not closed" in e for e in errors)


def test_country_without_boundary_fails(geo_dir):
    def drop_france(data):
        data["features"] = [
            f for f in data["features"] if f["properties"]["iso_code"] != "FR"
        ]

    edit_geojson(geo_dir / "countries.geojson", drop_france)

    errors, _ = audit(SWIFT_FILE, geo_dir)

    assert "countries without a boundary in countries.geojson: ['FR']" in errors


def test_stale_exception_fails(monkeypatch):
    monkeypatch.setitem(audit_geodata.CODES_WITHOUT_GEOMETRY, "GB", {"WRL"})

    errors, _ = audit()

    assert "GB: remove ['WRL'] from CODES_WITHOUT_GEOMETRY" in errors


def test_deleted_boundary_file_fails(geo_dir):
    (geo_dir / "NL_states.geojson").unlink()

    errors, _ = audit(SWIFT_FILE, geo_dir)

    assert "NL: boundary file NL_states.geojson is missing" in errors


def test_parenthesized_country_name_passes(tmp_path):
    swift = tmp_path / "GeographicData.swift"
    swift.write_text(
        SWIFT_FILE.read_text().replace(
            'Country("GB", "United Kingdom"', 'Country("GB", "United Kingdom (UK)"'
        )
    )

    errors, _ = audit(swift, GEO_DIR)

    assert errors == []


def test_exception_for_country_without_subdivisions_fails(monkeypatch):
    monkeypatch.setattr(
        audit_geodata, "COUNTRIES_WITHOUT_BOUNDARY_FILE", {"AU", "BR", "DE", "MX", "IS"}
    )

    errors, _ = audit()

    assert (
        "['IS'] have no subdivisions; remove from COUNTRIES_WITHOUT_BOUNDARY_FILE"
        in errors
    )

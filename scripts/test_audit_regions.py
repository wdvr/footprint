import json

import pytest

from audit_regions import DATASET, SOURCE, audit


@pytest.fixture
def files(tmp_path):
    dataset, source = tmp_path / "named_regions.json", tmp_path / "source.json"
    dataset.write_text(DATASET.read_text())
    source.write_text(SOURCE.read_text())
    return dataset, source


def edit(path, region_id, change):
    data = json.loads(path.read_text())
    change(next(r for r in data["regions"] if r["id"] == region_id))
    path.write_text(json.dumps(data))


def run(files, county_index=None):
    dataset, source = files
    return audit(
        dataset, source, county_index=county_index or dataset.parent / "none.json"
    )


def test_bundled_dataset_passes():
    assert audit() == []


def test_unknown_subdivision_fails(files):
    edit(
        files[0],
        "it-tuscany",
        lambda r: (
            r["memberKeys"].append("IT-ZZ"),
            r["memberNames"].update({"IT-ZZ": "?"}),
        ),
    )
    assert any("'IT-ZZ' is not a subdivision of IT" in e for e in run(files))


def test_unknown_country_fails(files):
    edit(
        files[0],
        "eu-baltics",
        lambda r: (r["memberKeys"].append("XX"), r["memberNames"].update({"XX": "?"})),
    )
    assert any("'XX' is not a country" in e for e in run(files))


def test_bad_county_fips_fails(files):
    edit(
        files[0],
        "us-cape-cod",
        lambda r: (
            r["memberKeys"].append("99001"),
            r["memberNames"].update({"99001": "?"}),
        ),
    )
    assert any("'99001' is not a US county FIPS" in e for e in run(files))


def test_county_missing_from_index_fails(files, tmp_path):
    index = tmp_path / "counties_index.json"
    index.write_text(json.dumps({"counties": {"25001": {}}}))
    edit(
        files[0],
        "us-cape-cod",
        lambda r: (
            r["memberKeys"].append("25003"),
            r["memberNames"].update({"25003": "?"}),
        ),
    )
    errors = run(files, index)
    assert any("'25003' is not in counties_index.json" in e for e in errors)
    assert not any("'25001'" in e for e in errors)


def test_duplicate_member_and_missing_name_fail(files):
    edit(files[0], "us-wine-country", lambda r: r["memberKeys"].append("06055"))
    edit(files[0], "us-big-sur", lambda r: r["memberNames"].clear())
    errors = run(files)
    assert any("us-wine-country: duplicate members ['06055']" in e for e in errors)
    assert any("us-big-sur: members without a name" in e for e in errors)


def test_bad_kind_and_id_fail(files):
    edit(files[0], "us-big-sur", lambda r: r.update(kind="vibes"))
    edit(files[0], "us-cape-cod", lambda r: r.update(id="Cape Cod"))
    errors = run(files)
    assert any("kind 'vibes'" in e for e in errors)
    assert any("Cape Cod: id is not a lowercase slug" in e for e in errors)


def test_dataset_out_of_date_with_source_fails(files):
    edit(files[1], "us-bay-area", lambda r: r["members"].pop())
    assert any("us-bay-area: members differ from the source" in e for e in run(files))


def test_duplicate_id_fails(files):
    data = json.loads(files[0].read_text())
    data["regions"].append(data["regions"][0])
    files[0].write_text(json.dumps(data))
    assert any("duplicate id" in e for e in run(files))


def test_null_or_missing_blurb_fails(files):
    edit(files[0], "us-big-sur", lambda r: r.update(blurb=None))
    edit(files[0], "us-cape-cod", lambda r: r.pop("blurb"))
    errors = run(files)
    assert any("us-big-sur: empty blurb" in e for e in errors)
    assert any("us-cape-cod: empty blurb" in e for e in errors)

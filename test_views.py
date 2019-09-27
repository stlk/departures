import os
import pytest
from flask import json
import api.departures


@pytest.fixture
def departures_app(request):
    config = {"TESTING": True, "DEBUG": True}
    app = api.departures.app
    app.config.update(config or {})

    with app.app_context():
        yield app


def test_slash(departures_app):
    client = departures_app.test_client()
    rv = client.get(
        "/api/departures?latitude=50.07386&longitude=14.41507",
    )
    assert rv.status == "200 OK"
    assert rv.get_json() == "hello world"
